import CoreGraphics
import XCTest
@testable import JottedCore

final class WindowResizeGeometryTests: XCTestCase {
    private let startingFrame = CGRect(x: 100, y: 200, width: 400, height: 500)
    private let minimumSize = CGSize(width: 300, height: 350)
    private let maximumSize = CGSize(width: 600, height: 700)

    func testBottomLeftKeepsOppositeCornerAnchored() {
        let result = WindowResizeGeometry.resizedFrame(
            starting: startingFrame,
            mouseDelta: CGSize(width: -50, height: -40),
            edge: .bottomLeft,
            minimumSize: minimumSize,
            maximumSize: maximumSize
        )

        XCTAssertEqual(result, CGRect(x: 50, y: 160, width: 450, height: 540))
        XCTAssertEqual(result.maxX, startingFrame.maxX)
        XCTAssertEqual(result.maxY, startingFrame.maxY)
    }

    func testTopRightGrowsFromFixedOrigin() {
        let result = WindowResizeGeometry.resizedFrame(
            starting: startingFrame,
            mouseDelta: CGSize(width: 80, height: 60),
            edge: .topRight,
            minimumSize: minimumSize,
            maximumSize: maximumSize
        )

        XCTAssertEqual(result, CGRect(x: 100, y: 200, width: 480, height: 560))
    }

    func testLeftResizeClampsAtMinimumWithoutAnchorDrift() {
        let result = WindowResizeGeometry.resizedFrame(
            starting: startingFrame,
            mouseDelta: CGSize(width: 250, height: 0),
            edge: .left,
            minimumSize: minimumSize,
            maximumSize: maximumSize
        )

        XCTAssertEqual(result.width, 300)
        XCTAssertEqual(result.maxX, startingFrame.maxX)
        XCTAssertEqual(result.minX, 200)
    }

    func testBottomResizeClampsAtMaximumWithoutAnchorDrift() {
        let result = WindowResizeGeometry.resizedFrame(
            starting: startingFrame,
            mouseDelta: CGSize(width: 0, height: -500),
            edge: .bottom,
            minimumSize: minimumSize,
            maximumSize: maximumSize
        )

        XCTAssertEqual(result.height, 700)
        XCTAssertEqual(result.maxY, startingFrame.maxY)
        XCTAssertEqual(result.minY, 0)
    }
}
