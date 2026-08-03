import AppKit
import JottedCore

final class PanelContentContainerView: NSView {
    let resizeOverlay: WindowResizeOverlayView

    init(hostingView: NSView, resizeOverlay: WindowResizeOverlayView) {
        self.resizeOverlay = resizeOverlay
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        resizeOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        addSubview(resizeOverlay, positioned: .above, relativeTo: hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            resizeOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            resizeOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            resizeOverlay.topAnchor.constraint(equalTo: topAnchor),
            resizeOverlay.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class WindowResizeOverlayView: NSView {
    // The visible card sits inside a transparent 16 pt shadow inset. A 32 pt
    // band therefore covers that entire inset plus 16 pt inside the card,
    // making the resize cursor easy to acquire without covering any controls.
    private let edgeHitWidth: CGFloat = 32
    private let cornerHitSize: CGFloat = 32

    private var activeEdge: WindowResizeEdge?
    private var startingFrame: NSRect?
    private var startingMouseLocation: NSPoint?

    override var isFlipped: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Keep the generous resize target for primary-button drags, while
        // allowing the board's context menu to work right up to every edge.
        if NSApp.currentEvent?.type == .rightMouseDown {
            return nil
        }
        return resizeEdge(at: point) == nil ? nil : self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        for (edge, rect) in cursorRegions() where !rect.isEmpty {
            addCursorRect(rect.intersection(bounds), cursor: cursor(for: edge))
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let edge = resizeEdge(at: point) {
            cursor(for: edge).set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window,
              window.styleMask.contains(.resizable),
              let edge = resizeEdge(at: convert(event.locationInWindow, from: nil)) else {
            return
        }

        window.makeKey()
        activeEdge = edge
        startingFrame = window.frame
        startingMouseLocation = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let edge = activeEdge,
              let startingFrame,
              let startingMouseLocation else { return }

        let current = NSEvent.mouseLocation
        let delta = CGSize(
            width: current.x - startingMouseLocation.x,
            height: current.y - startingMouseLocation.y
        )
        let frame = WindowResizeGeometry.resizedFrame(
            starting: startingFrame,
            mouseDelta: delta,
            edge: edge,
            minimumSize: window.minSize,
            maximumSize: window.maxSize
        )
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        activeEdge = nil
        startingFrame = nil
        startingMouseLocation = nil
    }

    func refreshCursorRects() {
        window?.invalidateCursorRects(for: self)
    }

    private var allowsVerticalResize: Bool {
        guard let window else { return true }
        return window.maxSize.height - window.minSize.height > 0.5
    }

    private var cardFrame: NSRect {
        bounds.insetBy(dx: JottedLayout.windowInset, dy: JottedLayout.windowInset)
    }

    private func resizeEdge(at point: NSPoint) -> WindowResizeEdge? {
        for (edge, rect) in cursorRegions() where rect.contains(point) {
            return edge
        }
        return nil
    }

    private func cursorRegions() -> [(WindowResizeEdge, NSRect)] {
        let card = cardFrame
        let halfBand = edgeHitWidth / 2
        let halfCorner = cornerHitSize / 2

        if !allowsVerticalResize {
            return [
                (
                    .left,
                    NSRect(
                        x: card.minX - halfBand,
                        y: card.minY - halfCorner,
                        width: edgeHitWidth,
                        height: card.height + cornerHitSize
                    )
                ),
                (
                    .right,
                    NSRect(
                        x: card.maxX - halfBand,
                        y: card.minY - halfCorner,
                        width: edgeHitWidth,
                        height: card.height + cornerHitSize
                    )
                )
            ]
        }

        let topLeft = NSRect(
            x: card.minX - halfCorner,
            y: card.maxY - halfCorner,
            width: cornerHitSize,
            height: cornerHitSize
        )
        let topRight = NSRect(
            x: card.maxX - halfCorner,
            y: card.maxY - halfCorner,
            width: cornerHitSize,
            height: cornerHitSize
        )
        let bottomLeft = NSRect(
            x: card.minX - halfCorner,
            y: card.minY - halfCorner,
            width: cornerHitSize,
            height: cornerHitSize
        )
        let bottomRight = NSRect(
            x: card.maxX - halfCorner,
            y: card.minY - halfCorner,
            width: cornerHitSize,
            height: cornerHitSize
        )

        return [
            (.topLeft, topLeft),
            (.topRight, topRight),
            (.bottomLeft, bottomLeft),
            (.bottomRight, bottomRight),
            (
                .left,
                NSRect(
                    x: card.minX - halfBand,
                    y: card.minY + halfCorner,
                    width: edgeHitWidth,
                    height: max(0, card.height - cornerHitSize)
                )
            ),
            (
                .right,
                NSRect(
                    x: card.maxX - halfBand,
                    y: card.minY + halfCorner,
                    width: edgeHitWidth,
                    height: max(0, card.height - cornerHitSize)
                )
            ),
            (
                .top,
                NSRect(
                    x: card.minX + halfCorner,
                    y: card.maxY - halfBand,
                    width: max(0, card.width - cornerHitSize),
                    height: edgeHitWidth
                )
            ),
            (
                .bottom,
                NSRect(
                    x: card.minX + halfCorner,
                    y: card.minY - halfBand,
                    width: max(0, card.width - cornerHitSize),
                    height: edgeHitWidth
                )
            )
        ]
    }

    private func cursor(for edge: WindowResizeEdge) -> NSCursor {
        if #available(macOS 15.0, *) {
            let position: NSCursor.FrameResizePosition
            switch edge {
            case .left: position = .left
            case .right: position = .right
            case .top: position = .top
            case .bottom: position = .bottom
            case .topLeft: position = .topLeft
            case .topRight: position = .topRight
            case .bottomLeft: position = .bottomLeft
            case .bottomRight: position = .bottomRight
            }
            return NSCursor.frameResize(position: position, directions: .all)
        }

        switch edge {
        case .left, .right:
            return .resizeLeftRight
        case .top, .bottom:
            return .resizeUpDown
        case .topLeft, .bottomRight:
            return Self.diagonalCursor(
                symbolName: "arrow.up.left.and.arrow.down.right",
                fallback: .resizeLeftRight
            )
        case .topRight, .bottomLeft:
            return Self.diagonalCursor(
                symbolName: "arrow.up.right.and.arrow.down.left",
                fallback: .resizeLeftRight
            )
        }
    }

    private static func diagonalCursor(symbolName: String, fallback: NSCursor) -> NSCursor {
        let configuration = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil),
              let image = symbol.withSymbolConfiguration(configuration) else {
            return fallback
        }
        image.isTemplate = true
        image.size = NSSize(width: 20, height: 20)
        return NSCursor(image: image, hotSpot: NSPoint(x: 10, y: 10))
    }
}
