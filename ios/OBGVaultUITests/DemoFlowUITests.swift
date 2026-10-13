import XCTest

/// Full demo: onboard (Ledger, Epic import, ZK proof, Ledger-signed registration),
/// then wait for a school's request and approve it on the Ledger.
/// Needs: scripts/speculos.sh, the web app (npm run dev in web/), someone approving
/// on the emulator screens, and a school requesting from the portal mid-test.
final class DemoFlowUITests: XCTestCase {
    func testOnboardThenApproveSchoolRequest() throws {
        try XCTSkipUnless(reachable("http://localhost:5005/") && reachable("http://localhost:3000/"),
                          "Needs the Ledger emulator and the web app running")
        let app = XCUIApplication()
        app.launchArguments = ["-resetForUITest"]
        app.launch()
        addUIInterruptionMonitor(withDescription: "Notifications") { alert in
            alert.buttons["Allow"].exists ? (alert.buttons["Allow"].tap(), true).1 : false
        }

        tap(app.buttons["Connect Ledger"], app)
        tap(app.buttons["Connect Epic MyChart"], app)
        tap(app.buttons["Review with AI"], app, timeout: 30)
        shot(app, "1-ai-review")
        tap(app.buttons["Generate proof"], app, timeout: 120)
        shot(app, "1-onboarding-proof")
        tap(app.buttons["Sign & register"], app, timeout: 30)
        shot(app, "2-onboarding-signing")

        // Registered once the vault appears; then wait for the school.
        XCTAssertTrue(app.staticTexts["ZERO-KNOWLEDGE PROOF"].waitForExistence(timeout: 120))
        shot(app, "3-vault")
        let approve = app.buttons["Approve on Ledger"]
        XCTAssertTrue(approve.waitForExistence(timeout: 240), "No school request arrived")
        app.tap() // trigger the interruption monitor if the permission alert is up
        shot(app, "4-request")
        approve.tap()
        let sent = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'Proof sent'")).firstMatch
        XCTAssertTrue(sent.waitForExistence(timeout: 120))
        shot(app, "5-sent")
    }

    private func tap(_ e: XCUIElement, _ app: XCUIApplication, timeout: TimeInterval = 15) {
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "Missing \(e)")
        if !e.isHittable { app.swipeUp() }
        e.tap()
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func reachable(_ s: String) -> Bool {
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var ok = false
        URLSession.shared.dataTask(with: URL(string: s)!) { _, r, _ in
            ok = (r as? HTTPURLResponse) != nil
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 3)
        return ok
    }
}
