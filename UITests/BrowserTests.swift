import XCTest

final class BrowserTests: XCTestCase {
    func testBrowsingProtectionReloadAndVideoDiscovery() {
        let app = XCUIApplication()
        app.launch()
        let address = app.textFields["address"]
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        address.tap()
        address.typeText("http://127.0.0.1:18765/index.html")
        app.buttons["navigate-button"].tap()

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
        let lock = app.switches["lock-toggle"]
        XCTAssertEqual(lock.value as? String, "1")
        lock.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Hostname lockdown off. Popups remain blocked."].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(lock.value as? String, "0")
        app.webViews.links["Other host"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Other hostname page"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue((address.value as? String ?? "").contains("localhost"))
        app.webViews.links["New tab"].tap()
        XCTAssertTrue(app.staticTexts["Popup blocked."].waitForExistence(timeout: 5))
    }
}
