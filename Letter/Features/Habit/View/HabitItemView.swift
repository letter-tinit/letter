//
//  HabitItemView.swift
//  Letter
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI

struct HabitItemView: View {
    // MARK: - Input Param
    private let model: Model
    
    // MARK: - UI State
    private let cornerRadius: CGFloat = 12.0
    @State private var showNumberPad = false
    
    private var isCompleted: Bool {
        model.completionRatio >= 1
    }
    
    private var statusText: String {
        if model.isSkipped {
            return "habit.status.skipped".localized
        }
        
        if model.goalType == .count {
            return "\(model.completedCount)/\(model.goalCount) \(model.goalUnit)"
        }
        
        return "\(model.completedCount)/\(model.goalCount)"
    }
    
    // MARK: - Callback
    var handleAction: ((Action) -> Void) = { _ in }
    
    init(
        model: Model,
        handleAction: @escaping (Action) -> Void = { _ in }
    ) {
        self.model = model
        self.handleAction = handleAction
    }
    
    var body: some View {
        ZStack {
            // MARK: - PROGRESS LAYER
            model.gradient
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
            
            // MARK: - HABIT INFOR
            HStack(alignment: .center) {
                Image(module: model.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)
                    .padding(8)
                    .appGlassEffect(
                        .regular.tint(model.color.opacity(0.3)),
                        in: .rect(cornerRadius: 4)
                    )
                    .foregroundStyle(model.color)
                    .shadow(color: .primary.opacity(0.2), radius: 1)
                
                VStack(alignment: .leading) {
                    Text(model.name)
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
                        .foregroundStyle(model.isSkipped ? Color.cyan : isCompleted ? Color.green : Color.secondary)
                        .customFont(.caption2)
                        .fontWeight(.regular)
                }
                
                Spacer()
            }
            .padding()
        }
        // MARK: - PLUS BUTTON
        .overlay(alignment: .trailing) {
            Group {
                if model.isSkipped {
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
                } else {
                    Button {
                        guard model.canEditEntry else {
                            Haptic.warning()
                            return
                        }
                        
                        baseAnimation {
                            Haptic.impact(.heavy)
                            if model.goalType == .todo {
                                handleAction(.progressChanged(1))
                            } else {
                                showNumberPad = true
                            }
                        }
                    } label: {
                        Image(module: model.goalType == .todo ? "checkmark" : "plus")
                            .fontWeight(.bold)
                    }
                    .padding(8)
                    .buttonStyle(.plain)
                    .disabled(!model.canEditEntry)
                    .background(Color.primary.opacity(0.08), in: Circle())
                }
            }
            .padding(.horizontal, 10)
        }
        // MARK: - ITEM STYLE
        .opacity(model.canEditEntry ? 1 : 0.72)
        .appGlassEffect(
            .regular,
            in: .rect(cornerRadius: cornerRadius)
        )
        .mask {
            RoundedRectangle(cornerRadius: cornerRadius)
        }
        // MARK: - Action
        .sheet(isPresented: $showNumberPad) {
            ZStack {
                Color.primary.opacity(0.02).ignoresSafeArea()
                
                NumberPadSheet(
                    habitName: model.name,
                    unit: model.goalUnit,
                    current: model.completedCount,
                    goal: model.goalCount
                ) { value in
                    baseAnimation {
                        let newCount = model.completedCount + value
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
        .opacity(model.isSkipped ? 0.4 : 1)
    }
}

// MARK: Model
extension HabitItemView {
    enum Action {
        case tapped
        case progressChanged(Int)
    }
    
    struct Model: Identifiable {
        let id: UUID
        let name: String
        let icon: String
        let color: Color
        let gradient: LinearGradient
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
        }
    }
}
