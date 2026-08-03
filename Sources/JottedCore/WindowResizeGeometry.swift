import CoreGraphics

public enum WindowResizeEdge: String, CaseIterable, Sendable {
    case left
    case right
    case top
    case bottom
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public var includesLeft: Bool {
        self == .left || self == .topLeft || self == .bottomLeft
    }

    public var includesRight: Bool {
        self == .right || self == .topRight || self == .bottomRight
    }

    public var includesTop: Bool {
        self == .top || self == .topLeft || self == .topRight
    }

    public var includesBottom: Bool {
        self == .bottom || self == .bottomLeft || self == .bottomRight
    }
}

public enum WindowResizeGeometry {
    public static func resizedFrame(
        starting frame: CGRect,
        mouseDelta: CGSize,
        edge: WindowResizeEdge,
        minimumSize: CGSize,
        maximumSize: CGSize
    ) -> CGRect {
        let maximumWidth = max(minimumSize.width, maximumSize.width)
        let maximumHeight = max(minimumSize.height, maximumSize.height)

        let rawWidth: CGFloat
        if edge.includesLeft {
            rawWidth = frame.width - mouseDelta.width
        } else if edge.includesRight {
            rawWidth = frame.width + mouseDelta.width
        } else {
            rawWidth = frame.width
        }

        let rawHeight: CGFloat
        if edge.includesBottom {
            rawHeight = frame.height - mouseDelta.height
        } else if edge.includesTop {
            rawHeight = frame.height + mouseDelta.height
        } else {
            rawHeight = frame.height
        }

        let width = min(max(rawWidth, minimumSize.width), maximumWidth)
        let height = min(max(rawHeight, minimumSize.height), maximumHeight)
        let x = edge.includesLeft ? frame.maxX - width : frame.minX
        let y = edge.includesBottom ? frame.maxY - height : frame.minY

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
