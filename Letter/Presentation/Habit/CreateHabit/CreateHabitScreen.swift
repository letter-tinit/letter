//
//  CreateHabitView.swift
//  Letter
//
//  Created by TiniT on 15/5/26.
//

import SwiftUI

struct CreateHabitScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateHabitViewModel
    
    private let onStartNewVersion: (() -> Void)?
    private let onHabitSaved: ((UUID) -> Void)?
    
    @State private var showSymbolPicker = false
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var showsVersionConfirmation = false
    
    private let colorOptions = AppConstant.colorOptions
    
    private var startDateTitle: String {
        viewModel.startDate.toString(withFormat: .custom("MMM d, yyyy"))
    }
    
    private var endDateTitle: String {
        viewModel.hasEndDate
            ? viewModel.endDate.toString(withFormat: .custom("MMM d, yyyy"))
            : "habit.duration.noEnd".localized
    }
    
    init(
        viewModel: CreateHabitViewModel,
        onStartNewVersion: (() -> Void)? = nil,
        onHabitSaved: ((UUID) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onStartNewVersion = onStartNewVersion
        self.onHabitSaved = onHabitSaved
    }
    
    var body: some View {
        BaseScreen($viewModel.screenTitle) {
            AppScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.isCreatingVersion {
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
                    if viewModel.isCreatingVersion {
                        showsVersionConfirmation = true
                    } else {
                        saveHabit()
                    }
                } label: {
                    Text((viewModel.isCreatingVersion ? "common.create" : "common.save").localized)
                        .fontWeight(viewModel.canSave ? .bold : .regular)
                }
                .disabled(!viewModel.canSave)
            }
        }
        .animation(.snappy, value: viewModel.goalType)
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerSheetView(selectedSymbol: $viewModel.icon)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStartDatePicker) {
            CalendarPickerSheetView(
                title: "habit.duration.startDate".localized,
                initialDate: viewModel.startDate,
                minimumDate: viewModel.minimumStartDate
            ) { selectedDate in
                viewModel.startDate = selectedDate
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showEndDatePicker) {
            CalendarPickerSheetView(
                title: "habit.duration.endDate".localized,
                initialDate: viewModel.hasEndDate ? viewModel.endDate : max(viewModel.startDate, Date()),
                minimumDate: viewModel.startDate,
                clearTitle: viewModel.hasEndDate ? "habit.common.reset".localized : nil
            ) { selectedDate in
                viewModel.endDate = selectedDate
                viewModel.hasEndDate = true
            } onClear: {
                viewModel.hasEndDate = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .commonConfirmationDialog(
            isPresented: $showsVersionConfirmation,
            title: "habit.version.create.confirmation".localized(viewModel.targetVersionNumber),
            message: "habit.version.create.warning".localized(viewModel.targetVersionNumber),
            actions: [
                ConfirmationDialogAction("habit.version.create.action".localized(viewModel.targetVersionNumber)) {
                    saveHabit()
                },
                ConfirmationDialogAction("common.cancel".localized, role: .cancel) {}
            ]
        )
    }
    
    @ViewBuilder
    private var versionContextSection: some View {
        if viewModel.isCreatingVersion {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(module: "arrow.triangle.2.circlepath")
                        .customFont(.headline)
                        .frame(width: 36, height: 36)
                        .borderedBackground(cornerRadius: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("habit.version.number".localized(viewModel.targetVersionNumber))
                            .customFont(.headline)

                        Text("habit.version.continuesFromNumber".localized(viewModel.sourceVersionNumber ?? 1))
                            .customFont(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    versionContextRow(
                        title: "habit.version.previousRepeat".localized,
                        value: viewModel.sourceRepeatTitle
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
            
            TextField("habit.form.name".localized, text: $viewModel.name)
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
                    Image(module: viewModel.icon)
                        .resizable()
                        .padding()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundStyle(Color.init(hex: viewModel.colorHex))
                        .appGlassEffect(
                            .regular,
                            in: .rect(cornerRadius: 12)
                        )
                }
                
                TextField("habit.form.description".localized, text: $viewModel.habitDescription)
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
                selection: $viewModel.frequency,
                layout: .control
            ) {
                Text("habit.repeat.daily".localized).tag(HabitFrequency.daily)
                Text("habit.repeat.weekday".localized).tag(HabitFrequency.weekday)
                Text("habit.repeat.weekend".localized).tag(HabitFrequency.weekend)
                Text("habit.repeat.custom".localized).tag(HabitFrequency.custom)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.frequency) { _, newValue in
                viewModel.selectFrequency(newValue)
            }
            .onChange(of: viewModel.startDate) { _, newValue in
                if viewModel.hasEndDate &&
                    viewModel.normalizedEndDate < AppCalendar.current.startOfDay(for: newValue) {
                    viewModel.endDate = newValue
                }
            }
            .disabled(viewModel.locksGoalAndSchedule)
            
            HStack(spacing: 8) {
                ForEach(viewModel.orderedWeekdays, id: \.self) { weekday in
                    Button {
                        viewModel.toggleWeekday(weekday)
                    } label: {
                        let tintColor = viewModel.selectedDays.contains(weekday)
                        ? Color.cyan.opacity(0.38)
                        : Color.primary.opacity(0.06)
                        
                        Text(shortWeekdayName(for: weekday))
                            .customFont(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .foregroundStyle(viewModel.selectedDays.contains(weekday) ? .white : .primary)
                            .appGlassEffect(
                                .regular.tint(tintColor),
                                in: .rect(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.locksGoalAndSchedule)
                }
            }
            
            if viewModel.isEditing {
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
                    if !viewModel.hasEndDate {
                        viewModel.endDate = max(viewModel.startDate, Date())
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
                selection: $viewModel.goalType,
                layout: .control
            ) {
                Text("habit.goal.count".localized).tag(GoalType.count)
                Text("habit.goal.todo".localized).tag(GoalType.todo)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.goalType) { _, newValue in
                if newValue == .todo {
                    viewModel.goalCountText = "1"
                    viewModel.goalUnit = "habit.goal.times".localized
                }
            }
            .disabled(viewModel.locksGoalAndSchedule)
            
            if viewModel.goalType == .count {
                HStack(spacing: 12) {
                    TextField("habit.goal.target".localized, text: $viewModel.goalCountText)
                        .keyboardType(.numberPad)
                        .disabled(viewModel.goalType == .todo || viewModel.locksGoalAndSchedule)
                        .padding()
                        .appGlassEffect(
                            in: .rect(cornerRadius: 12)
                        )
                    
                    TextField("habit.goal.unit".localized, text: $viewModel.goalUnit)
                        .disabled(viewModel.locksGoalAndSchedule)
                        .padding()
                        .appGlassEffect(
                            in: .rect(cornerRadius: 12)
                        )
                }
                .transition(.opacity)
            }
            
            if viewModel.isEditing {
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

            if onStartNewVersion != nil {
                Button {
                    onStartNewVersion?()
                } label: {
                    HStack(spacing: 8) {
                        Image(module: "arrow.triangle.2.circlepath")
                            .customFont(.caption, weight: .semibold)

                        Text("habit.version.start".localized(viewModel.targetVersionNumber))
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

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("habit.style.title".localized)
                .customFont(.headline)
            
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(colorOptions, id: \.self) { hex in
                        Button {
                            viewModel.colorHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    Circle()
                                        .stroke(viewModel.colorHex == hex ? Color.primary : Color.clear, lineWidth: 2)
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
        let emptyItem = previewHabitItem(completedCount: 0)
        let halfItem = previewHabitItem(completedCount: viewModel.goalCount / 2)
        let doneItem = previewHabitItem(completedCount: viewModel.goalCount)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("habit.preview.title".localized)
                .customFont(.headline)
            
            Text("habit.status.untracked".localized)
                .customFont(.subheadline)
            HabitItemView(model: emptyItem)
            
            if viewModel.goalType == .count && viewModel.goalCount > 1 {
                Text("habit.status.inProgress".localized)
                    .customFont(.subheadline)
                HabitItemView(model: halfItem)
            }
            
            Text("common.done".localized)
                .customFont(.subheadline)
            HabitItemView(model: doneItem)
        }
    }

    private func previewHabitItem(completedCount: Int) -> HabitItemView.Model {
        let safeGoalCount = max(viewModel.goalCount, 1)
        let completionRatio = min(
            Double(completedCount) / Double(safeGoalCount),
            1
        )
        let item = HabitListItem(
            id: UUID(),
            name: viewModel.trimmedName,
            icon: viewModel.icon,
            colorHex: viewModel.colorHex,
            goalType: viewModel.goalType,
            goalCount: safeGoalCount,
            goalUnit: viewModel.trimmedGoalUnit,
            completedCount: completedCount,
            completionRatio: completionRatio,
            isSkipped: false,
            currentStreak: 0,
            longestStreak: 0,
            lastCompletedDate: nil,
            canEditEntry: true,
            canResetEntry: completedCount > 0,
            entryIsCompleted: completedCount >= safeGoalCount
        )

        return HabitItemView.Model(item: item)
    }
    
    private func saveHabit() {
        guard let habitID = viewModel.save() else { return }
        onHabitSaved?(habitID)
        dismiss()
    }
    
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("habit.reminder.title".localized)
                    .customFont(.headline)

                Spacer()

                Button {
                    viewModel.addReminder()
                } label: {
                    Image(module: "plus")
                        .fontWeight(.bold)
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("habit.reminder.add".localized)
            }

            if viewModel.reminders.isEmpty {
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
                    ForEach($viewModel.reminders) { $reminder in
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
                viewModel.deleteReminder(id: reminder.wrappedValue.id)
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
                    ForEach(AppConstant.habitSymbolOptions, id: \.self) { symbol in
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
