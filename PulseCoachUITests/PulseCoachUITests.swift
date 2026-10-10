import XCTest

/// End-to-end UI checks for the iPhone app. Every step also saves a screenshot
/// (kept in the .xcresult) so a reviewer can see each screen per device, theme and text size.
///
/// Extra launch arguments (appearance, Dynamic Type) can be injected from the command line:
/// `TEST_RUNNER_UI_EXTRA_ARGS="-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL"`.
@MainActor
final class PulseCoachUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = true
    }

    private func launch(_ args: [String]) {
        app = XCUIApplication()
        let extra = ProcessInfo.processInfo.environment["UI_EXTRA_ARGS"]?
            .split(separator: " ").map(String.init) ?? []
        app.launchArguments = args + extra
        // Notification / Health permission alerts belong to SpringBoard; accept them so flows continue.
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for label in ["Allow", "อนุญาต", "Turn On All", "เปิดทั้งหมด"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        app.launch()
    }

    /// Interruption monitors only fire on the next interaction, so nudge the app after async prompts.
    private func settleAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "อนุญาต"] where springboard.buttons[label].waitForExistence(timeout: 1) {
            springboard.buttons[label].tap()
        }
    }

    private func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Plan generation runs the on-device model first, which can take a while on the simulator.
    private func waitForToday(_ file: StaticString = #filePath, line: UInt = #line) {
        settleAlerts()
        XCTAssertTrue(app.staticTexts["แนะนำสำหรับวันนี้"].waitForExistence(timeout: 20), file: file, line: line)
        XCTAssertTrue(app.buttons["เปลี่ยนแผน"].waitForExistence(timeout: 40),
                      "Plan must appear within the planner timeout (DEF-02)", file: file, line: line)
        settleAlerts()
    }

    /// Taps a tab and waits for its navigation bar. The iOS 27 floating tab bar isn't always
    /// exposed under `tabBars` (e.g. at accessibility text sizes), so fall back to any button.
    private func openTab(_ label: String, expecting title: String) -> Bool {
        for attempt in 0..<2 {
            let tab = app.tabBars.buttons[label].exists ? app.tabBars.buttons[label] : app.buttons[label].firstMatch
            if tab.exists { tab.tap() }
            if app.navigationBars[title].waitForExistence(timeout: attempt == 0 ? 3 : 5) { return true }
        }
        return false
    }

    // MARK: - Flows

    func testOnboardingCreatesPlan() {
        launch(["-uiTestReset"])
        let next = app.buttons["ดำเนินการต่อ"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        snap("01 Welcome")
        next.tap()

        let create = app.buttons["สร้างแผนของฉัน"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        app.buttons["ลดน้ำหนัก"].firstMatch.tap()
        snap("02 Goal setup")
        XCTAssertTrue(create.isHittable, "Primary button must be reachable without scrolling")
        create.tap()

        waitForToday()
        snap("03 Today after onboarding")
    }

    func testTodayPlanBodyAndProfile() {
        launch(["-uiTestReset", "-uiTestOnboarded"])
        waitForToday()
        snap("10 Today")
        app.swipeUp()
        snap("11 Today scrolled")

        XCTAssertTrue(openTab("แผน", expecting: "แผน 7 วัน"))
        snap("20 Plan")

        let firstDay = app.collectionViews.buttons.element(boundBy: 0)
        if firstDay.waitForExistence(timeout: 5) { firstDay.tap() }
        snap("21 Plan day expanded")

        let easier = app.buttons["ขอเบาลง"]
        if easier.waitForExistence(timeout: 3), easier.isEnabled {
            easier.tap()
            XCTAssertTrue(app.buttons["เลิกทำ"].waitForExistence(timeout: 5), "Undo toast should appear after an edit")
            snap("22 Plan undo toast")
            app.buttons["เลิกทำ"].tap()
        }

        app.buttons["สร้างแผนใหม่"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["สร้างแผนใหม่?"].waitForExistence(timeout: 3),
                      "Regenerating must ask first (DEF-03)")
        snap("23 Plan regenerate confirm")
        let cancel = app.buttons["ยกเลิก"].exists ? app.buttons["ยกเลิก"] : app.buttons["Cancel"]
        if cancel.exists { cancel.firstMatch.tap() } else { app.tap() }
        _ = app.staticTexts["สร้างแผนใหม่?"].waitForNonExistence(timeout: 3)

        XCTAssertTrue(openTab("ร่างกาย", expecting: "ร่างกาย"))
        snap("30 Body")

        app.buttons["โปรไฟล์และการตั้งค่า"].firstMatch.tap()
        XCTAssertTrue(app.buttons["เสร็จสิ้น"].waitForExistence(timeout: 5))
        snap("40 Profile")
        app.swipeUp()
        snap("41 Profile scrolled")
        app.buttons["เสร็จสิ้น"].tap()
    }

    func testGymGuide() {
        launch(["-uiTestReset", "-uiTestOnboarded", "-gymGuide"])
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 20))
        sleep(2)
        snap("50 Gym guide")
        app.swipeUp()
        snap("51 Gym guide scrolled")
    }

    func testEmptyStateWithoutHealthData() {
        launch(["-uiTestReset", "-uiTestOnboarded", "-uiTestNoData"])
        waitForToday()
        XCTAssertTrue(app.staticTexts["ยังไม่มีข้อมูลสุขภาพ"].waitForExistence(timeout: 5),
                      "No data must never show a readiness score (DEF-01)")
        XCTAssertFalse(app.staticTexts["100"].exists)
        snap("60 Today no data")
        _ = openTab("ร่างกาย", expecting: "ร่างกาย")
        snap("61 Body no data")
    }
}
