import XCTest

/// Walks the demo: provider asks, patient approves on the Ledger, provider verifies.
/// Needs the emulator running and someone (or a script) approving on its screen.
final class DemoFlowUITests: XCTestCase {
    func testProviderRequestToVerifiedProof() throws {
        let probe = URLSession.shared.synchronousStatus(URL(string: "http://localhost:5005/")!)
        try XCTSkipUnless(probe == 200, "Ledger emulator not running (scripts/speculos.sh)")
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Provider"].tap()
        app.buttons["McDonald Theatre"].tap()
        attach(app, "0-provider")
        app.buttons["Send request"].tap()

        app.tabBars.buttons["Wallet"].tap()
        let approve = app.buttons["Approve on Ledger"]
        XCTAssertTrue(approve.waitForExistence(timeout: 5))
        approve.tap()
        sleep(2)
        attach(app, "1-waiting-for-ledger")

        // Shared proof appears once the Ledger signs.
        let shared = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'No provider holds a valid proof'")).firstMatch
        XCTAssertTrue(shared.waitForNonExistence(timeout: 90))
        attach(app, "2-wallet-after-approval")

        app.tabBars.buttons["Provider"].tap()
        app.swipeUp()
        app.swipeUp()
        let open = app.buttons["open-proof"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        let verified = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Verified'")).firstMatch
        XCTAssertTrue(verified.waitForExistence(timeout: 5))
        attach(app, "3-provider-verified")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}

private extension URLSession {
    func synchronousStatus(_ url: URL) -> Int? {
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var status: Int?
        dataTask(with: url) { _, response, _ in
            status = (response as? HTTPURLResponse)?.statusCode
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 3)
        return status
    }
}
