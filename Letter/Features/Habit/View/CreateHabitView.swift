//
//  CreateHabitView.swift
//  Letter
//
//  Created by TiniT on 15/5/26.
//

import SwiftUI
import SwiftData

struct CreateHabitView: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let habitToEdit: Habit?
    private let sourceHabitForVersion: Habit?
    private let onStartNewVersion: ((Habit) -> Void)?
    private let onHabitSaved: ((Habit) -> Void)?
    
    @State private var screenTitle: String
    @State private var name: String
    @State private var icon: String
    @State private var habitDescription: String
    @State private var colorHex: String
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var frequency: HabitFrequency
    @State private var selectedDays: Set<Int>
    @State private var goalType: GoalType
    @State private var goalCountText: String
    @State private var goalUnit: String
    @State private var showSymbolPicker = false
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var showsVersionConfirmation = false
    @State private var reminders: [HabitReminderConfiguration]
    
    private let colorOptions = HabitConstant.colorOptions
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var trimmedGoalUnit: String {
        goalUnit.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var goalCount: Int {
        goalType == .todo ? 1 : Int(goalCountText) ?? 0
    }
    
    private var isEditing: Bool {
        habitToEdit != nil
    }

    private var isCreatingVersion: Bool {
        sourceHabitForVersion != nil
    }

    private var locksGoalAndSchedule: Bool {
        isEditing
    }

    private var targetVersionNumber: Int {
        (sourceHabitForVersion?.displayVersionNumber ?? 1) + 1
    }
    
    private var normalizedStartDate: Date {
        AppCalendar.current.startOfDay(for: startDate)
    }
    
    private var normalizedEndDate: Date {
        AppCalendar.current.startOfDay(for: endDate)
    }
    
    private var startDateTitle: String {
        startDate.toString(withFormat: .custom("MMM d, yyyy"))
    }
    
    private var endDateTitle: String {
        hasEndDate ? endDate.toString(withFormat: .custom("MMM d, yyyy")) : "habit.duration.noEnd".localized
    }

    private var minimumStartDate: Date? {
        guard isCreatingVersion else {
            return nil
        }

        let calendar = AppCalendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
    
    private var canSave: Bool {
        let startDateIsAllowed = minimumStartDate.map {
            normalizedStartDate >= $0
        } ?? true

        return !trimmedName.isEmpty &&
        goalCount > 0 &&
        !trimmedGoalUnit.isEmpty &&
        startDateIsAllowed &&
        (!hasEndDate || normalizedEndDate >= normalizedStartDate) &&
        (frequency != .custom || !selectedDays.isEmpty)
    }
    
    init(
        habit: Habit? = nil,
        onStartNewVersion: ((Habit) -> Void)? = nil,
        onHabitSaved: ((Habit) -> Void)? = nil
    ) {
        habitToEdit = habit
        sourceHabitForVersion = nil
        self.onStartNewVersion = onStartNewVersion
        self.onHabitSaved = onHabitSaved
        _screenTitle = State(initialValue: (habit == nil ? "habit.form.new.title" : "habit.form.edit.title").localized)
        _name = State(initialValue: habit?.name ?? "")
        _icon = State(initialValue: habit?.icon ?? "star.fill")
        _habitDescription = State(initialValue: habit?.habitDescription ?? "")
        _colorHex = State(initialValue: habit?.colorHex ?? HabitConstant.defaultColor)
        _startDate = State(initialValue: habit?.effectiveStartDate ?? Date())
        _hasEndDate = State(initialValue: habit?.endDate != nil)
        _endDate = State(initialValue: habit?.endDate ?? Date())
        _frequency = State(initialValue: habit?.frequency ?? .daily)
        _selectedDays = State(initialValue: Set(habit?.targetDaysOfWeek ?? Array(0...6)))
        _goalType = State(initialValue: habit?.goalType ?? .count)
        _goalCountText = State(initialValue: String(habit?.goalCount ?? 1))
        _goalUnit = State(initialValue: habit?.goalUnit ?? "habit.goal.times".localized)
        var reminderConfigurations: [HabitReminderConfiguration] = []
        if let habit {
            for reminder in habit.reminders {
                reminderConfigurations.append(HabitReminderConfiguration(reminder))
            }
            reminderConfigurations.sort { $0.time < $1.time }
        }
        _reminders = State(initialValue: reminderConfigurations)
    }

    init(
        newVersionOf habit: Habit,
        onHabitSaved: ((Habit) -> Void)? = nil
    ) {
        let calendar = AppCalendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        let inheritedEndDate = habit.endDate.flatMap {
            calendar.startOfDay(for: $0) >= tomorrow ? $0 : nil
        }

        habitToEdit = nil
        sourceHabitForVersion = habit
        onStartNewVersion = nil
        self.onHabitSaved = onHabitSaved
        _screenTitle = State(initialValue: "habit.version.number".localized(habit.displayVersionNumber + 1))
        _name = State(initialValue: habit.name)
        _icon = State(initialValue: habit.icon)
        _habitDescription = State(initialValue: habit.habitDescription)
        _colorHex = State(initialValue: habit.colorHex)
        _startDate = State(initialValue: tomorrow)
        _hasEndDate = State(initialValue: inheritedEndDate != nil)
        _endDate = State(initialValue: inheritedEndDate ?? tomorrow)
        _frequency = State(initialValue: habit.frequency)
        _selectedDays = State(initialValue: Set(habit.targetDaysOfWeek.isEmpty ? Array(0...6) : habit.targetDaysOfWeek))
        _goalType = State(initialValue: habit.goalType)
        _goalCountText = State(initialValue: String(habit.goalCount))
        _goalUnit = State(initialValue: habit.goalUnit)
        _reminders = State(
            initialValue: habit.reminders
                .map {
                    HabitReminderConfiguration(
                        time: $0.time,
                        daysOfWeek: $0.daysOfWeek,
                        isEnabled: $0.isEnabled
                    )
                }
                .sorted { $0.time < $1.time }
        )
    }
    
    var body: some View {
        BaseScreen($screenTitle) {
            AppScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isCreatingVersion {
                        versionContextSection
                    }
                    identitySection
                    scheduleSection
                    durationSection
                    goalSection
                    reminderSection
                    styleSection
                    previewItem
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        // MARK: - ToolBar
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if isCreatingVersion {
                        showsVersionConfirmation = true
                    } else {
                        saveHabit()
                    }
                } label: {
                    Text((isCreatingVersion ? "common.create" : "common.save").localized)
                        .fontWeight(canSave ? .bold : .regular)
                }
                .disabled(!canSave)
            }
        }
        .animation(.snappy, value: goalType)
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerSheetView(selectedSymbol: $icon)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStartDatePicker) {
            CalendarPickerSheetView(
                title: "habit.duration.startDate".localized,
                initialDate: startDate,
                minimumDate: minimumStartDate
            ) { selectedDate in
                startDate = selectedDate
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showEndDatePicker) {
            CalendarPickerSheetView(
                title: "habit.duration.endDate".localized,
                initialDate: hasEndDate ? endDate : max(startDate, Date()),
                minimumDate: startDate,
                clearTitle: hasEndDate ? "habit.common.reset".localized : nil
            ) { selectedDate in
                endDate = selectedDate
                hasEndDate = true
            } onClear: {
                hasEndDate = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .commonConfirmationDialog(
            isPresented: $showsVersionConfirmation,
            title: "habit.version.create.confirmation".localized(targetVersionNumber),
            message: "habit.version.create.warning".localized(targetVersionNumber),
            actions: [
                ConfirmationDialogAction("habit.version.create.action".localized(targetVersionNumber)) {
                    saveHabit()
                },
                ConfirmationDialogAction("common.cancel".localized, role: .cancel) {}
            ]
        )
    }
    
    @ViewBuilder
    private var versionContextSection: some View {
        if let sourceHabitForVersion {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(module: "arrow.triangle.2.circlepath")
                        .customFont(.headline)
                        .frame(width: 36, height: 36)
                        .borderedBackground(cornerRadius: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("habit.version.number".localized(targetVersionNumber))
                            .customFont(.headline)

                        Text("habit.version.continuesFromNumber".localized(sourceHabitForVersion.displayVersionNumber))
                            .customFont(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    versionContextRow(
                        title: "habit.version.previousRepeat".localized,
                        value: repeatTitle(for: sourceHabitForVersion)
                    )

                    Divider().opacity(0.28)

                    versionContextRow(
                        title: "habit.version.whatHappens".localized,
                        value: "habit.version.behavior".localized
                    )
                }

                Text("habit.version.help".localized)
                    .customFont(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .borderedBackground(cornerRadius: 16)
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("habit.form.identity".localized)
                .customFont(.headline)
            
            TextField("habit.form.name".localized, text: $name)
                .textInputAutocapitalization(.words)
                .padding()
                .appGlassEffect(
                    .regular,
                    in: .rect(cornerRadius: 12)
                )
            
            HStack(spacing: 12) {
                Button {
                    baseAnimation {
                        showSymbolPicker = true
                    }
                } label: {
                    Image(module: icon)
                        .resizable()
                        .padding()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundStyle(Color.init(hex: colorHex))
                        .appGlassEffect(
                            .regular,
                            in: .rect(cornerRadius: 12)
                        )
                }
                
                TextField("habit.form.description".localized, text: $habitDescription)
                    .frame(height: 60)
                    .padding(.horizontal)
                    .appGlassEffect(
                        .regular,
                        in: .rect(cornerRadius: 12)
                    )
            }
        }
    }
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("habit.repeat.title".localized)
                .customFont(.headline)
            
            AppPicker(
                "habit.repeat.title".localized,
                selection: $frequency,
                layout: .control
            ) {
                Text("habit.repeat.daily".localized).tag(HabitFrequency.daily)
                Text("habit.repeat.weekday".localized).tag(HabitFrequency.weekday)
                Text("habit.repeat.weekend".localized).tag(HabitFrequency.weekend)
                Text("habit.repeat.custom".localized).tag(HabitFrequency.custom)
            }
            .pickerStyle(.segmented)
            .onChange(of: frequency) { _, newValue in
                applyDefaultDays(for: newValue)
            }
            .onChange(of: startDate) { _, newValue in
                if hasEndDate && normalizedEndDate < AppCalendar.current.startOfDay(for: newValue) {
                    endDate = newValue
                }
            }
            .disabled(locksGoalAndSchedule)
            
            HStack(spacing: 8) {
                ForEach(habitViewModel.orderedWeekdays, id: \.self) { weekday in
                    Button {
                        toggleWeekday(weekday)
                    } label: {
                        let tintColor = selectedDays.contains(weekday)
                        ? Color.cyan.opacity(0.38)
                        : Color.primary.opacity(0.06)
                        
                        Text(shortWeekdayName(for: weekday))
                            .customFont(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .foregroundStyle(selectedDays.contains(weekday) ? .white : .primary)
                            .appGlassEffect(
                                .regular.tint(tintColor),
                                in: .rect(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(locksGoalAndSchedule)
                }
            }
            
            if isEditing {
                lockedVersionPrompt(
                    message: "habit.repeat.locked".localized
                )
            }
        }
    }
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("habit.duration.title".localized)
                .customFont(.headline)
            
            HStack(spacing: 12) {
                dateButton(title: "habit.duration.startDate".localized, value: startDateTitle) {
                    showStartDatePicker = true
                }
                
                dateButton(title: "habit.duration.endDate".localized, value: endDateTitle) {
                    if !hasEndDate {
                        endDate = max(startDate, Date())
                    }
                    
                    showEndDatePicker = true
                }
            }
        }
    }
    
    private func dateButton(
        title: String,
        value: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(module: "calendar")
                    .customFont(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .customFont(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(value)
                        .customFont(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 12)
            .appGlassEffect(
                in: .rect(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)

    }
    
    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("habit.goal.title".localized)
                .customFont(.headline)
            
            AppPicker(
                "habit.goal.type".localized,
                selection: $goalType,
                layout: .control
            ) {
                Text("habit.goal.count".localized).tag(GoalType.count)
                Text("habit.goal.todo".localized).tag(GoalType.todo)
            }
            .pickerStyle(.segmented)
            .onChange(of: goalType) { _, newValue in
                if newValue == .todo {
                    goalCountText = "1"
                    goalUnit = "habit.goal.times".localized
                }
            }
            .disabled(locksGoalAndSchedule)
            
            if goalType == .count {
                HStack(spacing: 12) {
                    TextField("habit.goal.target".localized, text: $goalCountText)
                        .keyboardType(.numberPad)
                        .disabled(goalType == .todo || locksGoalAndSchedule)
                        .padding()
                        .appGlassEffect(
                            in: .rect(cornerRadius: 12)
                        )
                    
                    TextField("habit.goal.unit".localized, text: $goalUnit)
                        .disabled(locksGoalAndSchedule)
                        .padding()
                        .appGlassEffect(
                            in: .rect(cornerRadius: 12)
                        )
                }
                .transition(.opacity)
            }
            
            if isEditing {
                lockedVersionPrompt(
                    message: "habit.goal.locked".localized
                )
            }
        }
    }

    private func lockedVersionPrompt(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .customFont(.footnote)
                .foregroundStyle(.secondary)

            if let habitToEdit, onStartNewVersion != nil {
                Button {
                    onStartNewVersion?(habitToEdit)
                } label: {
                    HStack(spacing: 8) {
                        Image(module: "arrow.triangle.2.circlepath")
                            .customFont(.caption, weight: .semibold)

                        Text("habit.version.start".localized(habitToEdit.displayVersionNumber + 1))
                            .customFont(.footnote, weight: .semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .borderedBackground(cornerRadius: 10)
            }
        }
    }

    private func versionContextRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .customFont(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .customFont(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 30)
    }

    private func repeatTitle(for habit: Habit) -> String {
        switch habit.frequency {
        case .daily:
            "habit.repeat.daily".localized
        case .weekday:
            "habit.repeat.weekdays".localized
        case .weekend:
            "habit.repeat.weekends".localized
        case .custom:
            "habit.repeat.custom".localized
        }
    }

    private func goalTitle(for habit: Habit) -> String {
        habit.goalType == .todo ? "habit.goal.completeOnce".localized : "\(habit.goalCount) \(habit.goalUnit)"
    }
    
    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("habit.style.title".localized)
                .customFont(.headline)
            
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(colorOptions, id: \.self) { hex in
                        Button {
                            colorHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    Circle()
                                        .stroke(colorHex == hex ? Color.primary : Color.clear, lineWidth: 2)
                                }
                        }
                        .buttonStyle(.plain)
                        .padding(2)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private var previewItem: some View {
        let emptyHabit = Habit(
            name: trimmedName,
            description: habitDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            colorHex: colorHex,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            frequency: frequency,
            targetDaysOfWeek: Array(selectedDays).sorted(),
            goalType: goalType,
            goalCount: goalCount,
            goalUnit: trimmedGoalUnit
        )
        
        let entry = HabitEntry(
            date: Date(),
            completedCount: 0,
            note: "Read 20 pages and practiced SwiftUI"
        )
        
        emptyHabit.entries.append(entry)
        
        let halfHabit = Habit(
            name: trimmedName,
            description: habitDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            colorHex: colorHex,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            frequency: frequency,
            targetDaysOfWeek: Array(selectedDays).sorted(),
            goalType: goalType,
            goalCount: goalCount,
            goalUnit: trimmedGoalUnit
        )
        
        let halfEntry = HabitEntry(
            date: Date(),
            completedCount: goalCount / 2,
            note: "Read 20 pages and practiced SwiftUI"
        )
        
        halfHabit.entries.append(halfEntry)
        
        let doneHabit = Habit(
            name: trimmedName,
            description: habitDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            colorHex: colorHex,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            frequency: frequency,
            targetDaysOfWeek: Array(selectedDays).sorted(),
            goalType: goalType,
            goalCount: goalCount,
            goalUnit: trimmedGoalUnit
        )
        
        let doneEntry = HabitEntry(
            date: Date(),
            completedCount: goalCount,
            note: "Read 20 pages and practiced SwiftUI"
        )
        
        doneHabit.entries.append(doneEntry)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("habit.preview.title".localized)
                .customFont(.headline)
            
            Text("habit.status.untracked".localized)
                .customFont(.subheadline)
            HabitItemView(habit: emptyHabit, selectedDate: Date())
            
            if goalType == .count && goalCount > 1 {
                Text("habit.status.inProgress".localized)
                    .customFont(.subheadline)
                HabitItemView(habit: halfHabit, selectedDate: Date())
            }
            
            Text("common.done".localized)
                .customFont(.subheadline)
            HabitItemView(habit: doneHabit, selectedDate: Date())
        }
    }
    
    private func saveHabit() {
        guard canSave else { return }
        
        if let habitToEdit {
            habitViewModel.updateHabit(
                habitToEdit,
                name: trimmedName,
                description: habitDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                icon: icon,
                colorHex: colorHex,
                startDate: normalizedStartDate,
                endDate: hasEndDate ? normalizedEndDate : nil,
                frequency: habitToEdit.frequency,
                targetDaysOfWeek: habitToEdit.targetDaysOfWeek,
                goalType: habitToEdit.goalType,
                goalCount: habitToEdit.goalCount,
                goalUnit: habitToEdit.goalUnit,
                reminders: reminders
            )
        } else if let sourceHabitForVersion {
            let habit = Habit(
                name: trimmedName,
                description: habitDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                icon: icon,
                colorHex: colorHex,
                startDate: normalizedStartDate,
                endDate: hasEndDate ? normalizedEndDate : nil,
                frequency: frequency,
                targetDaysOfWeek: Array(selectedDays).sorted(),
                goalType: goalType,
                goalCount: goalCount,
                goalUnit: trimmedGoalUnit
            )

            if let savedHabit = habitViewModel.createHabitVersion(
                replacing: sourceHabitForVersion,
                with: habit,
                reminders: reminders
            ) {
                onHabitSaved?(savedHabit)
            } else {
                return
            }
        } else {
            let habit = Habit(
                name: trimmedName,
                description: habitDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                icon: icon,
                colorHex: colorHex,
                startDate: normalizedStartDate,
                endDate: hasEndDate ? normalizedEndDate : nil,
                frequency: frequency,
                targetDaysOfWeek: Array(selectedDays).sorted(),
                goalType: goalType,
                goalCount: goalCount,
                goalUnit: trimmedGoalUnit
            )
            
            habitViewModel.addHabit(habit, reminders: reminders)
        }
        
        dismiss()
    }
    
    private func applyDefaultDays(for frequency: HabitFrequency) {
        switch frequency {
        case .daily:
            selectedDays = Set(0...6)
        case .weekday:
            selectedDays = [1, 2, 3, 4, 5]
        case .weekend:
            selectedDays = [0, 6]
        case .custom:
            break
        }
    }
    
    private func toggleWeekday(_ weekday: Int) {
        if selectedDays.contains(weekday) {
            selectedDays.remove(weekday)
        } else {
            selectedDays.insert(weekday)
        }

        syncFrequencyWithSelectedDays()
    }

    private func syncFrequencyWithSelectedDays() {
        if selectedDays == Set(0...6) {
            frequency = .daily
        } else if selectedDays == Set(1...5) {
            frequency = .weekday
        } else if selectedDays == Set([0, 6]) {
            frequency = .weekend
        } else {
            frequency = .custom
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("habit.reminder.title".localized)
                    .customFont(.headline)

                Spacer()

                Button {
                    addReminder()
                } label: {
                    Image(module: "plus")
                        .fontWeight(.bold)
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("habit.reminder.add".localized)
            }

            if reminders.isEmpty {
                Text("habit.reminder.empty".localized)
                    .customFont(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .appGlassEffect(
                        in: .rect(cornerRadius: 12)
                    )
            } else {
                VStack(spacing: 10) {
                    ForEach($reminders) { $reminder in
                        reminderRow(reminder: $reminder)
                    }
                }
            }

            Text("habit.reminder.repeatHelp".localized)
                .customFont(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func reminderRow(reminder: Binding<HabitReminderConfiguration>) -> some View {
        HStack(spacing: 12) {
            Image(module: "bell")
                .customFont(.headline)
                .foregroundStyle(.secondary)

            DatePicker(
                "habit.reminder.time".localized,
                selection: reminder.time,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()

            Spacer(minLength: 0)

            Button(role: .destructive) {
                deleteReminder(id: reminder.wrappedValue.id)
            } label: {
                Image(module: "trash")
                    .frame(width: 30, height: 30)
            }
            .accessibilityLabel("habit.reminder.delete".localized)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .appGlassEffect(
            in: .rect(cornerRadius: 12)
        )
    }

    private func addReminder() {
        let nextTime = AppCalendar.current.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()

        reminders.append(HabitReminderConfiguration(time: nextTime))
        reminders.sort { $0.time < $1.time }
    }

    private func deleteReminder(id: UUID) {
        reminders.removeAll { $0.id == id }
    }
    
    private func shortWeekdayName(for weekday: Int) -> String {
        HabitDateText.weekdayName(for: weekday)
    }
}

private struct SymbolPickerSheetView: View {
    @Binding var selectedSymbol: String
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.adaptive(minimum: 52), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("habit.symbol.choose".localized)
                .customFont(.headline)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(HabitConstant.habitSymbolOptions, id: \.self) { symbol in
                        Button {
                            selectedSymbol = symbol
                            dismiss()
                        } label: {
                            Image(module: symbol)
                                .customFont(.title3)
                                .padding(8)
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(selectedSymbol == symbol ? .white : .primary)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedSymbol == symbol ? Color.cyan : Color.primary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(20)
    }
}

private struct CalendarPickerSheetView: View {
    let title: String
    var minimumDate: Date?
    var clearTitle: String?
    let onDone: (Date) -> Void
    var onClear: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date
    
    init(
        title: String,
        initialDate: Date,
        minimumDate: Date? = nil,
        clearTitle: String? = nil,
        onDone: @escaping (Date) -> Void,
        onClear: (() -> Void)? = nil
    ) {
        self.title = title
        self.minimumDate = minimumDate
        self.clearTitle = clearTitle
        self.onDone = onDone
        self.onClear = onClear
        _selectedDate = State(initialValue: initialDate)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let minimumDate {
                    DatePicker(
                        title,
                        selection: $selectedDate,
                        in: minimumDate...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                } else {
                    DatePicker(title, selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
            }
            .ignoresSafeArea()
            .offset(y: -30)
            .padding(.horizontal)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                
                if let clearTitle, let onClear {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) {
                            onClear()
                            dismiss()
                        } label: {
                            Text(clearTitle)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) {
                        onDone(selectedDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Habit.self, HabitEntry.self, HabitReminder.self, UserProfile.self,
        configurations: config
    )
    
    NavigationStack {
        CreateHabitView()
            .modelContainer(container)
            .environment(HabitViewModel(
                repository: SwiftDataHabitRepository(modelContext: container.mainContext),
                notificationScheduler: HabitNotificationScheduler()
            ))
    }
}
