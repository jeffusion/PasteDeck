import AppKit
import XCTest
@testable import PasteDeck

@MainActor
final class BrandAssetTests: XCTestCase {
    func testMenuBarIconResourceIsBundled() {
        XCTAssertNotNil(
            Bundle.main.url(
                forResource: StatusBarIconProvider.resourceName,
                withExtension: "tiff"
            )
        )
    }

    func testMenuBarIconUsesExpectedTemplateConfiguration() {
        let image = StatusBarIconProvider.image()

        XCTAssertEqual(image.size.width, 18, accuracy: 0.01)
        XCTAssertEqual(image.size.height, 18, accuracy: 0.01)
        XCTAssertEqual(image.representations.count, 2)
        XCTAssertTrue(image.isTemplate)
    }

    func testAppLinksPointToCanonicalRepository() {
        XCTAssertEqual(AppLinks.repository.absoluteString, "https://github.com/jeffusion/PasteDeck")
        XCTAssertEqual(AppLinks.issues.absoluteString, "https://github.com/jeffusion/PasteDeck/issues")
    }
}
