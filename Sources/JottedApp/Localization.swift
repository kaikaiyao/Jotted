import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    static let storageKey = "JottedAppLanguage"

    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case spanish = "es"
    case german = "de"

    var id: String { rawValue }

    var nativeDisplayName: String {
        switch self {
        case .system: "System"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .french: "Français"
        case .spanish: "Español"
        case .german: "Deutsch"
        }
    }

    var locale: Locale {
        Locale(identifier: resolved.rawValue)
    }

    var resolved: AppLanguage {
        guard self == .system else { return self }
        return Self.resolve(preferredLanguages: Locale.preferredLanguages)
    }

    static func resolve(preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()

            if normalized.hasPrefix("zh") {
                let traditionalMarkers = ["hant", "-tw", "-hk", "-mo"]
                return traditionalMarkers.contains(where: normalized.contains)
                    ? .traditionalChinese
                    : .simplifiedChinese
            }
            if normalized.hasPrefix("en") { return .english }
            if normalized.hasPrefix("ja") { return .japanese }
            if normalized.hasPrefix("ko") { return .korean }
            if normalized.hasPrefix("fr") { return .french }
            if normalized.hasPrefix("es") { return .spanish }
            if normalized.hasPrefix("de") { return .german }
        }
        return .english
    }
}

@MainActor
final class AppLocalization: NSObject, ObservableObject {
    static let shared = AppLocalization()
    static let didChangeNotification = Notification.Name("JottedLanguageDidChange")

    @Published private(set) var selectedLanguage: AppLanguage
    @Published private(set) var resolvedLanguage: AppLanguage

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: AppLanguage.storageKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
        selectedLanguage = stored
        resolvedLanguage = stored.resolved
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemLocaleDidChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var locale: Locale {
        selectedLanguage == .system ? .autoupdatingCurrent : resolvedLanguage.locale
    }

    func setLanguage(_ language: AppLanguage) {
        guard selectedLanguage != language else {
            refreshResolvedLanguage()
            return
        }
        selectedLanguage = language
        defaults.set(language.rawValue, forKey: AppLanguage.storageKey)
        refreshResolvedLanguage(forceNotification: true)
    }

    func text(_ key: L10n.Key) -> String {
        L10n.text(key, language: resolvedLanguage)
    }

    func languageOptionName(_ language: AppLanguage) -> String {
        language == .system ? text(.followSystem) : language.nativeDisplayName
    }

    @objc private func systemLocaleDidChange() {
        guard selectedLanguage == .system else { return }
        refreshResolvedLanguage(forceNotification: true)
    }

    private func refreshResolvedLanguage(forceNotification: Bool = false) {
        let next = selectedLanguage.resolved
        let changed = next != resolvedLanguage
        if changed {
            resolvedLanguage = next
        } else if forceNotification {
            objectWillChange.send()
        }
        if changed || forceNotification {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }
}

enum L10n {
    enum Key: Sendable {
        case appName

        case sectionOverdue
        case sectionToday
        case sectionUpcoming
        case sectionUndated
        case sectionCompleted
        case blankBoardHint
        case clear
        case undo
        case restoredTask(String)
        case completedTask(String)
        case deletedTask(String)

        case addItem
        case showOrHideApp
        case newTodo
        case keepOnTop
        case stopKeepingOnTop
        case settings
        case hideApp
        case quitApp

        case edit
        case delete
        case markComplete
        case markIncomplete
        case moreActions
        case completedState
        case incompleteState
        case noDeadline
        case priorityLow
        case priorityMedium
        case priorityHigh
        case priorityMediumShort
        case priorityHighShort
        case mediumPriorityAccessibility
        case highPriorityAccessibility

        case createEditorTitle
        case editEditorTitle
        case createEditorSubtitle
        case editEditorSubtitle
        case cancel
        case taskTitlePlaceholder
        case quickSettings
        case today
        case tomorrow
        case chooseDate
        case deadlineDate(String)
        case openCalendar
        case completionTime
        case allDayExplanation
        case priority
        case add
        case save
        case allDay
        case time
        case specificTime
        case deadlineMode
        case hour
        case minute
        case chooseValue(String)
        case hourValue(Int)
        case minuteValue(Int)

        case calendarChooseAllDay
        case calendarChooseKeepingTime
        case previousMonth
        case nextMonth
        case todayRingExplanation
        case returnToToday
        case chooseTodayAndClose
        case selected
        case chooseThisDate
        case chooseAdjacentMonthDate

        case overdueAt(String)
        case overdueAtAccessibility(String)
        case overdueDays(Int)
        case dueTodayAt(String)
        case dueTodayAtAccessibility(String)
        case dueTomorrowAt(String)
        case dueTomorrowAtAccessibility(String)
        case dueWeekdayAt(String, String)
        case dueWeekdayAtAccessibility(String, String)
        case dueDate(String)
        case dueDateAccessibility(String)
        case allDayOverdueAccessibility(Int)
        case allDayToday
        case allDayTodayAccessibility
        case allDayTomorrow
        case allDayTomorrowAccessibility
        case allDayWeekday(String)
        case allDayWeekdayAccessibility(String)
        case allDayDate(String)
        case allDayDateAccessibility(String)
        case remainingDueToday
        case remainingLessThanMinute
        case remainingMinutes(Int)
        case remainingHours(Int)
        case remainingDays(Int)

        case panelTransparency
        case glassTransparencyAccessibility
        case reduceTransparencyNotice
        case language
        case followSystem
        case launchAtLogin
        case launchAtLoginEnabled
        case launchAtLoginDisabled
        case launchAtLoginRequiresApproval
        case launchAtLoginFailed
        case openSystemSettings
        case theme
        case themeGraphite
        case themeAurora
        case themeBlossom
        case themeAmber
        case themeAbyss
        case lightMode
        case darkMode
    }

    static func text(_ key: Key, language: AppLanguage = AppLanguage.system.resolved) -> String {
        switch language.resolved {
        case .simplifiedChinese: simplifiedChinese(key)
        case .traditionalChinese: traditionalChinese(key)
        case .english, .system: english(key)
        case .japanese: japanese(key)
        case .korean: korean(key)
        case .french: french(key)
        case .spanish: spanish(key)
        case .german: german(key)
        }
    }

