import AppKit
import JottedCore
import SwiftUI

@MainActor
final class TaskEditorWindowController: NSObject {
    private let store: TodoStore
    private let localization: AppLocalization
    private weak var parentWindow: NSWindow?
    private var panel: TaskEditorPanel?
    private var hostingController: NSHostingController<TaskEditorWindowRoot>?

    private(set) var presentedContext: TaskEditorContext?

    var isEditorVisible: Bool {
        panel?.isVisible == true
    }

    init(store: TodoStore, localization: AppLocalization = .shared) {
        self.store = store
        self.localization = localization
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localizationDidChange),
            name: AppLocalization.didChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func attach(parentWindow: NSWindow) {
        self.parentWindow = parentWindow
    }

    func present(
        context: TaskEditorContext,
        activate: Bool = true,
        visuallyHidden: Bool = false
    ) {
        presentedContext = context
        let panel = editorPanel()
        refreshTitle()

        let rootView = makeRootView(for: context)
        if let hostingController {
            hostingController.rootView = rootView
        } else {
            let controller = NSHostingController(rootView: rootView)
            controller.view.wantsLayer = true
            controller.view.layer?.backgroundColor = NSColor.clear.cgColor
            panel.contentViewController = controller
            hostingController = controller
        }

        panel.alphaValue = visuallyHidden ? 0 : 1
        panel.ignoresMouseEvents = visuallyHidden
        position(panel)

        if let parentWindow {
            if panel.parent !== parentWindow {
                panel.parent?.removeChildWindow(panel)
                parentWindow.addChildWindow(panel, ordered: .above)
            }
            panel.level = parentWindow.level
            panel.collectionBehavior = parentWindow.collectionBehavior
        }

        if activate {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFront(nil)
        }
    }

    func dismiss() {
        presentedContext = nil
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
    }

    func refreshTitle() {
        guard let panel else { return }
        let key: L10n.Key = presentedContext?.item == nil ? .createEditorTitle : .editEditorTitle
        panel.title = localization.text(key)
    }

    func refreshLocalization() {
        refreshTitle()
    }

    @objc private func localizationDidChange() {
        refreshLocalization()
    }

    private func editorPanel() -> TaskEditorPanel {
        if let panel { return panel }

        let size = JottedLayout.taskEditorWindowSize
        let panel = TaskEditorPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier("JottedTaskEditorWindow")
        panel.title = localization.text(.editEditorTitle)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        panel.onCancel = { [weak self] in
            self?.dismiss()
        }
        self.panel = panel
        return panel
    }

    private func makeRootView(for context: TaskEditorContext) -> TaskEditorWindowRoot {
        TaskEditorWindowRoot(
            context: context,
            onCancel: { [weak self] in
                self?.dismiss()
            },
            onSave: { [weak self] draft in
                self?.save(draft, in: context)
            }
        )
    }

    private func save(_ draft: TaskDraft, in context: TaskEditorContext) {
        switch context.mode {
        case .create:
            _ = store.add(
                title: draft.title,
                deadline: draft.deadline,
                priority: draft.priority,
                isAllDay: draft.isAllDay
            )
        case let .edit(item):
            store.update(
                item,
                title: draft.title,
                deadline: draft.deadline,
                priority: draft.priority,
                isAllDay: draft.isAllDay
            )
        }
        dismiss()
    }

    private func position(_ panel: NSWindow) {
        guard let parentWindow else {
            panel.center()
            return
        }

        let parentFrame = parentWindow.frame
        let screenFrame = (parentWindow.screen ?? NSScreen.main)?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? parentFrame.insetBy(dx: -500, dy: -500)
        let size = panel.frame.size
        let editorShadowInset: CGFloat = 28
        let boardCardInset = JottedLayout.windowInset
        let visualGap: CGFloat = 10

        let leftOriginX = parentFrame.minX + boardCardInset - visualGap
            - (size.width - editorShadowInset)
        let rightOriginX = parentFrame.maxX - boardCardInset + visualGap
            - editorShadowInset
        let preferredX = leftOriginX >= screenFrame.minX
            ? leftOriginX
            : rightOriginX
        let preferredY = parentFrame.maxY - boardCardInset
            + editorShadowInset - size.height

        let safeFrame = screenFrame.insetBy(dx: 6, dy: 6)
        let x = clampedOrigin(
            preferredX,
            minimum: safeFrame.minX,
            maximum: safeFrame.maxX - size.width
        )
        let y = clampedOrigin(
            preferredY,
            minimum: safeFrame.minY,
            maximum: safeFrame.maxY - size.height
        )
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func clampedOrigin(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard maximum >= minimum else { return minimum }
        return min(max(value, minimum), maximum)
    }
}

private struct TaskEditorWindowRoot: View {
    let context: TaskEditorContext
    let onCancel: () -> Void
    let onSave: (TaskDraft) -> Void

    var body: some View {
        ZStack {
            Color.clear
            TaskEditorView(
                context: context,
                onCancel: onCancel,
                onSave: onSave
            )
            .id(context.id)
        }
        .frame(
            width: JottedLayout.taskEditorWindowSize.width,
            height: JottedLayout.taskEditorWindowSize.height
        )
        .background(Color.clear)
    }
}

private final class TaskEditorPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
