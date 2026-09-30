//
//  HabitItemView.swift
//  Letter
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct HabitItemView: View {
    // MARK: - Input Param
    @Binding private var model: Model
    
    // MARK: - UI State
    private let cornerRadius: CGFloat = 12.0
    @State private var isShowNumberPad: Bool = false
    @State private var numberPadModel = NumberPadSheetModel()
    
    private var statusText: String {
        if model.isSkipped {
            return "habit.status.skipped".localized
        }
        
        if model.goalType == .count {
            return "\(model.completedCount)/\(model.goalCount) \(model.goalUnit)"
        }
        
        return "\(model.completedCount)/\(model.goalCount)"
    }
    
    public init(
        model: Binding<Model>
    ) {
        _model = model
    }
    
    public var body: some View {
        ZStack {
            // MARK: - PROGRESS LAYER
            model.progressGradient
                .opacity(0.6)
                .clipShape(
                    .rect(
                        topLeadingRadius: cornerRadius,
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )
                .scaleEffect(x: model.completionRatio, y: 1, anchor: .leading)
                .animation(.easeInOut(duration: 0.2), value: model.completionRatio)
            
            // MARK: - HABIT INFOR
            HStack(alignment: .center) {
                Image(module: model.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .padding(8)
                    .appGlassEffect(
                        .regular.interactive().tint(model.color.opacity(0.3)),
                        in: .rect(cornerRadius: 4)
                    )
                    .foregroundStyle(model.color)
                    .shadow(color: .primary.opacity(0.1), radius: 1)
                
                VStack(alignment: .leading) {
                    Text(model.name)
                        .customFont(.headline, weight: .semibold)
                        .foregroundStyle(.primary)
                    
                    Text(statusText)
                        .accessibilityIdentifier("habit.status.\(model.name)")
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.primary.opacity(0.06))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.primary.opacity(0.20), lineWidth: 0.4)
                                }
                        )
                        .foregroundStyle(statusColor)
                        .customFont(.caption2)
                        .fontWeight(.regular)
                }
                
                Spacer()
            }
            .padding()
        }
        // MARK: - TRAILING BUTTON
        .overlay(alignment: .trailing) {
            trailingAccessory
        }
        // MARK: - ITEM STYLE
        .opacity(model.canEditEntry ? 1 : 0.72)
        .borderedBackground(cornerRadius: cornerRadius)
        .mask {
            RoundedRectangle(cornerRadius: cornerRadius)
        }
        .opacity(model.isSkipped ? 0.2 : 1)
        // MARK: - Action
        .sheet(isPresented: $isShowNumberPad) {
            ZStack {
                Color.primary.opacity(0.02).ignoresSafeArea()
                
                NumberPadSheet(model: $numberPadModel)
                    .overlay(alignment: .topLeading) {
                        completeGoalButton
                    }
            }
            .presentationBackground(.ultraThinMaterial)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .onChange(of: numberPadModel.submittedValue) { _, submittedValue in
            submitProgress(submittedValue)
        }
        .onTapGesture {
            Haptic.selection()
            model.isSelected = true
        }
    }
    
    @ViewBuilder
    private var trailingAccessory: some View {
        switch model.state {
        case .skip:
            skippedAccessory
        case .completed:
            completedAccessory
        case .absoluteCompleted:
            absoluteCompletedAccessory
        case .default:
            defaultAccessory
        }
    }
    
    private var statusColor: Color {
        switch model.state {
        case .skip:
                .cyan
        case .completed, .absoluteCompleted:
                .green
        case .default:
                .secondary
        }
    }
    
    private var skippedAccessory: some View {
        VStack(spacing: 3) {
            Image(module: "airplane")
                .customFont(.title3)
                .foregroundStyle(.cyan)
            
            Text("habit.status.skipped".localized)
                .customFont(.caption2)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
    }
    
    private var completedAccessory: some View {
        VStack {
            HStack(spacing: 2) {
                Text("habit.streak.days".localized(model.currentStreak))
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
        .padding(.horizontal, 10)
    }
    
    private var absoluteCompletedAccessory: some View {
        Image(module: "trophy.fill")
            .customFont(.title3)
            .foregroundStyle(Gradient.Glass.golden)
            .padding(.horizontal, 10)
            .shadow(radius: 1)
    }
    
    private var defaultAccessory: some View {
        Button {
            Haptic.impact()
            guard model.canEditEntry else {
                return
            }
            
            if model.goalType == .todo {
                submitProgress(1)
            } else {
                numberPadModel = NumberPadSheetModel(unit: model.goalUnit.isEmpty ? nil : model.goalUnit)
                isShowNumberPad = true
            }
        } label: {
            Image(module: model.goalType == .todo ? "checkmark" : "plus")
                .fontWeight(.bold)
                .padding(10)
                .appGlassEffect(
                    .regular.interactive().tint(Color.primary.opacity(0.08)),
                    in: .circle
                )
                .frame(width: 72)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!model.canEditEntry)
        .accessibilityIdentifier("habit.progress.\(model.name)")
        .accessibilityLabel("habit.completeGoal".localized)
    }
    
    private func submitProgress(_ submittedValue: Int?) {
        guard let submittedValue else { return }
        numberPadModel = NumberPadSheetModel()
        model.submittedCompletedCount = model.completedCount + submittedValue
    }
    
    private var completeGoalButton: some View {
        Button {
            guard model.canEditEntry else { return }
            numberPadModel.submittedValue = max(model.goalCount - model.completedCount, 0)
            isShowNumberPad = false
        } label: {
            Image(systemName: "checkmark")
                .customFont(.headline, weight: .semibold)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .tint(.green)
        .disabled(!model.canEditEntry)
        .accessibilityLabel("habit.completeGoal".localized)
        .accessibilityIdentifier("habit.entry.completeGoal")
        .padding(.horizontal, 20)
    }
}

// MARK: Model
public extension HabitItemView {
    enum State {
        case skip
        case completed
        case absoluteCompleted
        case `default`
    }
    
    struct Model: Identifiable {
        public let id: UUID
        let name: String
        let icon: String
        let color: Color
        let gradient: LinearGradient
        let isCompletionDate: Bool
        let goalType: GoalType
        let goalCount: Int
        let goalUnit: String
        let completedCount: Int
        let completionRatio: Double
        let isSkipped: Bool
        let currentStreak: Int
        let longestStreak: Int
        let lastCompleteStreak: Date?
        let canEditEntry: Bool
        let canResetEntry: Bool
        let entryIsCompleted: Bool
        var isSelected: Bool
        var submittedCompletedCount: Int?
        
        var state: State {
            if isSkipped {
                return .skip
            }
            
            if isCompletionDate {
                return .absoluteCompleted
            }
            
            if completionRatio >= 1 {
                return .completed
            }
            
            return .default
        }
        
        var progressGradient: LinearGradient {
            guard isCompletionDate else {
                return gradient
            }
            
            return LinearGradient(
                gradient: .Glass.golden,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        init(item: HabitListItem) {
            let resolvedColor = Color(hex: item.colorHex)
            
            id = item.id
            name = item.name
            icon = item.icon
            color = resolvedColor
            gradient = LinearGradient(
                colors: GradientProvider.gradient(for: item.colorHex),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            isCompletionDate = item.isCompletionDate
            goalType = item.goalType
            goalCount = item.goalCount
            goalUnit = item.goalUnit
            completedCount = item.completedCount
            completionRatio = item.completionRatio
            isSkipped = item.isSkipped
            currentStreak = item.currentStreak
            longestStreak = item.longestStreak
            lastCompleteStreak = item.lastCompletedDate
            canEditEntry = item.canEditEntry
            canResetEntry = item.canResetEntry
            entryIsCompleted = item.entryIsCompleted
            isSelected = false
            submittedCompletedCount = nil
        }
    }
}