    private static func simplifiedChinese(_ key: Key) -> String {
        switch key {
        case .appName: "记着"
        case .sectionOverdue: "已逾期"
        case .sectionToday: "今天"
        case .sectionUpcoming: "接下来"
        case .sectionUndated: "无日期"
        case .sectionCompleted: "已完成"
        case .blankBoardHint: "右键空白处添加事项"
        case .clear: "清除"
        case .undo: "撤销"
        case let .restoredTask(title): "已恢复“\(title)”"
        case let .completedTask(title): "已完成“\(title)”"
        case let .deletedTask(title): "已删除“\(title)”"
        case .addItem: "添加事项"
        case .showOrHideApp: "显示或隐藏记着"
        case .newTodo: "新建待办"
        case .keepOnTop: "保持在最前"
        case .stopKeepingOnTop: "取消保持在最前"
        case .settings: "设置…"
        case .hideApp: "隐藏记着"
        case .quitApp: "退出记着"
        case .edit: "编辑"
        case .delete: "删除"
        case .markComplete: "标记为完成"
        case .markIncomplete: "标记为未完成"
        case .moreActions: "更多操作"
        case .completedState: "已完成"
        case .incompleteState: "未完成"
        case .noDeadline: "无截止日期"
        case .priorityLow: "低"
        case .priorityMedium: "中"
        case .priorityHigh: "高"
        case .priorityMediumShort: "中"
        case .priorityHighShort: "高"
        case .mediumPriorityAccessibility: "中优先级"
        case .highPriorityAccessibility: "高优先级"
        case .createEditorTitle: "记下一件事"
        case .editEditorTitle: "编辑待办"
        case .createEditorSubtitle: "稍后也可以随时调整"
        case .editEditorSubtitle: "确认后保存"
        case .cancel: "取消"
        case .taskTitlePlaceholder: "要完成什么？"
        case .quickSettings: "快速设置"
        case .today: "今天"
        case .tomorrow: "明天"
        case .chooseDate: "选日期"
        case let .deadlineDate(date): "截止日期，\(date)"
        case .openCalendar: "打开月历"
        case .completionTime: "完成时间"
        case .allDayExplanation: "当天结束前完成，不设具体时间"
        case .priority: "优先级"
        case .add: "添加"
        case .save: "保存"
        case .allDay: "全天"
        case .time: "时间"
        case .specificTime: "具体时间"
        case .deadlineMode: "截止时间模式"
        case .hour: "小时"
        case .minute: "分钟"
        case let .chooseValue(value): "选择\(value)"
        case let .hourValue(value): "\(value)时"
        case let .minuteValue(value): "\(value)分"
        case .calendarChooseAllDay: "选择完成日期 · 全天"
        case .calendarChooseKeepingTime: "选择完成日期 · 保留时间"
        case .previousMonth: "上个月"
        case .nextMonth: "下个月"
        case .todayRingExplanation: "圆环表示今天"
        case .returnToToday: "回到今天"
        case .chooseTodayAndClose: "选择今天并关闭月历"
        case .selected: "已选择"
        case .chooseThisDate: "选择此日期"
        case .chooseAdjacentMonthDate: "选择相邻月份的此日期"
        case let .overdueAt(time): "已逾期 · \(time)"
        case let .overdueAtAccessibility(time): "已逾期，截止时间 \(time)"
        case let .overdueDays(days): "已逾期 \(days) 天"
        case let .dueTodayAt(time): "今天 \(time)"
        case let .dueTodayAtAccessibility(time): "截止今天 \(time)"
        case let .dueTomorrowAt(time): "明天 \(time)"
        case let .dueTomorrowAtAccessibility(time): "截止明天 \(time)"
        case let .dueWeekdayAt(day, time): "\(day) \(time)"
        case let .dueWeekdayAtAccessibility(day, time): "截止\(day) \(time)"
        case let .dueDate(date): date
        case let .dueDateAccessibility(date): "截止 \(date)"
        case let .allDayOverdueAccessibility(days): "全天事项已逾期 \(days) 天"
        case .allDayToday: "今天 · 全天"
        case .allDayTodayAccessibility: "全天事项，截止今天"
        case .allDayTomorrow: "明天 · 全天"
        case .allDayTomorrowAccessibility: "全天事项，截止明天"
        case let .allDayWeekday(day): "\(day) · 全天"
        case let .allDayWeekdayAccessibility(day): "全天事项，截止\(day)"
        case let .allDayDate(date): "\(date) · 全天"
        case let .allDayDateAccessibility(date): "全天事项，截止 \(date)"
        case .remainingDueToday: "今天截止"
        case .remainingLessThanMinute: "不到 1 分钟"
        case let .remainingMinutes(value): "还有 \(value) 分钟"
        case let .remainingHours(value): "还有 \(value) 小时"
        case let .remainingDays(value): "还有 \(value) 天"
        case .panelTransparency: "面板通透度"
        case .glassTransparencyAccessibility: "玻璃透明度"
        case .reduceTransparencyNotice: "系统已开启“降低透明度”，记着会使用实色背景。"
        case .language: "语言"
        case .followSystem: "跟随系统"
        case .launchAtLogin: "登录时打开"
        case .launchAtLoginEnabled: "已开启登录时自动打开"
        case .launchAtLoginDisabled: "已关闭登录时自动打开"
        case .launchAtLoginRequiresApproval: "需要在系统设置中允许登录项"
        case .launchAtLoginFailed: "无法更改登录项设置"
        case .openSystemSettings: "打开系统设置"
        case .theme: "颜色主题"
        case .themeGraphite: "石墨"
        case .themeAurora: "极光"
        case .themeBlossom: "霞粉"
        case .themeAmber: "琥珀"
        case .themeAbyss: "深海"
        case .lightMode: "浅色"
        case .darkMode: "深色"
        }
    }

