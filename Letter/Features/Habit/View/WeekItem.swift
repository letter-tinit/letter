//
//  WeekItem.swift
//  Letter
//
//  Created by Tín Nguyễn on 21/8/26.
//

import SwiftUI

struct WeekItem: View {
    // MARK: - Enum
    enum DateState {
        case selected
        case unselected
        case unselectedComplete
        case unselectedToday
        
        init(isSelected: Bool, isToday: Bool, isComplete: Bool) {
            switch (isSelected, isToday, isComplete) {
                
            case (true, _, true), (true, _, false):
                self = .selected
            case (false, true, true), (false, true, false):
                self = .unselectedToday
            case (false, false, true):
                self = .unselectedComplete
            case (false, false, false):
                self = .unselected
            }
        }
        
        var color: Color {
            switch self {
            case .selected:
                return .cyan
            case .unselected:
                return .primary.opacity(0.58)
            case .unselectedComplete:
                return .green.opacity(0.7)
            case .unselectedToday:
                return .primary
            }
        }
    }
    
    let summary: WeekDaySummary
    let action: (Date) -> Void
    
    var body: some View {
        let dateState = DateState(
            isSelected: summary.isSelected,
            isToday: summary.isToday,
            isComplete: summary.isComplete
        )
        let tintColor: Color = dateState.color
        let fontWeight: Font.Weight = summary.isSelected ? .bold : .regular
        
        Button {
            baseAnimation {
                Haptic.selection()
                action(summary.date)
            }
        } label: {
            VStack(spacing: 10) {
                Text(summary.date.toString(withFormat: .dayName(length: 2)))
                    .customFont(.caption, weight: fontWeight)
                
                CircularWithTitleProgressView(
                    progress: summary.completionRatio,
                    title: summary.date.toString(withFormat: .dayNo),
                    tintColor: tintColor,
                    fontWeight: fontWeight
                )
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 14)
            .foregroundStyle(tintColor)
            .appGlassEffect(
                .regular.interactive(),
                in: Capsule()
            )
            .shadow(
                color: summary.isSelected ? .primary.opacity(0.35) : .clear,
                radius: 2,
            )
            .scaleEffect(summary.isSelected ? 1.1 : 1)
        }
    }
}
