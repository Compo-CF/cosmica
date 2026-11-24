import XCTest
import ObjectiveC

/// Ad capture: one test per Meta ad clip, run by .github/workflows/ad-clips.yml while
/// `simctl io recordVideo` films the simulator. Each launches with `-cosmicaDemo
/// -cosmicaAdClip <scene>` (Cosmica/App/AdClipMode.swift) and plays at a human pace.
/// Skipped unless the runner sets COSMICA_AD_CLIPS=1 (xcodebuild: TEST_RUNNER_COSMICA_AD_CLIPS=1),
/// so the screenshot walk in the same scheme never runs them.
final class AdClipsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["COSMICA_AD_CLIPS"] == "1",
                          "ad clips run only from ad-clips.yml")
        continueAfterFailure = true
        Quiescence.disable()   // the game animates nonstop; don't wait for idle before each tap
    }

    // MARK: Clips

    /// a — numbers that never stop: a fresh run, automation buying, orb taps, Max buys.
    func test_clip_a() {
        launch("a")
        mark("scene")
        tapOrb(count: 18, every: 0.22)
        tapButton("Max")                        // buy mode: Max
        mark("max")
        for round in 0..<7 {
            tapBuyRow(round % 3)
            tapOrb(count: 8, every: 0.22)
        }
        mark("end")
        pause(1.5)
    }

    /// b — a Big Bang: watch the run, open the Big Bang tab, claim, confirm, collapse, re-climb.
    func test_clip_b() {
        launch("b")
        mark("scene")
        tapOrb(count: 12, every: 0.25)
        tab("Big Bang")
        mark("bigbang-tab")
        pause(2.0)
        let claim = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Big Bang —")).firstMatch
        for _ in 0..<8 where !(claim.exists && claim.isHittable) {
            app.swipeUp(velocity: .slow)
            pause(0.7)
        }
        pause(0.8)
        claim.tap()
        mark("confirm-dialog")
        pause(1.4)
        let confirm = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Big Bang (")).firstMatch
        if confirm.waitForExistence(timeout: 3) { confirm.tap() }
        mark("confirmed")
        pause(0.3)
        scrollToTop()
        pause(4.5)
        mark("after")
        tab("Observatory")
        mark("reclimb")
        tapOrb(count: 26, every: 0.23)
        mark("end")
        pause(1.0)
    }

    /// c — every layer in its own colours, then into a Rift and a fresh run.
    func test_clip_c() {
        launch("c")
        mark("scene")
        tapOrb(count: 8, every: 0.25)
        tab("Big Bang")
        mark("bigbang-tab")
        pause(1.2)
        for name in ["True Cosmos", "Multiverse"] {
            if open(name) {
                mark(name)
                pause(2.2)
                back()
                pause(0.8)
            }
        }
        if open("Omniverse") {
            mark("Omniverse")
            pause(2.0)
            if open("Rifts") {
                mark("Rifts")
                pause(1.8)
                let enter = app.buttons["Enter"].firstMatch
                if enter.waitForExistence(timeout: 3) { enter.tap() }
                pause(1.2)
                let go = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Enter (")).firstMatch
                if go.waitForExistence(timeout: 3) { go.tap() }
                mark("rift-entered")
                pause(1.5)
            }
        }
        tab("Observatory")
        mark("rift-run")
        tapOrb(count: 26, every: 0.23)
        mark("end")
        pause(1.0)
    }

    // MARK: Helpers

    private func launch(_ scene: String) {
        app = XCUIApplication()
        app.launchArguments = ["-cosmicaDemo", "-cosmicaAdClip", scene]
        mark("launch")
        app.launch()
        pause(3.2)   // splash (1.7 s) + fade
    }

    private func pause(_ s: Double) { Thread.sleep(forTimeInterval: s) }

    /// Wall-clock marker in the log, used to trim the recording.
    private func mark(_ name: String) {
        print(String(format: "ADCLIP_MARK %@ %.3f", name, Date().timeIntervalSince1970))
    }

    private func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    /// The buy-mode "1" button sits just under the orb's tap zone.
    private var picker: CGRect {
        let one = app.buttons["1"].firstMatch
        return one.waitForExistence(timeout: 3) ? one.frame : CGRect(x: 0, y: app.frame.height * 0.55, width: 80, height: 30)
    }

    private func tapOrb(count: Int, every: Double) {
        let p = picker
        let target = point(app.frame.midX, p.minY - 100)
        for i in 0..<count {
            target.tap()
            pause(every + (i % 3 == 0 ? 0.04 : 0))
        }
    }

    /// Buy button of the n-th visible generator row (rows sit under the buy-mode picker).
    private func tapBuyRow(_ n: Int) {
        let p = picker
        let rowHeight: CGFloat = 86
        let y = p.maxY + 55 + CGFloat(n) * rowHeight
        point(app.frame.width * 0.83, y).tap()
        pause(0.35)
    }

    private func tapButton(_ label: String) {
        let b = app.buttons[label].firstMatch
        if b.waitForExistence(timeout: 3) { b.tap() }
        pause(0.5)
    }

    private func tab(_ label: String) {
        let button = app.tabBars.buttons[label]
        if button.waitForExistence(timeout: 3) { button.tap() }
        pause(1.0)
    }

    private func back() {
        let b = app.navigationBars.buttons.element(boundBy: 0)
        if b.exists { b.tap() }
    }

    /// Tap the status bar (scroll to top), then make sure with a quick fling.
    private func scrollToTop() {
        point(app.frame.midX, 8).tap()
        pause(0.45)
        let header = app.staticTexts["Prestige Reward"].firstMatch
        if !(header.exists && header.isHittable) {
            app.swipeDown(velocity: .fast)
        }
    }

    /// Scrolls until a link whose label mentions `name` appears, then taps it.
    @discardableResult
    private func open(_ name: String) -> Bool {
        let link = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        for _ in 0..<7 {
            if link.exists && link.isHittable { link.tap(); pause(0.6); return true }
            app.swipeUp(velocity: .slow)
            pause(0.6)
        }
        return false
    }
}

/// XCUITest waits for the app to go idle before and after every event. Cosmica animates
/// without pause (10 Hz counters, TimelineViews), so each tap would stall for seconds.
/// Swap the private wait for a no-op; if the selector isn't there, nothing changes.
private enum Quiescence {
    private static var done = false

    static func disable() {
        guard !done, let cls = NSClassFromString("XCUIApplicationProcess") else { return }
        done = true
        let two: @convention(block) (AnyObject, Bool, Bool) -> Void = { _, _, _ in }
        let one: @convention(block) (AnyObject, Bool) -> Void = { _, _ in }
        if let m = class_getInstanceMethod(cls, NSSelectorFromString("waitForQuiescenceIncludingAnimationsIdle:isPreEvent:")) {
            method_setImplementation(m, imp_implementationWithBlock(two))
        }
        if let m = class_getInstanceMethod(cls, NSSelectorFromString("waitForQuiescenceIncludingAnimationsIdle:")) {
            method_setImplementation(m, imp_implementationWithBlock(one))
        }
    }
}