    private static func traditionalChinese(_ key: Key) -> String {
        switch key {
        case .appName: "記著"
        case .sectionOverdue: "已逾期"
        case .sectionToday: "今天"
        case .sectionUpcoming: "接下來"
        case .sectionUndated: "無日期"
        case .sectionCompleted: "已完成"
        case .blankBoardHint: "在空白處按右鍵以新增事項"
        case .clear: "清除"
        case .undo: "復原"
        case let .restoredTask(title): "已恢復「\(title)」"
        case let .completedTask(title): "已完成「\(title)」"
        case let .deletedTask(title): "已刪除「\(title)」"
        case .addItem: "新增事項"
        case .showOrHideApp: "顯示或隱藏記著"
        case .newTodo: "新增待辦"
        case .keepOnTop: "保持在最上層"
        case .stopKeepingOnTop: "取消保持在最上層"
        case .settings: "設定…"
        case .hideApp: "隱藏記著"
        case .quitApp: "結束記著"
        case .edit: "編輯"
        case .delete: "刪除"
        case .markComplete: "標示為已完成"
        case .markIncomplete: "標示為未完成"
        case .moreActions: "更多操作"
        case .completedState: "已完成"
        case .incompleteState: "未完成"
        case .noDeadline: "無截止日期"
        case .priorityLow: "低"
        case .priorityMedium: "中"
        case .priorityHigh: "高"
        case .priorityMediumShort: "中"
        case .priorityHighShort: "高"
        case .mediumPriorityAccessibility: "中優先級"
        case .highPriorityAccessibility: "高優先級"
        case .createEditorTitle: "記下一件事"
        case .editEditorTitle: "編輯待辦"
        case .createEditorSubtitle: "稍後也可以隨時調整"
        case .editEditorSubtitle: "確認後儲存"
        case .cancel: "取消"
        case .taskTitlePlaceholder: "要完成什麼？"
        case .quickSettings: "快速設定"
        case .today: "今天"
        case .tomorrow: "明天"
        case .chooseDate: "選擇日期"
        case let .deadlineDate(date): "截止日期，\(date)"
        case .openCalendar: "開啟月曆"
        case .completionTime: "完成時間"
        case .allDayExplanation: "在當天結束前完成，不設定具體時間"
        case .priority: "優先級"
        case .add: "新增"
        case .save: "儲存"
        case .allDay: "全天"
        case .time: "時間"
        case .specificTime: "具體時間"
        case .deadlineMode: "截止時間模式"
        case .hour: "小時"
        case .minute: "分鐘"
        case let .chooseValue(value): "選擇\(value)"
        case let .hourValue(value): "\(value)時"
        case let .minuteValue(value): "\(value)分"
        case .calendarChooseAllDay: "選擇完成日期 · 全天"
        case .calendarChooseKeepingTime: "選擇完成日期 · 保留時間"
        case .previousMonth: "上個月"
        case .nextMonth: "下個月"
        case .todayRingExplanation: "圓環表示今天"
        case .returnToToday: "回到今天"
        case .chooseTodayAndClose: "選擇今天並關閉月曆"
        case .selected: "已選擇"
        case .chooseThisDate: "選擇此日期"
        case .chooseAdjacentMonthDate: "選擇相鄰月份的此日期"
        case let .overdueAt(time): "已逾期 · \(time)"
        case let .overdueAtAccessibility(time): "已逾期，截止時間 \(time)"
        case let .overdueDays(days): "已逾期 \(days) 天"
        case let .dueTodayAt(time): "今天 \(time)"
        case let .dueTodayAtAccessibility(time): "截止今天 \(time)"
        case let .dueTomorrowAt(time): "明天 \(time)"
        case let .dueTomorrowAtAccessibility(time): "截止明天 \(time)"
        case let .dueWeekdayAt(day, time): "\(day) \(time)"
        case let .dueWeekdayAtAccessibility(day, time): "截止\(day) \(time)"
        case let .dueDate(date): date
        case let .dueDateAccessibility(date): "截止 \(date)"
        case let .allDayOverdueAccessibility(days): "全天事項已逾期 \(days) 天"
        case .allDayToday: "今天 · 全天"
        case .allDayTodayAccessibility: "全天事項，截止今天"
        case .allDayTomorrow: "明天 · 全天"
        case .allDayTomorrowAccessibility: "全天事項，截止明天"
        case let .allDayWeekday(day): "\(day) · 全天"
        case let .allDayWeekdayAccessibility(day): "全天事項，截止\(day)"
        case let .allDayDate(date): "\(date) · 全天"
        case let .allDayDateAccessibility(date): "全天事項，截止 \(date)"
        case .remainingDueToday: "今天截止"
        case .remainingLessThanMinute: "不到 1 分鐘"
        case let .remainingMinutes(value): "還有 \(value) 分鐘"
        case let .remainingHours(value): "還有 \(value) 小時"
        case let .remainingDays(value): "還有 \(value) 天"
        case .panelTransparency: "面板通透度"
        case .glassTransparencyAccessibility: "玻璃透明度"
        case .reduceTransparencyNotice: "系統已開啟「降低透明度」，記著會使用實色背景。"
        case .language: "語言"
        case .followSystem: "跟隨系統"
        case .launchAtLogin: "登入時開啟"
        case .launchAtLoginEnabled: "已開啟登入時自動啟動"
        case .launchAtLoginDisabled: "已關閉登入時自動啟動"
        case .launchAtLoginRequiresApproval: "需要在系統設定中允許登入項目"
        case .launchAtLoginFailed: "無法更改登入項目設定"
        case .openSystemSettings: "打開系統設定"
        case .theme: "顏色主題"
        case .themeGraphite: "石墨"
        case .themeAurora: "極光"
        case .themeBlossom: "霞粉"
        case .themeAmber: "琥珀"
        case .themeAbyss: "深海"
        case .lightMode: "淺色"
        case .darkMode: "深色"
        }
    }

    private static func english(_ key: Key) -> String {
        switch key {
        case .appName: "Jotted"
        case .sectionOverdue: "Overdue"
        case .sectionToday: "Today"
        case .sectionUpcoming: "Up next"
        case .sectionUndated: "No date"
        case .sectionCompleted: "Completed"
        case .blankBoardHint: "Right-click an empty area to add a task"
        case .clear: "Clear"
        case .undo: "Undo"
        case let .restoredTask(title): "Restored “\(title)”"
        case let .completedTask(title): "Completed “\(title)”"
        case let .deletedTask(title): "Deleted “\(title)”"
        case .addItem: "Add task"
        case .showOrHideApp: "Show or hide Jotted"
        case .newTodo: "New task"
        case .keepOnTop: "Keep on top"
        case .stopKeepingOnTop: "Stop keeping on top"
        case .settings: "Settings…"
        case .hideApp: "Hide Jotted"
        case .quitApp: "Quit Jotted"
        case .edit: "Edit"
        case .delete: "Delete"
        case .markComplete: "Mark as complete"
        case .markIncomplete: "Mark as incomplete"
        case .moreActions: "More actions"
        case .completedState: "Completed"
        case .incompleteState: "Incomplete"
        case .noDeadline: "No deadline"
        case .priorityLow: "Low"
        case .priorityMedium: "Medium"
        case .priorityHigh: "High"
        case .priorityMediumShort: "M"
        case .priorityHighShort: "H"
        case .mediumPriorityAccessibility: "Medium priority"
        case .highPriorityAccessibility: "High priority"
        case .createEditorTitle: "Add a task"
        case .editEditorTitle: "Edit task"
        case .createEditorSubtitle: "You can fine-tune it later"
        case .editEditorSubtitle: "Save when everything looks right"
        case .cancel: "Cancel"
        case .taskTitlePlaceholder: "What needs to be done?"
        case .quickSettings: "Quick options"
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .chooseDate: "Choose date"
        case let .deadlineDate(date): "Deadline, \(date)"
        case .openCalendar: "Open calendar"
        case .completionTime: "Due time"
        case .allDayExplanation: "Due by the end of the day, with no specific time"
        case .priority: "Priority"
        case .add: "Add"
        case .save: "Save"
        case .allDay: "All day"
        case .time: "Time"
        case .specificTime: "Specific time"
        case .deadlineMode: "Deadline mode"
        case .hour: "hour"
        case .minute: "minute"
        case let .chooseValue(value): "Choose \(value)"
        case let .hourValue(value): "\(value) hour\(value == 1 ? "" : "s")"
        case let .minuteValue(value): "\(value) minute\(value == 1 ? "" : "s")"
        case .calendarChooseAllDay: "Choose a due date · All day"
        case .calendarChooseKeepingTime: "Choose a due date · Keep time"
        case .previousMonth: "Previous month"
        case .nextMonth: "Next month"
        case .todayRingExplanation: "The ring marks today"
        case .returnToToday: "Today"
        case .chooseTodayAndClose: "Select today and close the calendar"
        case .selected: "Selected"
        case .chooseThisDate: "Select this date"
        case .chooseAdjacentMonthDate: "Select this date from the adjacent month"
        case let .overdueAt(time): "Overdue · \(time)"
        case let .overdueAtAccessibility(time): "Overdue, was due at \(time)"
        case let .overdueDays(days): "\(days) day\(days == 1 ? "" : "s") overdue"
        case let .dueTodayAt(time): "Today \(time)"
        case let .dueTodayAtAccessibility(time): "Due today at \(time)"
        case let .dueTomorrowAt(time): "Tomorrow \(time)"
        case let .dueTomorrowAtAccessibility(time): "Due tomorrow at \(time)"
        case let .dueWeekdayAt(day, time): "\(day) \(time)"
        case let .dueWeekdayAtAccessibility(day, time): "Due \(day) at \(time)"
        case let .dueDate(date): date
        case let .dueDateAccessibility(date): "Due \(date)"
        case let .allDayOverdueAccessibility(days): "All-day task, \(days) day\(days == 1 ? "" : "s") overdue"
        case .allDayToday: "Today · All day"
        case .allDayTodayAccessibility: "All-day task due today"
        case .allDayTomorrow: "Tomorrow · All day"
        case .allDayTomorrowAccessibility: "All-day task due tomorrow"
        case let .allDayWeekday(day): "\(day) · All day"
        case let .allDayWeekdayAccessibility(day): "All-day task due \(day)"
        case let .allDayDate(date): "\(date) · All day"
        case let .allDayDateAccessibility(date): "All-day task due \(date)"
        case .remainingDueToday: "Due today"
        case .remainingLessThanMinute: "Less than 1 min"
        case let .remainingMinutes(value): "\(value) min left"
        case let .remainingHours(value): "\(value) hr left"
        case let .remainingDays(value): "\(value) day\(value == 1 ? "" : "s") left"
        case .panelTransparency: "Panel transparency"
        case .glassTransparencyAccessibility: "Glass transparency"
        case .reduceTransparencyNotice: "Reduce Transparency is enabled in System Settings, so Jotted will use a solid background."
        case .language: "Language"
        case .followSystem: "Follow System"
        case .launchAtLogin: "Open at Login"
        case .launchAtLoginEnabled: "Jotted will open at login"
        case .launchAtLoginDisabled: "Jotted will not open at login"
        case .launchAtLoginRequiresApproval: "Allow the login item in System Settings"
        case .launchAtLoginFailed: "Couldn’t change the login item setting"
        case .openSystemSettings: "Open System Settings"
        case .theme: "Color theme"
        case .themeGraphite: "Graphite"
        case .themeAurora: "Aurora"
        case .themeBlossom: "Blossom"
        case .themeAmber: "Amber"
        case .themeAbyss: "Abyss"
        case .lightMode: "Light"
        case .darkMode: "Dark"
        }
    }

