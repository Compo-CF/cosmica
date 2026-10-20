import XCTest
@testable import Cosmica

/// v3.2 — the synthesized effects and music loop render sane audio.
final class SoundTests: XCTestCase {
    func test_everyEffect_rendersAudibleUnclippedSamples() {
        for effect in SoundManager.Effect.allCases {
            let variants = Synth.effect(effect)
            XCTAssertFalse(variants.isEmpty, "\(effect)")
            for samples in variants {
                XCTAssertFalse(samples.isEmpty, "\(effect)")
                let peak = samples.map { abs($0) }.max() ?? 0
                XCTAssertTrue(peak.isFinite, "\(effect)")
                XCTAssertGreaterThan(peak, 0.01, "\(effect) is silent")
                XCTAssertLessThanOrEqual(peak, 1.0, "\(effect) clips")
            }
        }
    }

    func test_musicLoop_isThirtyTwoSecondsAndSeamless() {
        let music = Synth.music()
        XCTAssertEqual(music.count, Int(32 * Synth.sampleRate))
        let peak = music.map { abs($0) }.max() ?? 0
        XCTAssertEqual(peak, 0.32, accuracy: 0.001)
        // The jump from the last sample back to the first is no bigger than an
        // ordinary step inside the loop, so there's no click at the seam.
        let seam = abs(music[music.count - 1] - music[0])
        XCTAssertLessThan(seam, 0.02)
    }
}
