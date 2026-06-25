import UIKit
import Observation

@MainActor
@Observable
final class HapticsManager {
    private let lightImpact   = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact  = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact   = UIImpactFeedbackGenerator(style: .heavy)
    private let notification  = UINotificationFeedbackGenerator()

    init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notification.prepare()
    }

    func tap()       { mediumImpact.impactOccurred(intensity: 0.6) }
    func purchase()  { lightImpact.impactOccurred(intensity: 0.9) }
    func upgrade()   { notification.notificationOccurred(.success) }
    func bigBang()   { heavyImpact.impactOccurred(intensity: 1.0) }
    func error()     { notification.notificationOccurred(.error) }
}
