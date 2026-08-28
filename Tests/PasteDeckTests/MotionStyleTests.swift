import XCTest
@testable import PasteDeck

final class MotionStyleTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "MotionStyleTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testRawValuesAreStable() {
        XCTAssertEqual(MotionStyle.nativeSnappy.rawValue, "nativeSnappy")
        XCTAssertEqual(MotionStyle.spatialSpring.rawValue, "spatialSpring")
        XCTAssertEqual(MotionStyle.softMaterial.rawValue, "softMaterial")
    }

    func testCurrentDefaultsToNativeSnappy() {
        XCTAssertEqual(MotionStyle.defaultValue, .nativeSnappy)
        XCTAssertEqual(MotionStyle.current(in: defaults), .nativeSnappy)
    }

    func testCurrentReturnsStoredStyle() {
        for style in MotionStyle.allCases {
            defaults.set(style.rawValue, forKey: MotionStyle.preferenceKey)
            XCTAssertEqual(MotionStyle.current(in: defaults), style)
        }
    }

    func testCurrentFallsBackForInvalidStoredStyle() {
        defaults.set("invalid", forKey: MotionStyle.preferenceKey)

        XCTAssertEqual(MotionStyle.current(in: defaults), .nativeSnappy)
    }

    func testMotionSpeedRawValuesAreStable() {
        XCTAssertEqual(MotionSpeed.fast.rawValue, "fast")
        XCTAssertEqual(MotionSpeed.normal.rawValue, "normal")
        XCTAssertEqual(MotionSpeed.slow.rawValue, "slow")
    }

    func testMotionSpeedConformsToCaseIterableAndIdentifiable() {
        XCTAssertEqual(MotionSpeed.allCases, [.fast, .normal, .slow])
        XCTAssertEqual(MotionSpeed.fast.id, "fast")
    }

    func testMotionSpeedDurationMultipliers() {
        XCTAssertEqual(MotionSpeed.fast.durationMultiplier, 0.75)
        XCTAssertEqual(MotionSpeed.normal.durationMultiplier, 1.0)
        XCTAssertEqual(MotionSpeed.slow.durationMultiplier, 1.5)
    }

    func testCurrentMotionSpeedDefaultsToNormal() {
        XCTAssertEqual(MotionSpeed.defaultValue, .normal)
        XCTAssertEqual(MotionSpeed.current(in: defaults), .normal)
    }

    func testCurrentReturnsStoredMotionSpeed() {
        for speed in MotionSpeed.allCases {
            defaults.set(speed.rawValue, forKey: MotionSpeed.preferenceKey)
            XCTAssertEqual(MotionSpeed.current(in: defaults), speed)
        }
    }

    func testCurrentMotionSpeedFallsBackForInvalidStoredValue() {
        defaults.set("invalid", forKey: MotionSpeed.preferenceKey)

        XCTAssertEqual(MotionSpeed.current(in: defaults), .normal)
    }
}