    private static func japanese(_ key: Key) -> String {
        switch key {
        case .appName: "Jotted"
        case .sectionOverdue: "期限切れ"
        case .sectionToday: "今日"
        case .sectionUpcoming: "これから"
        case .sectionUndated: "日付なし"
        case .sectionCompleted: "完了済み"
        case .blankBoardHint: "空白部分を右クリックしてタスクを追加"
        case .clear: "消去"
        case .undo: "取り消す"
        case let .restoredTask(title): "「\(title)」を元に戻しました"
        case let .completedTask(title): "「\(title)」を完了しました"
        case let .deletedTask(title): "「\(title)」を削除しました"
        case .addItem: "タスクを追加"
        case .showOrHideApp: "Jottedを表示／非表示"
        case .newTodo: "新規タスク"
        case .keepOnTop: "常に手前に表示"
        case .stopKeepingOnTop: "常に手前を解除"
        case .settings: "設定…"
        case .hideApp: "Jottedを隠す"
        case .quitApp: "Jottedを終了"
        case .edit: "編集"
        case .delete: "削除"
        case .markComplete: "完了にする"
        case .markIncomplete: "未完了に戻す"
        case .moreActions: "その他の操作"
        case .completedState: "完了"
        case .incompleteState: "未完了"
        case .noDeadline: "期限なし"
        case .priorityLow: "低"
        case .priorityMedium: "中"
        case .priorityHigh: "高"
        case .priorityMediumShort: "中"
        case .priorityHighShort: "高"
        case .mediumPriorityAccessibility: "優先度：中"
        case .highPriorityAccessibility: "優先度：高"
        case .createEditorTitle: "タスクを追加"
        case .editEditorTitle: "タスクを編集"
        case .createEditorSubtitle: "あとからいつでも調整できます"
        case .editEditorSubtitle: "内容を確認して保存してください"
        case .cancel: "キャンセル"
        case .taskTitlePlaceholder: "何をしますか？"
        case .quickSettings: "クイック設定"
        case .today: "今日"
        case .tomorrow: "明日"
        case .chooseDate: "日付を選択"
        case let .deadlineDate(date): "期限、\(date)"
        case .openCalendar: "カレンダーを開く"
        case .completionTime: "期限時刻"
        case .allDayExplanation: "時刻を指定せず、その日の終わりまでに完了"
        case .priority: "優先度"
        case .add: "追加"
        case .save: "保存"
        case .allDay: "終日"
        case .time: "時刻"
        case .specificTime: "時刻指定"
        case .deadlineMode: "期限の種類"
        case .hour: "時"
        case .minute: "分"
        case let .chooseValue(value): "\(value)を選択"
        case let .hourValue(value): "\(value)時"
        case let .minuteValue(value): "\(value)分"
        case .calendarChooseAllDay: "期限日を選択 · 終日"
        case .calendarChooseKeepingTime: "期限日を選択 · 時刻を維持"
        case .previousMonth: "前の月"
        case .nextMonth: "次の月"
        case .todayRingExplanation: "リングは今日を示します"
        case .returnToToday: "今日に戻る"
        case .chooseTodayAndClose: "今日を選択してカレンダーを閉じる"
        case .selected: "選択済み"
        case .chooseThisDate: "この日付を選択"
        case .chooseAdjacentMonthDate: "隣の月のこの日付を選択"
        case let .overdueAt(time): "期限切れ · \(time)"
        case let .overdueAtAccessibility(time): "期限切れ、期限時刻は\(time)"
        case let .overdueDays(days): "\(days)日超過"
        case let .dueTodayAt(time): "今日 \(time)"
        case let .dueTodayAtAccessibility(time): "今日\(time)が期限"
        case let .dueTomorrowAt(time): "明日 \(time)"
        case let .dueTomorrowAtAccessibility(time): "明日\(time)が期限"
        case let .dueWeekdayAt(day, time): "\(day) \(time)"
        case let .dueWeekdayAtAccessibility(day, time): "\(day)\(time)が期限"
        case let .dueDate(date): date
        case let .dueDateAccessibility(date): "期限：\(date)"
        case let .allDayOverdueAccessibility(days): "終日タスク、\(days)日超過"
        case .allDayToday: "今日 · 終日"
        case .allDayTodayAccessibility: "今日が期限の終日タスク"
        case .allDayTomorrow: "明日 · 終日"
        case .allDayTomorrowAccessibility: "明日が期限の終日タスク"
        case let .allDayWeekday(day): "\(day) · 終日"
        case let .allDayWeekdayAccessibility(day): "\(day)が期限の終日タスク"
        case let .allDayDate(date): "\(date) · 終日"
        case let .allDayDateAccessibility(date): "\(date)が期限の終日タスク"
        case .remainingDueToday: "今日まで"
        case .remainingLessThanMinute: "1分未満"
        case let .remainingMinutes(value): "あと\(value)分"
        case let .remainingHours(value): "あと\(value)時間"
        case let .remainingDays(value): "あと\(value)日"
        case .panelTransparency: "パネルの透明度"
        case .glassTransparencyAccessibility: "ガラスの透明度"
        case .reduceTransparencyNotice: "システム設定で「透明度を下げる」が有効なため、Jottedは単色の背景を使用します。"
        case .language: "言語"
        case .followSystem: "システムに合わせる"
        case .launchAtLogin: "ログイン時に開く"
        case .launchAtLoginEnabled: "ログイン時にJottedを開きます"
        case .launchAtLoginDisabled: "ログイン時にJottedを開きません"
        case .launchAtLoginRequiresApproval: "システム設定でログイン項目を許可してください"
        case .launchAtLoginFailed: "ログイン項目の設定を変更できませんでした"
        case .openSystemSettings: "システム設定を開く"
        case .theme: "カラーテーマ"
        case .themeGraphite: "グラファイト"
        case .themeAurora: "オーロラ"
        case .themeBlossom: "ブロッサム"
        case .themeAmber: "アンバー"
        case .themeAbyss: "アビス"
        case .lightMode: "ライト"
        case .darkMode: "ダーク"
        }
    }

