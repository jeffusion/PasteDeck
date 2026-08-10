import XCTest
@testable import PasteDeck

final class RetentionSliderTests: XCTestCase {
    func testMajorUnitsAlignWithTheirLabeledValues() {
        XCTAssertEqual(RetentionScale.visualValue(forDays: 1), 0, accuracy: 0.000_001)
        XCTAssertEqual(RetentionScale.visualValue(forDays: 7), 0.25, accuracy: 0.000_001)
        XCTAssertEqual(RetentionScale.visualValue(forDays: 30), 0.45, accuracy: 0.000_001)
        XCTAssertEqual(RetentionScale.visualValue(forDays: 365), 0.9, accuracy: 0.000_001)
        XCTAssertEqual(RetentionScale.visualValue(forDays: -1), 1, accuracy: 0.000_001)
    }

    func testEquivalentBoundaryValuesAreNotDuplicated() {
        XCTAssertFalse(RetentionScale.supportedDays.contains(28))
        XCTAssertTrue(RetentionScale.supportedDays.contains(30))
        XCTAssertFalse(RetentionScale.supportedDays.contains(360))
        XCTAssertTrue(RetentionScale.supportedDays.contains(365))
    }

    func testEverySupportedValueRoundTripsThroughTheVisualScale() {
        for days in RetentionScale.supportedDays {
            let visualValue = RetentionScale.visualValue(forDays: days)
            XCTAssertEqual(RetentionScale.days(closestTo: visualValue), days)
        }
    }

    func testSupportedOptionsDoNotShareVisualPositions() {
        let visualValues = RetentionScale.options.map(\.visualValue)
        XCTAssertEqual(Set(visualValues).count, visualValues.count)
    }
}
