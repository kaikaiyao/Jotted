import AppKit
import JottedCore
import SwiftUI

@main
struct JottedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let localization: AppLocalization
    private var panel: BoardPanel?
    private var statusItem: NSStatusItem?
    private var pinMenuItem: NSMenuItem?
    private var store: TodoStore?
    private var windowCoordinator: WindowCoordinator?
    private var taskEditorWindowController: TaskEditorWindowController?
    private var settingsWindow: SettingsPanel?
    private var launchAtLoginManager: LaunchAtLoginManager?
    private var previewDirectory: URL?

    override init() {
        localization = AppLocalization.shared
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let snapshotRequest = SnapshotRequest.from(arguments: CommandLine.arguments)
        let isSmokeTest = CommandLine.arguments.contains("--smoke-test")
        // Liquid Glass does not composite into `cacheDisplay` bitmaps, so the
        // snapshot pipeline draws the legacy glass surface instead.
        JottedGlass.forcesLegacySurface = snapshotRequest != nil
        let usesIsolatedState = snapshotRequest != nil || isSmokeTest
        if !usesIsolatedState {
            GlassTransparencyPreference.migrateIfNeeded()
            // Rewrites pre-1.8 theme identifiers so an existing user keeps the
            // equivalent new theme instead of silently reverting to default.
            AppearanceTheme.migrateStoredPreferenceIfNeeded()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettingsFromNotification(_:)),
            name: .jottedShowSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localizationDidChange(_:)),
            name: AppLocalization.didChangeNotification,
            object: localization
        )
        let store = usesIsolatedState
            ? makePreviewStore(
                language: localization.resolvedLanguage,
                condensed: snapshotRequest?.usesCondensedPreview == true
            )
            : TodoStore()
        let coordinatorDefaults: UserDefaults
        if usesIsolatedState {
            let suiteName = "com.kaiyao.Jotted.Snapshot"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            coordinatorDefaults = defaults
        } else {
            coordinatorDefaults = .standard
        }
        let launchAtLoginManager = LaunchAtLoginManager(defaults: coordinatorDefaults)
        let coordinator = WindowCoordinator(defaults: coordinatorDefaults)
        let editorController = TaskEditorWindowController(store: store)
        let panel = makePanel(
            store: store,
            coordinator: coordinator,
            editorController: editorController,
            snapshotMode: usesIsolatedState
        )

        self.store = store
        self.windowCoordinator = coordinator
        self.taskEditorWindowController = editorController
        self.launchAtLoginManager = launchAtLoginManager
        self.panel = panel

        coordinator.onPinStateChange = { [weak self] isPinned in
            self?.pinMenuItem?.state = isPinned ? .on : .off
            self?.pinMenuItem?.title = self?.localization.text(
                isPinned ? .stopKeepingOnTop : .keepOnTop
            ) ?? ""
        }
        coordinator.attach(window: panel)
        editorController.attach(parentWindow: panel)

        makeStatusItem()
        makeApplicationMenu()
        if !usesIsolatedState {
            launchAtLoginManager.synchronize()
        }

        if let snapshotRequest {
            let snapshotWindow: NSWindow
            switch snapshotRequest.target {
            case let .board(windowSize):
                panel.setFrame(
                    NSRect(origin: .zero, size: windowSize),
                    display: true
                )
                snapshotWindow = panel
            case .settings:
                snapshotWindow = makeSettingsWindow(manager: launchAtLoginManager)
            case .themeGallery:
                snapshotWindow = makeThemeGalleryWindow()
            }
            snapshotWindow.appearance = NSAppearance(
                named: snapshotRequest.isDark ? .darkAqua : .aqua
            )
            snapshotWindow.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.renderSnapshot(window: snapshotWindow, request: snapshotRequest)
            }
        } else if isSmokeTest {
            guard launchAtLoginManager.enabled else {
                fatalError("新安装未默认开启登录时启动")
            }
            let maximumLightAlpha = GlassTransparencyPreference.materialAlpha(
                value: 1,
                for: .light
            )
            let maximumDarkAlpha = GlassTransparencyPreference.materialAlpha(
                value: 1,
                for: .dark
            )
            guard maximumLightAlpha <= 0.381,
                  maximumDarkAlpha <= 0.411 else {
                fatalError("100% 通透度未达到增强透明范围")
            }
            panel.orderOut(nil)
            panel.setFrame(
                NSRect(origin: panel.frame.origin, size: JottedLayout.minimumExpandedWindowSize),
                display: true
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                guard coordinator.presentationMode == .condensed else {
                    fatalError("自适应简洁界面未在最小尺寸触发")
                }
                let condensedFrameBeforeEditor = panel.frame
                panel.alphaValue = 0
                panel.ignoresMouseEvents = true
                panel.orderFront(nil)
                panel.contentView?.layoutSubtreeIfNeeded()
                guard let contentView = panel.contentView,
                      self.containsWindowDragSurface(in: contentView) else {
                    fatalError("无顶栏看板缺少可用的窗口拖动区域")
                }
                editorController.present(
                    context: .create,
                    activate: false,
                    visuallyHidden: true
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    guard editorController.isEditorVisible,
                          editorController.presentedContext != nil else {
                        fatalError("独立待办编辑窗口未成功创建")
                    }
                    guard NSEqualRects(panel.frame, condensedFrameBeforeEditor),
                          coordinator.presentationMode == .condensed else {
                        fatalError("打开独立编辑窗口改变了小尺寸主看板")
                    }
                    editorController.dismiss()
                    panel.orderOut(nil)
                    panel.alphaValue = 1
                    panel.ignoresMouseEvents = false
                    panel.setFrame(
                        NSRect(origin: panel.frame.origin, size: JottedLayout.defaultWindowSize),
                        display: true
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        guard coordinator.presentationMode == .full else {
                            fatalError("完整界面未在放大后恢复")
                        }
                        let localizationSamples: [L10n.Key] = [
                            .appName,
                            .remainingDueToday,
                            .remainingLessThanMinute,
                            .remainingMinutes(2),
                            .remainingHours(2),
                            .remainingDays(2)
                        ]
                        guard AppLanguage.allCases.count == 9,
                              AppearanceTheme.allCases.count == 5,
                              AppLanguage.allCases.allSatisfy({
                                  let language = $0.resolved
                                  return localizationSamples.allSatisfy {
                                      !L10n.text($0, language: language).isEmpty
                                  }
                              }) else {
                            fatalError("多语言或主题配置不完整")
                        }
                        self.terminateAfterSnapshot(error: nil)
                    }
                }
            }
        } else {
            coordinator.show(activate: false)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windowCoordinator?.show(activate: true)
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        launchAtLoginManager?.refresh()
    }

    private func makePanel(
        store: TodoStore,
        coordinator: WindowCoordinator,
        editorController: TaskEditorWindowController,
        snapshotMode: Bool
    ) -> BoardPanel {
        let defaultSize = JottedLayout.defaultWindowSize
        let panel = BoardPanel(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            styleMask: [.borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.title = localization.text(.appName)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // NSWindow's shadow follows the rectangular window frame, even when
        // SwiftUI clips the visible card to rounded corners. The card draws its
        // own rounded shadow inside a transparent window inset instead.
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = coordinator.isPinned ? .floating : .normal
        panel.minSize = JottedLayout.minimumExpandedWindowSize
        panel.maxSize = JottedLayout.maximumWindowSize

        var restored = false
        if !snapshotMode {
            let frameName = "JottedBoardFrameV2"
            restored = panel.setFrameUsingName(frameName)
            if !restored {
                restored = panel.setFrameUsingName("JottedBoardFrame")
            }
            panel.setFrameAutosaveName(frameName)

            let layoutVersionKey = "JottedWindowLayoutVersion"
            let oldLayoutVersion = UserDefaults.standard.integer(forKey: layoutVersionKey)
            if restored, oldLayoutVersion < 2 {
                if panel.frame.width < defaultSize.width {
                    var migratedFrame = panel.frame
                    migratedFrame.size.width = min(
                        migratedFrame.width + JottedLayout.windowInset * 2,
                        JottedLayout.maximumWindowSize.width
                    )
                    migratedFrame.origin.x -= JottedLayout.windowInset
                    panel.setFrame(migratedFrame, display: false)
                }
            }
            if restored,
               oldLayoutVersion < 3,
               UserDefaults.standard.bool(forKey: "JottedIsCompact") {
                var migratedFrame = panel.frame
                let topEdge = migratedFrame.maxY
                migratedFrame.size = defaultSize
                migratedFrame.origin.y = topEdge - migratedFrame.height
                panel.setFrame(migratedFrame, display: false)
            }
            UserDefaults.standard.removeObject(forKey: "JottedIsCompact")
            UserDefaults.standard.set(3, forKey: layoutVersionKey)
        }

        let rootView = BoardView(
            store: store,
            windowCoordinator: coordinator,
            snapshotMode: snapshotMode,
            onPresentEditor: { [weak self, weak editorController] context in
                self?.dismissSettings()
                editorController?.present(context: context)
            }
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        let resizeOverlay = WindowResizeOverlayView(frame: .zero)
        let container = PanelContentContainerView(
            hostingView: hostingView,
            resizeOverlay: resizeOverlay
        )
        panel.contentView = container

        if !restored || !isFrameVisible(panel.frame) {
            positionNearTopRight(panel)
        }

        return panel
    }

    private func makePreviewStore(language: AppLanguage, condensed: Bool = false) -> TodoStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JottedPreview-\(UUID().uuidString)", isDirectory: true)
        previewDirectory = directory
        let store = TodoStore(
            repository: TodoRepository(fileURL: directory.appendingPathComponent("board.json")),
            loadImmediately: false
        )
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let todayLater = calendar.date(byAdding: .hour, value: 2, to: now) ?? now
        let tomorrowBase = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrow = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: tomorrowBase) ?? tomorrowBase
        let nextWeek = calendar.date(byAdding: .day, value: 8, to: now) ?? now
        let copy = PreviewTaskCopy.localized(for: language)

        _ = store.add(title: copy.overdue, deadline: now.addingTimeInterval(-86_400), priority: .high)
        _ = store.add(title: copy.today, deadline: todayLater, priority: .high)
        if condensed {
            return store
        }
        _ = store.add(
            title: copy.allDay,
            deadline: tomorrow,
            priority: .medium,
            isAllDay: true
        )
        _ = store.add(title: copy.future, deadline: nextWeek, priority: .low)
        _ = store.add(title: copy.undated, deadline: nil, priority: .medium)
        if let completed = store.add(title: copy.completed, deadline: nil, priority: .medium) {
            store.toggleCompletion(completed)
        }
        return store
    }

    private func renderSnapshot(window: NSWindow, request: SnapshotRequest) {
        guard let view = window.contentView else {
            terminateAfterSnapshot(error: "无法获取预览视图")
            return
        }

        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            terminateAfterSnapshot(error: "无法创建预览画布")
            return
        }
        view.cacheDisplay(in: view.bounds, to: representation)

        guard let data = representation.representation(using: .png, properties: [:]) else {
            terminateAfterSnapshot(error: "无法编码预览图片")
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: request.outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: request.outputURL, options: .atomic)
            print(request.outputURL.path)
            terminateAfterSnapshot(error: nil)
        } catch {
            terminateAfterSnapshot(error: error.localizedDescription)
        }
    }

    private func terminateAfterSnapshot(error: String?) {
        if let error {
            FileHandle.standardError.write(Data("记着预览失败：\(error)\n".utf8))
        }
        if let previewDirectory {
            try? FileManager.default.removeItem(at: previewDirectory)
        }
        NSApp.terminate(nil)
    }

    private func positionNearTopRight(_ panel: NSWindow) {
        guard let screen = NSScreen.main else {
            panel.center()
            return
        }
        let visible = screen.visibleFrame
        let visibleCardMargin: CGFloat = 28
        let windowMargin = max(0, visibleCardMargin - JottedLayout.windowInset)
        let origin = NSPoint(
            x: visible.maxX - panel.frame.width - windowMargin,
            y: visible.maxY - panel.frame.height - windowMargin
        )
        panel.setFrameOrigin(origin)
    }

    private func isFrameVisible(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            screen.visibleFrame.intersection(frame).width >= 80
                && screen.visibleFrame.intersection(frame).height >= 50
        }
    }

    private func containsWindowDragSurface(in view: NSView) -> Bool {
        if view is DraggableNSView {
            return true
        }
        return view.subviews.contains { containsWindowDragSurface(in: $0) }
    }

    private func makeStatusItem() {
        let item: NSStatusItem
        if let statusItem {
            item = statusItem
        } else {
            item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        }
        let appName = localization.text(.appName)
        item.button?.image = NSImage(
            systemSymbolName: "checklist",
            accessibilityDescription: appName
        )
        item.button?.toolTip = appName

        let menu = NSMenu()
        let showItem = NSMenuItem(
            title: localization.text(.showOrHideApp),
            action: #selector(togglePanel),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        let newItem = NSMenuItem(
            title: localization.text(.newTodo),
            action: #selector(createTask),
            keyEquivalent: "n"
        )
        newItem.keyEquivalentModifierMask = [.command]
        newItem.target = self
        menu.addItem(newItem)

        let pinItem = NSMenuItem(
            title: localization.text(
                windowCoordinator?.isPinned == true ? .stopKeepingOnTop : .keepOnTop
            ),
            action: #selector(togglePinned),
            keyEquivalent: ""
        )
        pinItem.target = self
        pinItem.state = windowCoordinator?.isPinned == true ? .on : .off
        menu.addItem(pinItem)
        pinMenuItem = pinItem

        let settingsItem = NSMenuItem(
            title: localization.text(.settings),
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: localization.text(.quitApp),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func makeApplicationMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: localization.text(.appName))

        let newItem = NSMenuItem(
            title: localization.text(.newTodo),
            action: #selector(createTask),
            keyEquivalent: "n"
        )
        newItem.keyEquivalentModifierMask = [.command]
        newItem.target = self
        appMenu.addItem(newItem)

        let settingsItem = NSMenuItem(
            title: localization.text(.settings),
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: localization.text(.quitApp),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true {
            dismissSettings()
            taskEditorWindowController?.dismiss()
        }
        windowCoordinator?.toggleVisibility()
    }

    @objc private func createTask() {
        dismissSettings()
        windowCoordinator?.show(activate: true)
        taskEditorWindowController?.present(context: .create)
    }

    @objc private func togglePinned() {
        windowCoordinator?.togglePinned()
    }

    @objc private func showSettingsFromNotification(_ notification: Notification) {
        showSettings()
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        panel?.title = localization.text(.appName)
        settingsWindow?.title = localizedSettingsWindowTitle
        taskEditorWindowController?.refreshLocalization()
        makeStatusItem()
        makeApplicationMenu()
    }

    @objc private func showSettings() {
        taskEditorWindowController?.dismiss()
        windowCoordinator?.show(activate: false)

        let window: SettingsPanel
        if let settingsWindow {
            window = settingsWindow
        } else {
            let manager = launchAtLoginManager ?? LaunchAtLoginManager()
            launchAtLoginManager = manager
            let newWindow = makeSettingsWindow(manager: manager)
            settingsWindow = newWindow
            window = newWindow
        }

        positionSettingsWindow(window)
        if let panel {
            if window.parent !== panel {
                window.parent?.removeChildWindow(window)
                panel.addChildWindow(window, ordered: .above)
            }
            window.level = panel.level
            window.collectionBehavior = panel.collectionBehavior
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func dismissSettings() {
        guard let settingsWindow else { return }
        settingsWindow.parent?.removeChildWindow(settingsWindow)
        settingsWindow.orderOut(nil)
    }

    private func makeSettingsWindow(manager: LaunchAtLoginManager) -> SettingsPanel {
        let window = SettingsPanel(
            contentRect: NSRect(origin: .zero, size: JottedLayout.settingsWindowSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let controller = NSHostingController(
            rootView: JottedSettingsWindowRoot(
                launchAtLoginManager: manager,
                onClose: { [weak self] in
                    self?.dismissSettings()
                }
            )
        )
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentViewController = controller
        window.title = localizedSettingsWindowTitle
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        // Off on purpose: background dragging competes with the transparency
        // slider for the mouse and used to win. The header carries an explicit
        // drag surface instead.
        window.isMovableByWindowBackground = false
        window.animationBehavior = .utilityWindow
        window.onCancel = { [weak self] in
            self?.dismissSettings()
        }
        return window
    }

    private func positionSettingsWindow(_ settingsWindow: NSWindow) {
        guard let panel else {
            settingsWindow.center()
            return
        }

        let parentFrame = panel.frame
        let screenFrame = (panel.screen ?? NSScreen.main)?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? parentFrame.insetBy(dx: -500, dy: -500)
        let size = settingsWindow.frame.size
        let shadowInset: CGFloat = 28
        let boardCardInset = JottedLayout.windowInset
        let visualGap: CGFloat = 10

        let leftOriginX = parentFrame.minX + boardCardInset - visualGap
            - (size.width - shadowInset)
        let rightOriginX = parentFrame.maxX - boardCardInset + visualGap
            - shadowInset
        let preferredX = leftOriginX >= screenFrame.minX
            ? leftOriginX
            : rightOriginX
        let preferredY = parentFrame.maxY - boardCardInset
            + shadowInset - size.height

        let safeFrame = screenFrame.insetBy(dx: 6, dy: 6)
        let maximumX = max(safeFrame.minX, safeFrame.maxX - size.width)
        let maximumY = max(safeFrame.minY, safeFrame.maxY - size.height)
        let x = min(max(preferredX, safeFrame.minX), maximumX)
        let y = min(max(preferredY, safeFrame.minY), maximumY)
        settingsWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func makeThemeGalleryWindow() -> NSWindow {
        let size = JottedLayout.themeGallerySize
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView = NSHostingView(rootView: ThemeGalleryView())
        return window
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private var localizedSettingsWindowTitle: String {
        let settings = localization.text(.settings)
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: "...", with: "")
        return "\(localization.text(.appName)) · \(settings)"
    }
}

private struct PreviewTaskCopy {
    let overdue: String
    let today: String
    let allDay: String
    let future: String
    let undated: String
    let completed: String

    static func localized(for language: AppLanguage) -> PreviewTaskCopy {
        switch language.resolved {
        case .simplifiedChinese:
            PreviewTaskCopy(
                overdue: "提交论文最终版本",
                today: "回复导师的修改意见",
                allDay: "预约下周的讨论会",
                future: "整理实验笔记",
                undated: "整理回国物品",
                completed: "更新项目进度"
            )
        case .traditionalChinese:
            PreviewTaskCopy(
                overdue: "提交論文最終版本",
                today: "回覆導師的修改意見",
                allDay: "預約下週討論會",
                future: "整理實驗筆記",
                undated: "整理返程物品",
                completed: "更新專案進度"
            )
        case .english:
            PreviewTaskCopy(
                overdue: "Submit final paper",
                today: "Reply to advisor feedback",
                allDay: "Schedule next week’s review",
                future: "Organize experiment notes",
                undated: "Pack for the trip home",
                completed: "Update project status"
            )
        case .japanese:
            PreviewTaskCopy(
                overdue: "論文の最終版を提出",
                today: "指導教員の修正に返信",
                allDay: "来週の打ち合わせを予約",
                future: "実験ノートを整理",
                undated: "帰国の荷物を整理",
                completed: "進捗を更新"
            )
        case .korean:
            PreviewTaskCopy(
                overdue: "논문 최종본 제출",
                today: "지도교수 피드백 답변",
                allDay: "다음 주 회의 일정 잡기",
                future: "실험 노트 정리",
                undated: "귀국 짐 정리",
                completed: "프로젝트 진행 상황 업데이트"
            )
        case .french:
            PreviewTaskCopy(
                overdue: "Envoyer la version finale",
                today: "Répondre aux retours",
                allDay: "Planifier la réunion",
                future: "Classer les notes d’expérience",
                undated: "Préparer les affaires du retour",
                completed: "Mettre à jour le projet"
            )
        case .spanish:
            PreviewTaskCopy(
                overdue: "Enviar la versión final",
                today: "Responder a los comentarios",
                allDay: "Programar la reunión",
                future: "Ordenar las notas del experimento",
                undated: "Preparar el equipaje de vuelta",
                completed: "Actualizar el proyecto"
            )
        case .german:
            PreviewTaskCopy(
                overdue: "Finalfassung einreichen",
                today: "Rückmeldung beantworten",
                allDay: "Besprechung planen",
                future: "Versuchsnotizen ordnen",
                undated: "Rückreise packen",
                completed: "Projektstatus aktualisieren"
            )
        case .system:
            // `resolved` normally eliminates this case. Keep a stable fallback
            // so preview data remains useful if system resolution ever changes.
            PreviewTaskCopy(
                overdue: "Submit final paper",
                today: "Reply to advisor feedback",
                allDay: "Schedule next week’s review",
                future: "Organize experiment notes",
                undated: "Pack for the trip home",
                completed: "Update project status"
            )
        }
    }
}

private struct SnapshotRequest {
    enum Target {
        case board(NSSize)
        case settings
        case themeGallery
    }

    let outputURL: URL
    let isDark: Bool
    let target: Target
    let usesCondensedPreview: Bool

    static func from(arguments: [String]) -> SnapshotRequest? {
        let requests: [(String, Bool, Target, Bool)] = [
            ("--snapshot-light", false, .board(JottedLayout.defaultWindowSize), false),
            ("--snapshot-dark", true, .board(JottedLayout.defaultWindowSize), false),
            ("--snapshot-condensed-light", false, .board(JottedLayout.minimumExpandedWindowSize), true),
            ("--snapshot-condensed-dark", true, .board(JottedLayout.minimumExpandedWindowSize), true),
            ("--snapshot-settings-light", false, .settings, false),
            ("--snapshot-settings-dark", true, .settings, false),
            ("--snapshot-theme-gallery", false, .themeGallery, false)
        ]
        for (flag, dark, target, usesCondensedPreview) in requests {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
                continue
            }
            let path = NSString(string: arguments[index + 1]).expandingTildeInPath
            return SnapshotRequest(
                outputURL: URL(fileURLWithPath: path),
                isDark: dark,
                target: target,
                usesCondensedPreview: usesCondensedPreview
            )
        }
        return nil
    }
}

final class BoardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class SettingsPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

extension Notification.Name {
    static let jottedShowSettings = Notification.Name("JottedShowSettings")
    static let jottedCreateTask = Notification.Name("JottedCreateTask")
    static let jottedTogglePin = Notification.Name("JottedTogglePin")
    static let jottedHideBoard = Notification.Name("JottedHideBoard")
}
