import AVFoundation
import Observation
import QuartzCore

/// v3.2 — Cosmica's sound: short effects for every haptic moment, plus an
/// ambient music loop. Everything is synthesized in code at launch, so the
/// app ships no audio files and there's nothing to license.
///
/// Plays nicely with the phone: the `.ambient` session follows the ringer /
/// silent switch and mixes with whatever the player is already listening to.
/// Music pauses in the background and while a full-screen ad is showing.
///
/// Effects are triggered from `HapticsManager` (every haptic is a sound
/// moment), so call sites don't change. Settings > Sound has the switches.
@MainActor
@Observable
final class SoundManager {
    enum Effect: CaseIterable {
        case tap, purchase, upgrade, bigBang, shardGrant, skillUnlock, specialize, eventStart, eventEnd, dailyClaim, error
    }

    private enum Keys {
        static let effects = "cosmica.sound.effects"
        static let music = "cosmica.sound.music"
        static let musicVolume = "cosmica.sound.musicVolume"
    }

    private(set) var effectsEnabled: Bool
    private(set) var musicEnabled: Bool
    private(set) var musicVolume: Double

    @ObservationIgnored private let audio = AVAudioEngine()
    @ObservationIgnored private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)!
    @ObservationIgnored private var effectNodes: [AVAudioPlayerNode] = []
    @ObservationIgnored private var nextEffectNode = 0
    @ObservationIgnored private let musicNode = AVAudioPlayerNode()
    @ObservationIgnored private var buffers: [Effect: [AVAudioPCMBuffer]] = [:]
    @ObservationIgnored private var musicBuffer: AVAudioPCMBuffer?
    @ObservationIgnored private var musicScheduled = false
    @ObservationIgnored private var started = false
    @ObservationIgnored private var inForeground = true
    @ObservationIgnored private var adShowing = false
    @ObservationIgnored private var adFallback: Task<Void, Never>?
    @ObservationIgnored private var tapNote = 2
    @ObservationIgnored private var lastTapAt: CFTimeInterval = 0
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    /// Music sits under the effects: a full slider is this fraction of full scale.
    private static let musicGain = 0.6

    init() {
        let d = UserDefaults.standard
        effectsEnabled = d.object(forKey: Keys.effects) as? Bool ?? true
        musicEnabled = d.object(forKey: Keys.music) as? Bool ?? true
        musicVolume = d.object(forKey: Keys.musicVolume) as? Double ?? 0.5
    }

    // MARK: - Settings

    func setEffectsEnabled(_ on: Bool) {
        effectsEnabled = on
        UserDefaults.standard.set(on, forKey: Keys.effects)
    }

    func setMusicEnabled(_ on: Bool) {
        musicEnabled = on
        UserDefaults.standard.set(on, forKey: Keys.music)
        updateMusic()
    }

    func setMusicVolume(_ v: Double) {
        musicVolume = min(1, max(0, v))
        UserDefaults.standard.set(musicVolume, forKey: Keys.musicVolume)
        musicNode.volume = Float(musicVolume * Self.musicGain)
    }

    // MARK: - Lifecycle

    /// Build the effects, start the audio engine, and render the music loop in
    /// the background (well under a second; music starts when it's ready).
    func start() {
        guard !started else { return }
        started = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        for effect in Effect.allCases {
            buffers[effect] = Synth.effect(effect).map(makeBuffer)
        }
        for _ in 0..<6 {
            let node = AVAudioPlayerNode()
            audio.attach(node)
            audio.connect(node, to: audio.mainMixerNode, format: format)
            effectNodes.append(node)
        }
        audio.attach(musicNode)
        audio.connect(musicNode, to: audio.mainMixerNode, format: format)
        musicNode.volume = Float(musicVolume * Self.musicGain)
        audio.prepare()
        startEngine()
        observe()

        Task { [weak self] in
            let samples = await Task.detached(priority: .utility) { Synth.music() }.value
            guard let self else { return }
            self.musicBuffer = self.makeBuffer(samples)
            self.updateMusic()
        }
    }

    /// App went to the background: stop music and let the engine sleep.
    func suspend() {
        inForeground = false
        updateMusic()
        if started { audio.pause() }
    }

    func resume() {
        inForeground = true
        startEngine()
        updateMusic()
    }

    /// Full-screen ads play their own audio; music steps aside while one is up.
    /// If the ad never reports closing, music comes back after two minutes anyway.
    func setAdShowing(_ showing: Bool) {
        adShowing = showing
        adFallback?.cancel()
        if showing {
            adFallback = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 120_000_000_000)
                guard !Task.isCancelled else { return }
                self?.setAdShowing(false)
            }
        }
        updateMusic()
    }

    // MARK: - Playing

    func play(_ effect: Effect) {
        guard started, effectsEnabled, inForeground, !adShowing else { return }
        guard var variants = buffers[effect], !variants.isEmpty else { return }
        if effect == .tap {
            // Fast tapping shouldn't turn into a buzz.
            let now = CACurrentMediaTime()
            guard now - lastTapAt > 0.045 else { return }
            lastTapAt = now
            // A gentle random walk over the pentatonic notes: melodic, never jarring.
            tapNote = min(variants.count - 1, max(0, tapNote + Int.random(in: -1...1)))
            variants = [variants[tapNote]]
        }
        if !audio.isRunning { startEngine() }
        guard audio.isRunning, let buffer = variants.randomElement() else { return }
        let node = effectNodes[nextEffectNode]
        nextEffectNode = (nextEffectNode + 1) % effectNodes.count
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !node.isPlaying { node.play() }
    }

    private func updateMusic() {
        guard started else { return }
        let shouldPlay = musicEnabled && inForeground && !adShowing && musicBuffer != nil
        if shouldPlay {
            if !audio.isRunning { startEngine() }
            guard audio.isRunning, let buffer = musicBuffer else { return }
            if !musicScheduled {
                musicNode.scheduleBuffer(buffer, at: nil, options: .loops)
                musicScheduled = true
            }
            if !musicNode.isPlaying { musicNode.play() }
        } else if musicNode.isPlaying {
            musicNode.pause()
        }
    }

    // MARK: - Engine plumbing

    private func startEngine() {
        guard started, !audio.isRunning else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        try? audio.start()
    }

    /// After a phone call or an audio route change the engine stops; restart it
    /// and reschedule the music (a stopped node forgets its schedule).
    private func observe() {
        let center = NotificationCenter.default
        let restart: (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.musicNode.stop()
                self.musicScheduled = false
                if self.inForeground { self.startEngine() }
                self.updateMusic()
            }
        }
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange,
                                            object: audio, queue: nil, using: restart))
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil, queue: nil) { note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if raw == AVAudioSession.InterruptionType.ended.rawValue { restart(note) }
        })
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        return buffer
    }
}

