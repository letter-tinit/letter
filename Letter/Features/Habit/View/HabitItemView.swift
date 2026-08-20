//
//  HabitItemView.swift
//  Letter
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI

struct HabitItemView: View {
    enum Action {
        case tapped
        case progressChanged(Int)
    }

    // MARK: - Input Param
    private let name: String
    private let icon: String
    private let colorHex: String
    private let gradient: LinearGradient
    private let goalType: GoalType
    private let goalCount: Int
    private let goalUnit: String
    private let completedCount: Int
    private let completionRatio: Double
    private let isSkipped: Bool
    private let currentStreak: Int
    private let longestStreak: Int
    private let lastCompleteStreak: Date?
    private let canEditEntry: Bool

    // MARK: - UI State
    private let cornerRadius: CGFloat = 12.0
    @State private var showNumberPad = false

    private var isCompleted: Bool {
        completionRatio >= 1
    }

    private var statusText: String {
        if isSkipped {
            return "habit.status.skipped".localized
        }

        if goalType == .count {
            return "\(completedCount)/\(goalCount) \(goalUnit)"
        }

        return "\(completedCount)/\(goalCount)"
    }

    // MARK: - Callback
    var handleAction: ((Action) -> Void) = { _ in }

    init(
        habit: Habit,
        selectedDate: Date,
        handleAction: @escaping (Action) -> Void = { _ in }
    ) {
        let entry = habit.entry(for: selectedDate)
        self.name = habit.name
        self.icon = habit.icon
        self.colorHex = habit.colorHex
        self.gradient = habit.gradient
        self.goalType = habit.goalType
        self.goalCount = habit.goalCount
        self.goalUnit = habit.goalUnit
        self.completedCount = entry?.completedCount ?? 0
        self.completionRatio = entry?.completionRatio ?? 0
        self.isSkipped = entry?.isSkipped ?? false
        self.handleAction = handleAction
        self.currentStreak = habit.currentStreak
        self.longestStreak = habit.longestStreak
        self.lastCompleteStreak = habit.lastCompletedDate
        self.canEditEntry = !selectedDate.isFutureDay()
    }

    var body: some View {
        ZStack {
            // MARK: - PROGRESS LAYER
            gradient
                .opacity(0.6)
                .clipShape(
                    .rect(
                        topLeadingRadius: cornerRadius,
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )
                .scaleEffect(x: completionRatio, y: 1, anchor: .leading)
            
            // MARK: - HABIT INFOR
            HStack(alignment: .center) {
                Image(module: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)
                    .shadow(color: .black.opacity(0.1), radius: 1)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .foregroundStyle(.primary.opacity(0.1))
                    )
                    .foregroundStyle(Color.init(hex: colorHex))
                
                VStack(alignment: .leading) {
                    Text(name)
                        .customFont(.headline, weight: .semibold)
                        .foregroundStyle(.primary)
                    
                    Text(statusText)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.primary.opacity(0.06))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.primary.opacity(0.20), lineWidth: 0.4)
                                }
                        )
                        .foregroundStyle(isSkipped ? Color.cyan : isCompleted ? Color.green : Color.secondary)
                        .customFont(.caption2)
                        .fontWeight(.regular)
                }
                
                Spacer()
            }
            .padding()
            .shadow(color: .black.opacity(0.1), radius: 3)
        }
        // MARK: - PLUS BUTTON
        .overlay(alignment: .trailing) {
            Group {
                if isSkipped {
                    VStack(spacing: 3) {
                        Image(module: "airplane")
                            .customFont(.title3)
                            .foregroundStyle(.cyan)

                        Text("habit.status.skipped".localized)
                            .customFont(.caption2)
                            .foregroundStyle(.primary)
                    }
                } else if isCompleted {
                    VStack {
                        HStack(spacing: 2) {
                            Text("habit.streak.days".localized(currentStreak))
                                .fontWeight(.regular)
                                .foregroundStyle(.primary)
                            
                            Image(module: "flame.fill")
                                .foregroundStyle(.orange)
                        }
                        .customFont(.caption2)
                        
                        Image(module: "checkmark.seal.fill")
                            .customFont(.title3)
                            .foregroundStyle(.green)
                    }
                } else {
                    Button {
                        guard canEditEntry else {
                            Haptic.warning()
                            return
                        }

                        baseAnimation {
                            Haptic.impact(.heavy)
                            if goalType == .todo {
                                handleAction(.progressChanged(1))
                            } else {
                                showNumberPad = true
                            }
                        }
                    } label: {
                        Image(module: goalType == .todo ? "checkmark" : "plus")
                            .fontWeight(.bold)
                    }
                    .padding(8)
                    .buttonStyle(.plain)
                    .disabled(!canEditEntry)
                    .background(Color.primary.opacity(0.08), in: Circle())
                }
            }
            .padding(.horizontal, 10)
            .shadow(color: .black.opacity(0.3), radius: 1)
        }
        // MARK: - ITEM STYLE
        .opacity(canEditEntry ? 1 : 0.72)
        .mask {
            RoundedRectangle(cornerRadius: cornerRadius)
        }
        .borderedBackground(cornerRadius: cornerRadius)
        // MARK: - Action
        .sheet(isPresented: $showNumberPad) {
            ZStack {
                Color.primary.opacity(0.02).ignoresSafeArea()

                NumberPadSheetView(
                    habitName: name,
                    unit: goalUnit,
                    current: completedCount,
                    goal: goalCount
                ) { value in
                    baseAnimation {
                        let newCount = completedCount + value
                        Haptic.impact()
                        handleAction(.progressChanged(newCount))
                    }
                }
            }
            .presentationBackground(.ultraThinMaterial)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .onTapGesture {
            Haptic.selection()
            handleAction(.tapped)
        }
        .opacity(isSkipped ? 0.4 : 1)
    }
}

// MARK: - NumberPadSheetView
struct NumberPadSheetView: View {
    let habitName: String
    let unit: String
    let current: Int
    let goal: Int
    let onConfirm: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var input: String = ""

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["C", "0", "⌫"]
    ]

    private var parsedValue: Int { Int(input) ?? 0 }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            // Display
            Text(input.isEmpty ? "0" : input)
                .customFont(size: 48, weight: .semibold)
                .contentTransition(.numericText())
                .animation(.snappy, value: input)

            // Number Pad Grid
            VStack(spacing: 10) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(row, id: \.self) { key in
                            NumberPadKeyView(label: key) {
                                handleKey(key)
                            }
                        }
                    }
                }
            }

            // Confirm Button
            Button {
                let value = parsedValue
                if value > 0 {
                    onConfirm(value)
                }
                dismiss()
            } label: {
                Text("common.done".localized)
                    .customFont(.headline, weight: .semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.primary)
                    .borderedBackground(cornerRadius: 14)
                    .animation(.snappy, value: parsedValue)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .overlay(alignment: .topTrailing) {
            Text(unit)
                .customFont(.caption)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(lineWidth: 0.5)
                )
                .padding(.trailing, 30)
        }
    }

    private func handleKey(_ key: String) {
        switch key {
        case "C":
            input = ""
        case "⌫":
            if !input.isEmpty { input.removeLast() }
        default:
            // Prevent leading zeros and cap at 4 digits
            if input == "0" { input = "" }
            if input.count < 4 { input += key }
        }
    }
}

// MARK: - NumberPadKeyView

struct NumberPadKeyView: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .customFont(.title2, weight: .medium)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .borderedBackground(cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
}
