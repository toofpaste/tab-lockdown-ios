import XCTest

final class BrowserTests: XCTestCase {
    func testBrowsingProtectionReloadAndVideoDiscovery() {
        let app = XCUIApplication()
        app.launch()
        let address = app.textFields["address"]
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        address.tap()
        address.typeText("http://127.0.0.1:18765/index.html")
        app.buttons["go"].tap()

        let next = app.webViews.links["Same host"]
        XCTAssertTrue(next.waitForExistence(timeout: 20))
        next.tap()
        XCTAssertTrue(app.webViews.staticTexts["Second page"].waitForExistence(timeout: 10))
        XCTAssertTrue((address.value as? String ?? "").contains("second.html"))
        app.buttons["reload"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Second page"].waitForExistence(timeout: 10))
        XCTAssertTrue((address.value as? String ?? "").contains("second.html"))

        app.webViews.links["Other host"].tap()
        XCTAssertTrue(app.staticTexts["Navigation blocked. Turn off hostname lockdown to change sites."].waitForExistence(timeout: 5))
        XCTAssertTrue((address.value as? String ?? "").contains("127.0.0.1"))
        app.webViews.links["New tab"].tap()
        XCTAssertTrue(app.staticTexts["Popup blocked."].waitForExistence(timeout: 5))

        app.buttons["find-video"].tap()
        XCTAssertTrue(app.buttons["Play HLS"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        app.switches["lock-toggle"].tap()
        app.webViews.links["Other host"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Other hostname page"].waitForExistence(timeout: 10))
        XCTAssertTrue((address.value as? String ?? "").contains("localhost"))
        app.webViews.links["New tab"].tap()
        XCTAssertTrue(app.staticTexts["Popup blocked."].waitForExistence(timeout: 5))
    }
}