// MARK: - Synthesis

/// Pure functions that render mono Float samples at 44.1 kHz. Not tied to the
/// main actor, so the music loop renders in the background.
enum Synth {
    static let sampleRate = 44_100.0

    /// One or more variants per effect (only `tap` has several: one per note).
    static func effect(_ e: SoundManager.Effect) -> [[Float]] {
        switch e {
        case .tap:
            // C major pentatonic, two octaves up: bright but soft.
            return [1046.50, 1174.66, 1318.51, 1567.98, 1760.00, 2093.00].map {
                pluck($0, length: 0.35, decay: 0.11, amp: 0.20)
            }
        case .purchase:
            return [mix(0.16, [(0, pluck(1318.51, length: 0.12, decay: 0.03, amp: 0.16)),
                               (0.035, pluck(1975.53, length: 0.12, decay: 0.03, amp: 0.12))])]
        case .upgrade:
            return [arpeggio([523.25, 659.26, 783.99, 1046.50], step: 0.07, amp: 0.16)]
        case .dailyClaim:
            return [arpeggio([659.26, 783.99, 1046.50, 1318.51, 1567.98], step: 0.06, amp: 0.15)]
        case .skillUnlock:
            return [arpeggio([783.99, 1174.66], step: 0.09, amp: 0.18)]
        case .specialize:
            return [arpeggio([523.25, 783.99, 1046.50], step: 0.09, amp: 0.16)]
        case .shardGrant:
            return [mix(0.95, [(0, bell(1567.98, amp: 0.10)), (0.06, bell(2349.32, amp: 0.08)), (0.12, bell(3135.96, amp: 0.06))])]
        case .eventStart:
            return [mix(0.9, [(0, sweep(from: 440, to: 880, length: 0.45, amp: 0.12)),
                              (0.38, pluck(1760, length: 0.5, decay: 0.15, amp: 0.12))])]
        case .eventEnd:
            return [sweep(from: 880, to: 440, length: 0.45, amp: 0.10)]
        case .error:
            return [mix(0.3, [(0, pluck(220, length: 0.12, decay: 0.05, amp: 0.20, harmonics: [(3, 0.3)])),
                              (0.12, pluck(207.65, length: 0.15, decay: 0.06, amp: 0.20, harmonics: [(3, 0.3)]))])]
        case .bigBang:
            return [bigBang()]
        }
    }