    private static func korean(_ key: Key) -> String {
        switch key {
        case .appName: "Jotted"
        case .sectionOverdue: "기한 지남"
        case .sectionToday: "오늘"
        case .sectionUpcoming: "다가오는 일정"
        case .sectionUndated: "날짜 없음"
        case .sectionCompleted: "완료됨"
        case .blankBoardHint: "빈 곳을 우클릭해 할 일을 추가하세요"
        case .clear: "지우기"
        case .undo: "실행 취소"
        case let .restoredTask(title): "‘\(title)’을(를) 복원했습니다"
        case let .completedTask(title): "‘\(title)’을(를) 완료했습니다"
        case let .deletedTask(title): "‘\(title)’을(를) 삭제했습니다"
        case .addItem: "할 일 추가"
        case .showOrHideApp: "Jotted 표시 또는 숨기기"
        case .newTodo: "새 할 일"
        case .keepOnTop: "항상 위에 표시"
        case .stopKeepingOnTop: "항상 위 해제"
        case .settings: "설정…"
        case .hideApp: "Jotted 숨기기"
        case .quitApp: "Jotted 종료"
        case .edit: "편집"
        case .delete: "삭제"
        case .markComplete: "완료로 표시"
        case .markIncomplete: "미완료로 표시"
        case .moreActions: "추가 작업"
        case .completedState: "완료"
        case .incompleteState: "미완료"
        case .noDeadline: "마감일 없음"
        case .priorityLow: "낮음"
        case .priorityMedium: "보통"
        case .priorityHigh: "높음"
        case .priorityMediumShort: "중"
        case .priorityHighShort: "고"
        case .mediumPriorityAccessibility: "보통 우선순위"
        case .highPriorityAccessibility: "높은 우선순위"
        case .createEditorTitle: "할 일 추가"
        case .editEditorTitle: "할 일 편집"
        case .createEditorSubtitle: "나중에 언제든 조정할 수 있어요"
        case .editEditorSubtitle: "확인한 뒤 저장하세요"
        case .cancel: "취소"
        case .taskTitlePlaceholder: "무엇을 해야 하나요?"
        case .quickSettings: "빠른 설정"
        case .today: "오늘"
        case .tomorrow: "내일"
        case .chooseDate: "날짜 선택"
        case let .deadlineDate(date): "마감일, \(date)"
        case .openCalendar: "달력 열기"
        case .completionTime: "마감 시간"
        case .allDayExplanation: "시간을 정하지 않고 해당 날짜가 끝나기 전까지 완료"
        case .priority: "우선순위"
        case .add: "추가"
        case .save: "저장"
        case .allDay: "종일"
        case .time: "시간"
        case .specificTime: "특정 시간"
        case .deadlineMode: "마감 시간 방식"
        case .hour: "시간"
        case .minute: "분"
        case let .chooseValue(value): "\(value) 선택"
        case let .hourValue(value): "\(value)시"
        case let .minuteValue(value): "\(value)분"
        case .calendarChooseAllDay: "마감일 선택 · 종일"
        case .calendarChooseKeepingTime: "마감일 선택 · 시간 유지"
        case .previousMonth: "이전 달"
        case .nextMonth: "다음 달"
        case .todayRingExplanation: "테두리는 오늘을 나타냅니다"
        case .returnToToday: "오늘로 돌아가기"
        case .chooseTodayAndClose: "오늘을 선택하고 달력 닫기"
        case .selected: "선택됨"
        case .chooseThisDate: "이 날짜 선택"
        case .chooseAdjacentMonthDate: "인접한 달의 이 날짜 선택"
        case let .overdueAt(time): "기한 지남 · \(time)"
        case let .overdueAtAccessibility(time): "기한이 지났습니다. 마감 시간 \(time)"
        case let .overdueDays(days): "\(days)일 지남"
        case let .dueTodayAt(time): "오늘 \(time)"
        case let .dueTodayAtAccessibility(time): "오늘 \(time) 마감"
        case let .dueTomorrowAt(time): "내일 \(time)"
        case let .dueTomorrowAtAccessibility(time): "내일 \(time) 마감"
        case let .dueWeekdayAt(day, time): "\(day) \(time)"
        case let .dueWeekdayAtAccessibility(day, time): "\(day) \(time) 마감"
        case let .dueDate(date): date
        case let .dueDateAccessibility(date): "\(date) 마감"
        case let .allDayOverdueAccessibility(days): "종일 할 일, \(days)일 지남"
        case .allDayToday: "오늘 · 종일"
        case .allDayTodayAccessibility: "오늘 마감인 종일 할 일"
        case .allDayTomorrow: "내일 · 종일"
        case .allDayTomorrowAccessibility: "내일 마감인 종일 할 일"
        case let .allDayWeekday(day): "\(day) · 종일"
        case let .allDayWeekdayAccessibility(day): "\(day) 마감인 종일 할 일"
        case let .allDayDate(date): "\(date) · 종일"
        case let .allDayDateAccessibility(date): "\(date) 마감인 종일 할 일"
        case .remainingDueToday: "오늘까지"
        case .remainingLessThanMinute: "1분 미만"
        case let .remainingMinutes(value): "\(value)분 남음"
        case let .remainingHours(value): "\(value)시간 남음"
        case let .remainingDays(value): "\(value)일 남음"
        case .panelTransparency: "패널 투명도"
        case .glassTransparencyAccessibility: "유리 투명도"
        case .reduceTransparencyNotice: "시스템 설정에서 ‘투명도 줄이기’가 켜져 있어 Jotted이 단색 배경을 사용합니다."
        case .language: "언어"
        case .followSystem: "시스템 설정 따르기"
        case .launchAtLogin: "로그인 시 열기"
        case .launchAtLoginEnabled: "로그인할 때 Jotted이 열립니다"
        case .launchAtLoginDisabled: "로그인할 때 Jotted이 열리지 않습니다"
        case .launchAtLoginRequiresApproval: "시스템 설정에서 로그인 항목을 허용하세요"
        case .launchAtLoginFailed: "로그인 항목 설정을 변경할 수 없습니다"
        case .openSystemSettings: "시스템 설정 열기"
        case .theme: "색상 테마"
        case .themeGraphite: "그래파이트"
        case .themeAurora: "오로라"
        case .themeBlossom: "블로섬"
        case .themeAmber: "앰버"
        case .themeAbyss: "애비스"
        case .lightMode: "라이트"
        case .darkMode: "다크"
        }
    }

