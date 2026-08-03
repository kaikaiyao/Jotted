import CoreGraphics
import XCTest
@testable import JottedCore

final class AdaptiveBoardLayoutTests: XCTestCase {
    private let entry = CGSize(width: 352, height: 332)
    private let returnSize = CGSize(width: 376, height: 368)

    func testFullModeCondensesWhenEitherDimensionCrossesEntryThreshold() {
        XCTAssertEqual(resolve(.full, CGSize(width: 351, height: 500)), .condensed)
        XCTAssertEqual(resolve(.full, CGSize(width: 500, height: 331)), .condensed)
    }

    func testFullModeStaysFullInsideHysteresisBand() {
        XCTAssertEqual(resolve(.full, CGSize(width: 360, height: 350)), .full)
    }

    func testCondensedModeStaysCondensedUntilBothDimensionsRecover() {
        XCTAssertEqual(resolve(.condensed, CGSize(width: 376, height: 360)), .condensed)
        XCTAssertEqual(resolve(.condensed, CGSize(width: 360, height: 368)), .condensed)
    }

    func testCondensedModeReturnsToFullAfterBothDimensionsRecover() {
        XCTAssertEqual(resolve(.condensed, CGSize(width: 376, height: 368)), .full)
    }

    private func resolve(_ mode: AdaptiveBoardMode, _ size: CGSize) -> AdaptiveBoardMode {
        AdaptiveBoardLayout.resolvedMode(
            current: mode,
            size: size,
            condensedEntrySize: entry,
            fullReturnSize: returnSize
        )
    }
}