    // MARK: Building blocks

    /// Plucked tone: 2 ms attack, exponential decay, a little brightness from harmonics.
    static func pluck(_ f: Double, length: Double, decay: Double, amp: Double,
                      harmonics: [(Double, Double)] = [(2, 0.25), (3, 0.08)]) -> [Float] {
        let n = Int(length * sampleRate)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let env = min(1, t / 0.002) * exp(-t / decay)
            var s = sin(2 * .pi * f * t)
            for (mult, a) in harmonics { s += a * sin(2 * .pi * f * mult * t) * exp(-t / (decay * 0.5)) }
            out[i] = Float(amp * env * s)
        }
        return out
    }

    /// Bell: the inharmonic partial (×2.76) gives the metallic ring.
    static func bell(_ f: Double, amp: Double) -> [Float] {
        pluck(f, length: 0.8, decay: 0.25, amp: amp, harmonics: [(2.76, 0.35), (5.4, 0.12)])
    }

    static func arpeggio(_ notes: [Double], step: Double, amp: Double) -> [Float] {
        let parts = notes.enumerated().map { (Double($0.offset) * step, pluck($0.element, length: 0.45, decay: 0.16, amp: amp)) }
        return mix(Double(notes.count - 1) * step + 0.45, parts)
    }

    /// Exponential pitch glide with a smooth swell in and out.
    static func sweep(from f0: Double, to f1: Double, length: Double, amp: Double) -> [Float] {
        let n = Int(length * sampleRate)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let x = Double(i) / Double(n)
            phase += 2 * .pi * f0 * pow(f1 / f0, x) / sampleRate
            out[i] = Float(amp * sin(.pi * x) * sin(phase))
        }
        return out
    }

    /// A low boom sliding down, a soft rumble, and a high shimmer as it settles.
    static func bigBang() -> [Float] {
        let n = Int(2.4 * sampleRate)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0, lp = 0.0
        var rng = SystemRandomNumberGenerator()
        for i in 0..<n {
            let t = Double(i) / sampleRate
            phase += 2 * .pi * (32 + 90 * exp(-t / 0.35)) / sampleRate
            let boom = 0.55 * min(1, t / 0.01) * exp(-t / 0.7) * sin(phase)
            lp += 0.03 * (Double.random(in: -1...1, using: &rng) - lp)   // one-pole low-pass: rumble, not hiss
            let rumble = 1.6 * min(1, t / 0.02) * exp(-t / 0.45) * lp
            out[i] = Float(boom + rumble)
        }
        let shimmer = mix(1.6, [(0, bell(1046.50, amp: 0.05)), (0.08, bell(1567.98, amp: 0.05)), (0.16, bell(2093.00, amp: 0.04))])
        let offset = Int(0.35 * sampleRate)
        for (i, s) in shimmer.enumerated() where offset + i < n { out[offset + i] += s }
        return out
    }

    static func mix(_ length: Double, _ parts: [(Double, [Float])]) -> [Float] {
        var out = [Float](repeating: 0, count: Int(length * sampleRate))
        for (start, samples) in parts {
            let o = Int(start * sampleRate)
            for (i, s) in samples.enumerated() where o + i < out.count { out[o + i] += s }
        }
        return out
    }

    // MARK: Music

    /// A 32-second ambient loop: four slow, overlapping chords over a low drone,
    /// with soft bell notes drifting on top.
    ///
    /// Seamless by construction: every pitch is nudged to a whole number of
    /// cycles in 32 s, chord fades are measured around the loop, and bell tails
    /// wrap past the end, so the last sample flows into the first.
    static func music() -> [Float] {
        let loop = 32.0
        let n = Int(loop * sampleRate)
        func snap(_ f: Double) -> Double { (f * loop).rounded() / loop }

        // Dmaj9 → Bm9 → Gmaj7(#11) → A6/9, voiced low and open.
        let chords: [[Double]] = [
            [146.83, 220.00, 329.63, 369.99, 554.37],
            [123.47, 185.00, 293.66, 440.00, 554.37],
            [98.00, 146.83, 369.99, 493.88, 554.37],
            [110.00, 164.81, 246.94, 369.99, 659.26],
        ].map { $0.map(snap) }
        let slot = loop / Double(chords.count)          // 8 s per chord
        let halfWidth = slot * 0.75                     // 12 s fade window, so chords overlap
        let drone = [73.42, 110.00].map(snap)

        // Bell notes from D major pentatonic, at fixed times in the loop.
        let bellNotes = [587.33, 659.26, 739.99, 880.00, 987.77, 1174.66]
        let bellTimes: [(Double, Int)] = [(1.5, 3), (4.2, 1), (7.0, 5), (10.6, 2), (13.1, 0), (16.8, 4),
                                          (19.5, 2), (22.9, 5), (25.4, 1), (28.7, 3), (30.9, 0)]
        let bellDecay = 1.4

        var out = [Float](repeating: 0, count: n)
        var peak: Float = 0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            for (k, chord) in chords.enumerated() {
                var d = abs(t - (Double(k) * slot + slot / 2))
                d = min(d, loop - d)                    // distance around the loop
                guard d < halfWidth else { continue }
                let w = 0.5 * (1 + cos(.pi * d / halfWidth))
                for (v, f) in chord.enumerated() {
                    // Each voice breathes at its own slow rate (all periodic in the loop).
                    let breathe = 1 + 0.18 * sin(2 * .pi * t * Double(v + 2) / loop)
                    s += w * breathe * 0.045 * (sin(2 * .pi * f * t) + 0.12 * sin(4 * .pi * f * t))
                }
            }
            for f in drone { s += 0.05 * sin(2 * .pi * f * t) }
            for (start, note) in bellTimes {
                var dt = t - start
                if dt < 0 { dt += loop }                // tails wrap across the loop point
                guard dt < bellDecay * 5 else { continue }
                let f = bellNotes[note]
                let env = min(1, dt / 0.01) * exp(-dt / bellDecay)
                s += 0.035 * env * (sin(2 * .pi * f * dt) + 0.25 * sin(4 * .pi * f * dt))
            }
            out[i] = Float(s)
            peak = max(peak, abs(out[i]))
        }
        if peak > 0 {
            let scale = 0.32 / peak
            for i in 0..<n { out[i] *= scale }
        }
        return out
    }
}