    private static func french(_ key: Key) -> String {
        switch key {
        case .appName: "Jotted"
        case .sectionOverdue: "En retard"
        case .sectionToday: "Aujourd’hui"
        case .sectionUpcoming: "À venir"
        case .sectionUndated: "Sans date"
        case .sectionCompleted: "Terminées"
        case .blankBoardHint: "Faites un clic droit dans une zone vide pour ajouter une tâche"
        case .clear: "Effacer"
        case .undo: "Annuler"
        case let .restoredTask(title): "« \(title) » restaurée"
        case let .completedTask(title): "« \(title) » terminée"
        case let .deletedTask(title): "« \(title) » supprimée"
        case .addItem: "Ajouter une tâche"
        case .showOrHideApp: "Afficher ou masquer Jotted"
        case .newTodo: "Nouvelle tâche"
        case .keepOnTop: "Toujours au premier plan"
        case .stopKeepingOnTop: "Ne plus garder au premier plan"
        case .settings: "Réglages…"
        case .hideApp: "Masquer Jotted"
        case .quitApp: "Quitter Jotted"
        case .edit: "Modifier"
        case .delete: "Supprimer"
        case .markComplete: "Marquer comme terminée"
        case .markIncomplete: "Marquer comme non terminée"
        case .moreActions: "Plus d’actions"
        case .completedState: "Terminée"
        case .incompleteState: "Non terminée"
        case .noDeadline: "Sans échéance"
        case .priorityLow: "Basse"
        case .priorityMedium: "Moyenne"
        case .priorityHigh: "Haute"
        case .priorityMediumShort: "M"
        case .priorityHighShort: "H"
        case .mediumPriorityAccessibility: "Priorité moyenne"
        case .highPriorityAccessibility: "Priorité haute"
        case .createEditorTitle: "Ajouter une tâche"
        case .editEditorTitle: "Modifier la tâche"
        case .createEditorSubtitle: "Vous pourrez l’ajuster plus tard"
        case .editEditorSubtitle: "Enregistrez lorsque tout est prêt"
        case .cancel: "Annuler"
        case .taskTitlePlaceholder: "Que faut-il faire ?"
        case .quickSettings: "Options rapides"
        case .today: "Aujourd’hui"
        case .tomorrow: "Demain"
        case .chooseDate: "Choisir une date"
        case let .deadlineDate(date): "Échéance, \(date)"
        case .openCalendar: "Ouvrir le calendrier"
        case .completionTime: "Heure d’échéance"
        case .allDayExplanation: "À terminer avant la fin de la journée, sans heure précise"
        case .priority: "Priorité"
        case .add: "Ajouter"
        case .save: "Enregistrer"
        case .allDay: "Toute la journée"
        case .time: "Heure"
        case .specificTime: "Heure précise"
        case .deadlineMode: "Type d’échéance"
        case .hour: "heure"
        case .minute: "minute"
        case let .chooseValue(value): "Choisir \(value)"
        case let .hourValue(value): "\(value) h"
        case let .minuteValue(value): "\(value) min"
        case .calendarChooseAllDay: "Choisir une échéance · Toute la journée"
        case .calendarChooseKeepingTime: "Choisir une échéance · Conserver l’heure"
        case .previousMonth: "Mois précédent"
        case .nextMonth: "Mois suivant"
        case .todayRingExplanation: "Le cercle indique aujourd’hui"
        case .returnToToday: "Revenir à aujourd’hui"
        case .chooseTodayAndClose: "Choisir aujourd’hui et fermer le calendrier"
        case .selected: "Sélectionnée"
        case .chooseThisDate: "Choisir cette date"
        case .chooseAdjacentMonthDate: "Choisir cette date du mois adjacent"
        case let .overdueAt(time): "En retard · \(time)"
        case let .overdueAtAccessibility(time): "En retard, échéance à \(time)"
        case let .overdueDays(days): "En retard de \(days) jour\(days == 1 ? "" : "s")"
        case let .dueTodayAt(time): "Aujourd’hui \(time)"
        case let .dueTodayAtAccessibility(time): "Échéance aujourd’hui à \(time)"
        case let .dueTomorrowAt(time): "Demain \(time)"
        case let .dueTomorrowAtAccessibility(time): "Échéance demain à \(time)"
        case let .dueWeekdayAt(day, time): "\(day) \(time)"
        case let .dueWeekdayAtAccessibility(day, time): "Échéance \(day) à \(time)"
        case let .dueDate(date): date
        case let .dueDateAccessibility(date): "Échéance le \(date)"
        case let .allDayOverdueAccessibility(days): "Tâche sans heure précise, en retard de \(days) jour\(days == 1 ? "" : "s")"
        case .allDayToday: "Aujourd’hui · Toute la journée"
        case .allDayTodayAccessibility: "Tâche sans heure précise à terminer aujourd’hui"
        case .allDayTomorrow: "Demain · Toute la journée"
        case .allDayTomorrowAccessibility: "Tâche sans heure précise à terminer demain"
        case let .allDayWeekday(day): "\(day) · Toute la journée"
        case let .allDayWeekdayAccessibility(day): "Tâche sans heure précise à terminer \(day)"
        case let .allDayDate(date): "\(date) · Toute la journée"
        case let .allDayDateAccessibility(date): "Tâche sans heure précise à terminer le \(date)"
        case .remainingDueToday: "Pour aujourd’hui"
        case .remainingLessThanMinute: "Moins d’1 min"
        case let .remainingMinutes(value): "Dans \(value) min"
        case let .remainingHours(value): "Dans \(value) h"
        case let .remainingDays(value): "Dans \(value) jour\(value == 1 ? "" : "s")"
        case .panelTransparency: "Transparence du panneau"
        case .glassTransparencyAccessibility: "Transparence du verre"
        case .reduceTransparencyNotice: "L’option « Réduire la transparence » est activée dans les Réglages Système ; Jotted utilise donc un fond uni."
        case .language: "Langue"
        case .followSystem: "Suivre le système"
        case .launchAtLogin: "Ouvrir à la connexion"
        case .launchAtLoginEnabled: "Jotted s’ouvrira à la connexion"
        case .launchAtLoginDisabled: "Jotted ne s’ouvrira pas à la connexion"
        case .launchAtLoginRequiresApproval: "Autorisez l’élément d’ouverture dans les Réglages Système"
        case .launchAtLoginFailed: "Impossible de modifier le réglage d’ouverture"
        case .openSystemSettings: "Ouvrir les Réglages Système"
        case .theme: "Thème de couleur"
        case .themeGraphite: "Graphite"
        case .themeAurora: "Aurore"
        case .themeBlossom: "Floraison"
        case .themeAmber: "Ambre"
        case .themeAbyss: "Abysse"
        case .lightMode: "Clair"
        case .darkMode: "Sombre"
        }
    }

