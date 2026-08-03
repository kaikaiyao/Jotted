import JottedCore
import SwiftUI

struct TaskEditorContext: Identifiable, Equatable {
    enum Mode: Equatable {
        case create
        case edit(TodoItem)
    }

    let id = UUID()
    let mode: Mode

    static var create: TaskEditorContext {
        TaskEditorContext(mode: .create)
    }

    var item: TodoItem? {
        guard case let .edit(item) = mode else { return nil }
        return item
    }
}

struct TaskDraft {
    let title: String
    let deadline: Date?
    let priority: TodoPriority
    let isAllDay: Bool

    init(
        title: String,
        deadline: Date?,
        priority: TodoPriority,
        isAllDay: Bool = false
    ) {
        self.title = title
        self.deadline = deadline
        self.priority = priority
        self.isAllDay = isAllDay
    }
}

struct TaskEditorView: View {
    let context: TaskEditorContext
    let onCancel: () -> Void
    let onSave: (TaskDraft) -> Void

    @State private var title: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var priority: TodoPriority
    @State private var isAllDay: Bool
    @State private var lastTimedHour: Int
    @State private var lastTimedMinute: Int
    @State private var showsCalendar = false
    @FocusState private var isTitleFocused: Bool

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var localization = AppLocalization.shared
    @AppStorage(AppearanceThemePreference.key) private var themeRaw = AppearanceThemePreference.defaultValue

    private var activeTheme: AppearanceTheme {
        AppearanceTheme(rawValue: themeRaw) ?? .defaultTheme
    }

