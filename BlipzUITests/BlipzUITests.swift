//
//  BlipzUITests.swift
//  BlipzUITests
//
//  Created by Shayan Manoharan on 6/1/26.
//

import XCTest

final class BlipzUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    /// Live, read-only navigation. No launch fixtures or gameplay submissions.
    @MainActor
    func testLiveTabScreenshots() throws {
        let app = XCUIApplication()
        app.launch()
        let today = app.tabBars.buttons["Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 30), app.debugDescription)
        for title in ["Today", "Ranks", "You"] {
            app.tabBars.buttons[title].tap()
            let stableLabel = title == "Today" ? "A little more curious." : title
            _ = app.staticTexts[stableLabel].waitForExistence(timeout: 10)
            // Let the live GET responses settle before recording visual evidence.
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !app.activityIndicators.firstMatch.exists
            }, object: nil)
            _ = XCTWaiter.wait(for: [settled], timeout: 15)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Live \(title)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
