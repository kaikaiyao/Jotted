import AppKit
import Combine
import Foundation
import JottedCore

enum BoardPresentationMode: Equatable {
    case full
    case condensed
}

@MainActor
final class WindowCoordinator: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var presentationMode: BoardPresentationMode
    @Published private(set) var isPinned: Bool

    var isCondensed: Bool { presentationMode == .condensed }

    weak var window: NSWindow?
    var onPinStateChange: ((Bool) -> Void)?

    private let defaults: UserDefaults
    private let pinnedKey = "JottedIsPinned"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.presentationMode = .full
        self.isPinned = defaults.bool(forKey: pinnedKey)
        super.init()
    }

    func attach(window: NSWindow) {
        self.window = window
        window.delegate = self
        configureWindowConstraints()
        presentationMode = presentationMode(for: window.frame.size, initial: true)
    }

    func show(activate: Bool) {
        guard let window else { return }
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    func hide() {
        window?.orderOut(nil)
    }

    func toggleVisibility() {
        if window?.isVisible == true {
            hide()
        } else {
            show(activate: true)
        }
    }

    func togglePinned() {
        isPinned.toggle()
        defaults.set(isPinned, forKey: pinnedKey)
        window?.level = isPinned ? .floating : .normal
        onPinStateChange?(isPinned)
    }

    func windowDidResize(_ notification: Notification) {
        guard let size = window?.frame.size else { return }
        presentationMode = presentationMode(for: size, initial: false)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let size = window?.frame.size else { return }
        presentationMode = presentationMode(for: size, initial: false)
    }

    private func presentationMode(for size: NSSize, initial: Bool) -> BoardPresentationMode {
        let mode: AdaptiveBoardMode
        if initial {
            mode = AdaptiveBoardLayout.initialMode(
                for: size,
                fullReturnSize: JottedLayout.fullReturnWindowSize
            )
        } else {
            let current: AdaptiveBoardMode = presentationMode == .full ? .full : .condensed
            mode = AdaptiveBoardLayout.resolvedMode(
                current: current,
                size: size,
                condensedEntrySize: JottedLayout.condensedEntryWindowSize,
                fullReturnSize: JottedLayout.fullReturnWindowSize
            )
        }
        return mode == .full ? .full : .condensed
    }

    private func configureWindowConstraints() {
        guard let window else { return }
        window.level = isPinned ? .floating : .normal
        window.minSize = JottedLayout.minimumExpandedWindowSize
        window.maxSize = JottedLayout.maximumWindowSize
    }
}
