import XCTest

/// v4.0 — walks every screen on the `-cosmicaDemo` save and attaches a screenshot of
/// each (named NN-screen). CI exports them from the .xcresult and pushes them to the
/// `ci-screens` branch for the visual audit. Not part of the main test scheme.
final class ScreensUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-cosmicaDemo"]
        app.launch()
        sleep(4)   // splash (1.7 s) + fade
    }

    func test_captureEveryScreen() {
        snap("01-observatory")
        tab("Upgrades");  snap("02-upgrades")
        tab("Shop");      snap("03-shop-top")
        app.swipeUp(); app.swipeUp(); snap("04-shop-lower")
        tab("Settings");  snap("05-settings")
        tab("Big Bang");  snap("06-bigbang-top")
        app.swipeUp(); snap("07-bigbang-mid")
        app.swipeUp(); snap("08-bigbang-lower")

        for (i, name) in ["Cosmic Tree", "Achievements", "Cosmic Wonders", "True Cosmos", "Multiverse", "Omniverse"].enumerated() {
            tab("Big Bang")
            guard open(name) else { continue }
            sleep(1)
            snap(String(format: "%02d-%@", 10 + i * 2, slug(name)))
            app.swipeUp()
            snap(String(format: "%02d-%@-lower", 11 + i * 2, slug(name)))
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        // v4.0 — Rifts sit under the Omniverse.
        tab("Big Bang")
        if open("Omniverse"), open("Rifts") {
            sleep(1); snap("22-rifts"); app.swipeUp(); snap("23-rifts-lower")
        }
    }

    // MARK: Helpers

    private func tab(_ label: String) {
        let button = app.tabBars.buttons[label]
        if button.waitForExistence(timeout: 3) { button.tap() }
        sleep(1)
    }

    /// Scrolls the Big Bang tab until a link whose label mentions `name` appears, then taps it.
    @discardableResult
    private func open(_ name: String) -> Bool {
        let link = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        for _ in 0..<6 {
            if link.exists && link.isHittable { link.tap(); return true }
            app.swipeUp()
        }
        return false
    }

    private func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func slug(_ s: String) -> String { s.lowercased().replacingOccurrences(of: " ", with: "-") }
}