    private static func spanish(_ key: Key) -> String {
        switch key {
        case .appName: "Jotted"
        case .sectionOverdue: "Vencidas"
        case .sectionToday: "Hoy"
        case .sectionUpcoming: "Próximas"
        case .sectionUndated: "Sin fecha"
        case .sectionCompleted: "Completadas"
        case .blankBoardHint: "Haz clic derecho en un espacio vacío para añadir una tarea"
        case .clear: "Borrar"
        case .undo: "Deshacer"
        case let .restoredTask(title): "Se restauró «\(title)»"
        case let .completedTask(title): "Se completó «\(title)»"
        case let .deletedTask(title): "Se eliminó «\(title)»"
        case .addItem: "Añadir tarea"
        case .showOrHideApp: "Mostrar u ocultar Jotted"
        case .newTodo: "Nueva tarea"
        case .keepOnTop: "Mantener en primer plano"
        case .stopKeepingOnTop: "Dejar de mantener en primer plano"
        case .settings: "Ajustes…"
        case .hideApp: "Ocultar Jotted"
        case .quitApp: "Salir de Jotted"
        case .edit: "Editar"
        case .delete: "Eliminar"
        case .markComplete: "Marcar como completada"
        case .markIncomplete: "Marcar como pendiente"
        case .moreActions: "Más acciones"
        case .completedState: "Completada"
        case .incompleteState: "Pendiente"
        case .noDeadline: "Sin fecha límite"
        case .priorityLow: "Baja"
        case .priorityMedium: "Media"
        case .priorityHigh: "Alta"
        case .priorityMediumShort: "M"
        case .priorityHighShort: "A"
        case .mediumPriorityAccessibility: "Prioridad media"
        case .highPriorityAccessibility: "Prioridad alta"
        case .createEditorTitle: "Añadir una tarea"
        case .editEditorTitle: "Editar tarea"
        case .createEditorSubtitle: "Puedes ajustarla más tarde"
        case .editEditorSubtitle: "Guarda cuando todo esté listo"
        case .cancel: "Cancelar"
        case .taskTitlePlaceholder: "¿Qué hay que hacer?"
        case .quickSettings: "Opciones rápidas"
        case .today: "Hoy"
        case .tomorrow: "Mañana"
        case .chooseDate: "Elegir fecha"
        case let .deadlineDate(date): "Fecha límite, \(date)"
        case .openCalendar: "Abrir calendario"
        case .completionTime: "Hora límite"
        case .allDayExplanation: "Debe terminarse antes de que acabe el día, sin una hora concreta"
        case .priority: "Prioridad"
        case .add: "Añadir"
        case .save: "Guardar"
        case .allDay: "Todo el día"
        case .time: "Hora"
        case .specificTime: "Hora concreta"
        case .deadlineMode: "Tipo de fecha límite"
        case .hour: "hora"
        case .minute: "minuto"
        case let .chooseValue(value): "Elegir \(value)"
        case let .hourValue(value): "\(value) h"
        case let .minuteValue(value): "\(value) min"
        case .calendarChooseAllDay: "Elegir fecha límite · Todo el día"
        case .calendarChooseKeepingTime: "Elegir fecha límite · Conservar hora"
        case .previousMonth: "Mes anterior"
        case .nextMonth: "Mes siguiente"
        case .todayRingExplanation: "El círculo indica hoy"
        case .returnToToday: "Volver a hoy"
        case .chooseTodayAndClose: "Elegir hoy y cerrar el calendario"
        case .selected: "Seleccionada"
        case .chooseThisDate: "Elegir esta fecha"
        case .chooseAdjacentMonthDate: "Elegir esta fecha del mes adyacente"
        case let .overdueAt(time): "Vencida · \(time)"
        case let .overdueAtAccessibility(time): "Vencida, debía completarse a las \(time)"
        case let .overdueDays(days): "Vencida hace \(days) día\(days == 1 ? "" : "s")"
        case let .dueTodayAt(time): "Hoy \(time)"
        case let .dueTodayAtAccessibility(time): "Vence hoy a las \(time)"
        case let .dueTomorrowAt(time): "Mañana \(time)"
        case let .dueTomorrowAtAccessibility(time): "Vence mañana a las \(time)"
        case let .dueWeekdayAt(day, time): "\(day) \(time)"
        case let .dueWeekdayAtAccessibility(day, time): "Vence el \(day) a las \(time)"
        case let .dueDate(date): date
        case let .dueDateAccessibility(date): "Vence el \(date)"
        case let .allDayOverdueAccessibility(days): "Tarea de todo el día, vencida hace \(days) día\(days == 1 ? "" : "s")"
        case .allDayToday: "Hoy · Todo el día"
        case .allDayTodayAccessibility: "Tarea de todo el día que vence hoy"
        case .allDayTomorrow: "Mañana · Todo el día"
        case .allDayTomorrowAccessibility: "Tarea de todo el día que vence mañana"
        case let .allDayWeekday(day): "\(day) · Todo el día"
        case let .allDayWeekdayAccessibility(day): "Tarea de todo el día que vence el \(day)"
        case let .allDayDate(date): "\(date) · Todo el día"
        case let .allDayDateAccessibility(date): "Tarea de todo el día que vence el \(date)"
        case .remainingDueToday: "Para hoy"
        case .remainingLessThanMinute: "Menos de 1 min"
        case let .remainingMinutes(value): "\(value == 1 ? "Falta" : "Faltan") \(value) min"
        case let .remainingHours(value): "\(value == 1 ? "Falta" : "Faltan") \(value) h"
        case let .remainingDays(value): "\(value == 1 ? "Falta" : "Faltan") \(value) día\(value == 1 ? "" : "s")"
        case .panelTransparency: "Transparencia del panel"
        case .glassTransparencyAccessibility: "Transparencia del vidrio"
        case .reduceTransparencyNotice: "La opción «Reducir transparencia» está activada en Ajustes del Sistema, así que Jotted usará un fondo sólido."
        case .language: "Idioma"
        case .followSystem: "Usar el idioma del sistema"
        case .launchAtLogin: "Abrir al iniciar sesión"
        case .launchAtLoginEnabled: "Jotted se abrirá al iniciar sesión"
        case .launchAtLoginDisabled: "Jotted no se abrirá al iniciar sesión"
        case .launchAtLoginRequiresApproval: "Permite el ítem de inicio en Ajustes del Sistema"
        case .launchAtLoginFailed: "No se pudo cambiar el ajuste de inicio"
        case .openSystemSettings: "Abrir Ajustes del Sistema"
        case .theme: "Tema de color"
        case .themeGraphite: "Grafito"
        case .themeAurora: "Aurora"
        case .themeBlossom: "Flor"
        case .themeAmber: "Ámbar"
        case .themeAbyss: "Abismo"
        case .lightMode: "Claro"
        case .darkMode: "Oscuro"
        }
    }

