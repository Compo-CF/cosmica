import UIKit
import Observation

/// Central haptic vocabulary. Each method is a specific in-game event so call sites read like
/// domain narration ("cosmic event", "shard grant") rather than raw impact primitives.
@MainActor
@Observable
final class HapticsManager {
    private let lightImpact   = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact  = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact   = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact   = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact    = UIImpactFeedbackGenerator(style: .soft)
    private let notification  = UINotificationFeedbackGenerator()

    init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        notification.prepare()
    }

    // MARK: - Taps & purchases

    /// Player tapped the observatory orb.
    func tap()         { mediumImpact.impactOccurred(intensity: 0.6) }

    /// A generator or upgrade was bought successfully.
    func purchase()    { lightImpact.impactOccurred(intensity: 0.9) }

    /// An upgrade unlocked or a tier crossed — a positive step-up.
    func upgrade()     { notification.notificationOccurred(.success) }

    // MARK: - Prestige & meta

    /// Big Bang triggered — the big beat.
    func bigBang()     { heavyImpact.impactOccurred(intensity: 1.0) }

    /// Cosmic Shard direct grant (IAP, daily reward, event drop).
    func shardGrant() {
        rigidImpact.impactOccurred(intensity: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.notification.notificationOccurred(.success)
        }
    }

    /// Bought a Cosmic tree skill level.
    func skillUnlock() {
        heavyImpact.impactOccurred(intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.notification.notificationOccurred(.success)
        }
    }

    /// Committed a generator to a specialization — firm one-two beat.
    func specialize() {
        mediumImpact.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
            self?.rigidImpact.impactOccurred(intensity: 0.8)
        }
    }

    // MARK: - Cosmic Events

    /// A new Cosmic Event window just began — subtle nudge to look at the banner.
    func eventStart()  { rigidImpact.impactOccurred(intensity: 0.7) }

    /// The active Cosmic Event just expired.
    func eventEnd()    { softImpact.impactOccurred(intensity: 0.5) }

    // MARK: - Daily reward

    func dailyClaim()  { notification.notificationOccurred(.success) }

    // MARK: - Feedback

    func error()       { notification.notificationOccurred(.error) }
}