    init(
        context: TaskEditorContext,
        onCancel: @escaping () -> Void,
        onSave: @escaping (TaskDraft) -> Void
    ) {
        self.context = context
        self.onCancel = onCancel
        self.onSave = onSave

        let item = context.item
        _title = State(initialValue: item?.title ?? "")
        _hasDeadline = State(initialValue: item?.deadline != nil)
        _deadline = State(initialValue: item?.deadline ?? Self.defaultDeadline())
        _priority = State(initialValue: item?.priority ?? .medium)
        _isAllDay = State(initialValue: item?.deadline == nil ? true : (item?.isAllDay ?? true))

        let storedTime = item?.isAllDay == true ? nil : item?.deadline.map {
            Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: $0)
        }
        _lastTimedHour = State(initialValue: storedTime?.hour ?? 18)
        _lastTimedMinute = State(initialValue: storedTime?.minute ?? 0)
    }

    var body: some View {
        // Reading this preference keeps the static semantic palette in sync
        // while an editor window is already open.
        let _ = themeRaw

        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.text(context.item == nil ? .createEditorTitle : .editEditorTitle))
                        .font(.system(size: 16, weight: .semibold))
                    Text(localization.text(context.item == nil ? .createEditorSubtitle : .editEditorSubtitle))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(JottedPalette.controlForeground(for: colorScheme).opacity(0.82))
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(JottedPalette.controlFill(for: colorScheme))
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.84), lineWidth: 0.7)
                                }
                        )
                        .shadow(color: JottedPalette.filledAccent.opacity(colorScheme == .dark ? 0.12 : 0.06), radius: 5, y: 2)
                }
                .buttonStyle(.plain)
                .help(localization.text(.cancel))
                .accessibilityLabel(localization.text(.cancel))
            }

            TextField(localization.text(.taskTitlePlaceholder), text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? JottedPalette.filledAccent(for: colorScheme).opacity(0.32)
                                : Color.white.opacity(0.54)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.88), lineWidth: 0.8)
                        }
                )
                .shadow(color: JottedPalette.filledAccent.opacity(colorScheme == .dark ? 0.10 : 0.045), radius: 6, y: 2)
                .focused($isTitleFocused)
                .onSubmit(save)

            VStack(alignment: .leading, spacing: 7) {
                Text(localization.text(.quickSettings))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 7) {
                    Spacer(minLength: 0)
                    quickDateButton(localization.text(.today), dayOffset: 0)
                    quickDateButton(localization.text(.tomorrow), dayOffset: 1)
                    Button(localization.text(hasDeadline ? .sectionUndated : .chooseDate)) {
                        toggleDeadlineSelection()
                    }
                    .buttonStyle(CapsuleActionStyle())
                }
            }

            if hasDeadline {
                VStack(spacing: 9) {
                    HStack(spacing: 8) {
                        Button {
                            showsCalendar.toggle()
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(formattedDeadlineDate)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .opacity(0.55)
                            }
                            .foregroundStyle(JottedPalette.controlForeground(for: colorScheme))
                            .padding(.horizontal, 11)
                            .frame(height: 32)
                            .background(controlCapsule(isSelected: showsCalendar))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showsCalendar, arrowEdge: .bottom) {
                            ModernCalendarPicker(
                                selection: $deadline,
                                isAllDay: isAllDay,
                                onSelect: { showsCalendar = false }
                            )
                        }
                        .help(localization.text(.chooseDate))
                        .accessibilityLabel(localization.text(.deadlineDate(formattedDeadlineDate)))
                        .accessibilityHint(localization.text(.openCalendar))

                        Spacer(minLength: 0)

                        deadlineModeControl
                    }

                    if !isAllDay {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(JottedPalette.accent(for: colorScheme))

                            Text(localization.text(.completionTime))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 0)

                            timeMenu(
                                value: deadlineHour,
                                values: Array(0..<24),
                                label: localization.text(.hour),
                                accessibilityValue: { localization.text(.hourValue($0)) }
                            ) { setDeadline(hour: $0) }

                            Text(":")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)

                            timeMenu(
                                value: deadlineMinute,
                                values: Array(stride(from: 0, through: 55, by: 5)),
                                label: localization.text(.minute),
                                accessibilityValue: { localization.text(.minuteValue($0)) }
                            ) { setDeadline(minute: $0) }
                        }
                        .padding(.horizontal, 3)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "sun.max")
                                .font(.system(size: 10, weight: .semibold))
                            Text(localization.text(.allDayExplanation))
                                .font(.system(size: 10.5, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 3)
                        .transition(.opacity)
                    }
                }
                .padding(9)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? JottedPalette.filledAccent(for: colorScheme).opacity(0.24)
                                : Color.white.opacity(0.34)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: colorScheme == .dark
                                            ? [Color.white.opacity(0.055), Color.clear]
                                            : [Color.white.opacity(0.44), Color.white.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(
                                    Color.white.opacity(colorScheme == .dark ? 0.13 : 0.88),
                                    lineWidth: 0.8
                                )
                        }
                )
                .shadow(color: JottedPalette.filledAccent.opacity(colorScheme == .dark ? 0.10 : 0.045), radius: 7, y: 3)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(localization.text(.priority))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Picker(localization.text(.priority), selection: $priority) {
                        Text(localization.text(.priorityLow)).tag(TodoPriority.low)
                        Text(localization.text(.priorityMedium)).tag(TodoPriority.medium)
                        Text(localization.text(.priorityHigh)).tag(TodoPriority.high)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                    .tint(JottedPalette.accent(for: colorScheme))

                    Spacer(minLength: 0)

                    Button(localization.text(context.item == nil ? .add : .save), action: save)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 30)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            JottedPalette.accent(for: colorScheme),
                                            JottedPalette.filledAccent(for: colorScheme)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .opacity(canSave ? 1 : 0.35)
                                .overlay {
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.36), lineWidth: 0.7)
                                }
                        )
                        .shadow(color: JottedPalette.filledAccent.opacity(canSave ? 0.18 : 0.04), radius: 7, y: 3)
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                }
            }
        }
        .padding(18)
        .frame(width: 336)
        .background {
            ZStack {
                // Both glass paths render sheer over a transparent panel, so
                // the window keeps an opaque-enough backing of its own.
                JottedPalette.panelTint(for: colorScheme)
                    .opacity(colorScheme == .dark ? 0.58 : 0.62)
                ThemeAmbientWash(theme: activeTheme, colorScheme: colorScheme)
                    .opacity(activeTheme.floatingAmbientOpacity(for: colorScheme))
                    .blendMode(colorScheme == .dark ? .screen : .normal)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .jottedGlass(
            in: RoundedRectangle(cornerRadius: 26, style: .continuous),
            tint: activeTheme.glassTint(for: colorScheme)
        ) {
            LegacyGlassSurface(
                shape: RoundedRectangle(cornerRadius: 26, style: .continuous),
                tint: JottedPalette.panelTint(for: colorScheme)
                    .opacity(colorScheme == .dark ? 0.42 : 0.46)
            )
        }
        .shadow(
            color: colorScheme == .dark
                ? Color.black.opacity(0.30)
                : activeTheme.isChromatic
                    ? Color.black.opacity(0.075)
                    : JottedPalette.filledAccent(for: colorScheme).opacity(0.105),
            radius: colorScheme == .dark ? 24 : 26,
            y: colorScheme == .dark ? 11 : 10
        )
        .onAppear {
            DispatchQueue.main.async {
                isTitleFocused = true
            }
        }
        .onExitCommand(perform: onCancel)
        .environment(\.locale, localization.locale)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var formattedDeadlineDate: String {
        let calendar = Calendar.autoupdatingCurrent
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let includesYear = !calendar.isDate(deadline, equalTo: Date(), toGranularity: .year)
        formatter.setLocalizedDateFormatFromTemplate(includesYear ? "yMMMdEEE" : "MMMdEEE")
        return formatter.string(from: deadline)
    }

    private var deadlineHour: Int {
        Calendar.autoupdatingCurrent.component(.hour, from: deadline)
    }

    private var deadlineMinute: Int {
        Calendar.autoupdatingCurrent.component(.minute, from: deadline)
    }

    private var deadlineModeControl: some View {
        HStack(spacing: 2) {
            deadlineModeButton(localization.text(.allDay), modeIsAllDay: true)
            deadlineModeButton(localization.text(.time), modeIsAllDay: false)
        }
        .padding(2)
        .background(
            Capsule()
                .fill(JottedPalette.controlFill(for: colorScheme).opacity(colorScheme == .dark ? 0.78 : 0.72))
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.84), lineWidth: 0.7)
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localization.text(.deadlineMode))
    }

    private func deadlineModeButton(_ label: String, modeIsAllDay: Bool) -> some View {
        let isSelected = isAllDay == modeIsAllDay
        return Button {
            setDeadlineMode(allDay: modeIsAllDay)
        } label: {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : JottedPalette.controlForeground(for: colorScheme).opacity(0.68))
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(
                    Capsule()
                        .fill(isSelected ? JottedPalette.filledAccent(for: colorScheme) : .clear)
                        .overlay {
                            if isSelected {
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.6)
                            }
                        }
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localization.text(modeIsAllDay ? .allDay : .specificTime))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func controlCapsule(isSelected: Bool) -> some View {
        Capsule()
            .fill(
                isSelected
                    ? JottedPalette.accent(for: colorScheme).opacity(colorScheme == .dark ? 0.26 : 0.12)
                    : JottedPalette.controlFill(for: colorScheme).opacity(colorScheme == .dark ? 0.80 : 0.76)
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? JottedPalette.accent(for: colorScheme).opacity(0.34)
                            : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.84),
                        lineWidth: 0.7
                    )
            }
    }

    private func timeMenu(
        value: Int,
        values: [Int],
        label: String,
        accessibilityValue: @escaping (Int) -> String,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        Menu {
            ForEach(values, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    if option == value {
                        Label(String(format: "%02d", option), systemImage: "checkmark")
                    } else {
                        Text(String(format: "%02d", option))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(String(format: "%02d", value))
                    .monospacedDigit()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .opacity(0.48)
            }
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundStyle(JottedPalette.controlForeground(for: colorScheme))
            .padding(.horizontal, 9)
            .frame(height: 27)
            .background(controlCapsule(isSelected: false))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(localization.text(.chooseValue(label)))
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue(value))
    }

    private func quickDateButton(_ label: String, dayOffset: Int) -> some View {
        Button(label) {
            let calendar = Calendar.autoupdatingCurrent
            let base = calendar.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
            let updatedDeadline = isAllDay
                ? Self.normalizedAllDayDate(base, calendar: calendar)
                : Self.dateAtUsefulHour(base, calendar: calendar)
            deadline = updatedDeadline
            if !isAllDay {
                lastTimedHour = calendar.component(.hour, from: updatedDeadline)
                lastTimedMinute = calendar.component(.minute, from: updatedDeadline)
            }
            withAnimation(.easeInOut(duration: 0.16)) {
                hasDeadline = true
            }
        }
        .buttonStyle(CapsuleActionStyle())
    }

    private func save() {
        guard canSave else { return }
        onSave(
            TaskDraft(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                deadline: hasDeadline
                    ? (isAllDay ? Self.normalizedAllDayDate(deadline, calendar: .autoupdatingCurrent) : deadline)
                    : nil,
                priority: priority,
                isAllDay: hasDeadline && isAllDay
            )
        )
    }

    private static func defaultDeadline() -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return normalizedAllDayDate(tomorrow, calendar: calendar)
    }

    private func setDeadlineMode(allDay: Bool) {
        guard isAllDay != allDay else { return }
        withAnimation(.easeInOut(duration: 0.16)) {
            if allDay {
                let calendar = Calendar.autoupdatingCurrent
                lastTimedHour = calendar.component(.hour, from: deadline)
                lastTimedMinute = calendar.component(.minute, from: deadline)
                deadline = Self.normalizedAllDayDate(deadline, calendar: .autoupdatingCurrent)
            } else {
                deadline = Calendar.autoupdatingCurrent.date(
                    bySettingHour: lastTimedHour,
                    minute: lastTimedMinute,
                    second: 0,
                    of: deadline
                ) ?? deadline
            }
            isAllDay = allDay
        }
    }

    private func setDeadline(hour: Int? = nil, minute: Int? = nil) {
        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: deadline)
        var updated = DateComponents()
        updated.calendar = calendar
        updated.timeZone = calendar.timeZone
        updated.year = components.year
        updated.month = components.month
        updated.day = components.day
        updated.hour = hour ?? components.hour ?? 18
        updated.minute = minute ?? components.minute ?? 0
        updated.second = 0
        if let date = calendar.date(from: updated) {
            deadline = date
            lastTimedHour = updated.hour ?? 18
            lastTimedMinute = updated.minute ?? 0
        }
    }

    private func toggleDeadlineSelection() {
        if hasDeadline {
            showsCalendar = false
            withAnimation(.easeInOut(duration: 0.16)) {
                hasDeadline = false
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            hasDeadline = true
        }
        DispatchQueue.main.async {
            showsCalendar = true
        }
    }

    private static func normalizedAllDayDate(_ date: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    private static func dateAtUsefulHour(_ date: Date, calendar: Calendar) -> Date {
        if calendar.isDateInToday(date) {
            let now = Date()
            let sixPM = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date) ?? date
            if sixPM > now { return sixPM }

            let currentHour = calendar.component(.hour, from: now)
            let targetHour = min(currentHour + 1, 23)
            let targetMinute = currentHour >= 23 ? 55 : 0
            return calendar.date(
                bySettingHour: targetHour,
                minute: targetMinute,
                second: 0,
                of: date
            ) ?? date
        }
        return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date) ?? date
    }
}