    private static func german(_ key: Key) -> String {
        switch key {
        case .appName: "Jotted"
        case .sectionOverdue: "Überfällig"
        case .sectionToday: "Heute"
        case .sectionUpcoming: "Demnächst"
        case .sectionUndated: "Ohne Datum"
        case .sectionCompleted: "Erledigt"
        case .blankBoardHint: "Rechtsklicke auf eine freie Fläche, um eine Aufgabe hinzuzufügen"
        case .clear: "Löschen"
        case .undo: "Widerrufen"
        case let .restoredTask(title): "„\(title)“ wiederhergestellt"
        case let .completedTask(title): "„\(title)“ erledigt"
        case let .deletedTask(title): "„\(title)“ gelöscht"
        case .addItem: "Aufgabe hinzufügen"
        case .showOrHideApp: "Jotted ein- oder ausblenden"
        case .newTodo: "Neue Aufgabe"
        case .keepOnTop: "Im Vordergrund halten"
        case .stopKeepingOnTop: "Nicht mehr im Vordergrund halten"
        case .settings: "Einstellungen…"
        case .hideApp: "Jotted ausblenden"
        case .quitApp: "Jotted beenden"
        case .edit: "Bearbeiten"
        case .delete: "Löschen"
        case .markComplete: "Als erledigt markieren"
        case .markIncomplete: "Als unerledigt markieren"
        case .moreActions: "Weitere Aktionen"
        case .completedState: "Erledigt"
        case .incompleteState: "Unerledigt"
        case .noDeadline: "Keine Frist"
        case .priorityLow: "Niedrig"
        case .priorityMedium: "Mittel"
        case .priorityHigh: "Hoch"
        case .priorityMediumShort: "M"
        case .priorityHighShort: "H"
        case .mediumPriorityAccessibility: "Mittlere Priorität"
        case .highPriorityAccessibility: "Hohe Priorität"
        case .createEditorTitle: "Aufgabe hinzufügen"
        case .editEditorTitle: "Aufgabe bearbeiten"
        case .createEditorSubtitle: "Du kannst sie später jederzeit anpassen"
        case .editEditorSubtitle: "Speichere, wenn alles passt"
        case .cancel: "Abbrechen"
        case .taskTitlePlaceholder: "Was ist zu erledigen?"
        case .quickSettings: "Schnelleinstellungen"
        case .today: "Heute"
        case .tomorrow: "Morgen"
        case .chooseDate: "Datum wählen"
        case let .deadlineDate(date): "Frist, \(date)"
        case .openCalendar: "Kalender öffnen"
        case .completionTime: "Fälligkeit"
        case .allDayExplanation: "Bis zum Ende des Tages zu erledigen, ohne feste Uhrzeit"
        case .priority: "Priorität"
        case .add: "Hinzufügen"
        case .save: "Sichern"
        case .allDay: "Ganztägig"
        case .time: "Uhrzeit"
        case .specificTime: "Bestimmte Uhrzeit"
        case .deadlineMode: "Art der Frist"
        case .hour: "Stunde"
        case .minute: "Minute"
        case let .chooseValue(value): "\(value) wählen"
        case let .hourValue(value): "\(value) Uhr"
        case let .minuteValue(value): "\(value) Minuten"
        case .calendarChooseAllDay: "Fälligkeitsdatum wählen · Ganztägig"
        case .calendarChooseKeepingTime: "Fälligkeitsdatum wählen · Uhrzeit beibehalten"
        case .previousMonth: "Vorheriger Monat"
        case .nextMonth: "Nächster Monat"
        case .todayRingExplanation: "Der Ring kennzeichnet den heutigen Tag"
        case .returnToToday: "Zurück zu heute"
        case .chooseTodayAndClose: "Heute auswählen und Kalender schließen"
        case .selected: "Ausgewählt"
        case .chooseThisDate: "Dieses Datum auswählen"
        case .chooseAdjacentMonthDate: "Dieses Datum aus dem angrenzenden Monat auswählen"
        case let .overdueAt(time): "Überfällig · \(time)"
        case let .overdueAtAccessibility(time): "Überfällig, war um \(time) fällig"
        case let .overdueDays(days): "Seit \(days) Tag\(days == 1 ? "" : "en") überfällig"
        case let .dueTodayAt(time): "Heute \(time)"
        case let .dueTodayAtAccessibility(time): "Heute um \(time) fällig"
        case let .dueTomorrowAt(time): "Morgen \(time)"
        case let .dueTomorrowAtAccessibility(time): "Morgen um \(time) fällig"
        case let .dueWeekdayAt(day, time): "\(day) \(time)"
        case let .dueWeekdayAtAccessibility(day, time): "Am \(day) um \(time) fällig"
        case let .dueDate(date): date
        case let .dueDateAccessibility(date): "Fällig am \(date)"
        case let .allDayOverdueAccessibility(days): "Ganztägige Aufgabe, seit \(days) Tag\(days == 1 ? "" : "en") überfällig"
        case .allDayToday: "Heute · Ganztägig"
        case .allDayTodayAccessibility: "Ganztägige Aufgabe, heute fällig"
        case .allDayTomorrow: "Morgen · Ganztägig"
        case .allDayTomorrowAccessibility: "Ganztägige Aufgabe, morgen fällig"
        case let .allDayWeekday(day): "\(day) · Ganztägig"
        case let .allDayWeekdayAccessibility(day): "Ganztägige Aufgabe, am \(day) fällig"
        case let .allDayDate(date): "\(date) · Ganztägig"
        case let .allDayDateAccessibility(date): "Ganztägige Aufgabe, am \(date) fällig"
        case .remainingDueToday: "Heute fällig"
        case .remainingLessThanMinute: "Unter 1 Min."
        case let .remainingMinutes(value): "Noch \(value) Min."
        case let .remainingHours(value): "Noch \(value) Std."
        case let .remainingDays(value): "Noch \(value) Tag\(value == 1 ? "" : "e")"
        case .panelTransparency: "Panel-Transparenz"
        case .glassTransparencyAccessibility: "Glastransparenz"
        case .reduceTransparencyNotice: "„Transparenz reduzieren“ ist in den Systemeinstellungen aktiviert. Jotted verwendet daher einen deckenden Hintergrund."
        case .language: "Sprache"
        case .followSystem: "Systemeinstellung folgen"
        case .launchAtLogin: "Bei der Anmeldung öffnen"
        case .launchAtLoginEnabled: "Jotted wird bei der Anmeldung geöffnet"
        case .launchAtLoginDisabled: "Jotted wird bei der Anmeldung nicht geöffnet"
        case .launchAtLoginRequiresApproval: "Erlaube das Anmeldeobjekt in den Systemeinstellungen"
        case .launchAtLoginFailed: "Die Einstellung des Anmeldeobjekts konnte nicht geändert werden"
        case .openSystemSettings: "Systemeinstellungen öffnen"
        case .theme: "Farbthema"
        case .themeGraphite: "Graphit"
        case .themeAurora: "Aurora"
        case .themeBlossom: "Blüte"
        case .themeAmber: "Bernstein"
        case .themeAbyss: "Abgrund"
        case .lightMode: "Hell"
        case .darkMode: "Dunkel"
        }
    }
}
