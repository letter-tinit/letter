//
//  WeekView.swift
//  Letter
//
//  Created by TiniT on 29/4/26.
//

import SwiftUI

struct WeekView: View {
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

    
    @Environment(HabitViewModel.self) private var habitViewModel
    @State private var centerDate = Date()
    @State private var weekPage = 0

    private func calendar(weekStartsOnMonday: Bool) -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartsOnMonday ? 2 : 1
        return calendar
    }

    private func weekDates(for page: Int, weekStartsOnMonday: Bool) -> [Date] {
        let calendar = calendar(weekStartsOnMonday: weekStartsOnMonday)
        guard
            let pageDate = calendar.date(byAdding: .weekOfYear, value: page, to: centerDate),
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: pageDate)
        else {
            return []
        }

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekInterval.start)
        }
    }

    private func moveWeek(by value: Int, weekStartsOnMonday: Bool) {
        let calendar = calendar(weekStartsOnMonday: weekStartsOnMonday)
        guard let date = calendar.date(byAdding: .weekOfYear, value: value, to: centerDate) else {
            return
        }

        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            centerDate = date
            weekPage = 0
        }

        baseAnimation {
            habitViewModel.didChangeSelecteDate(date)
        }
    }

    private func syncCenterDateIfNeeded(with date: Date) {
        guard
            weekPage == 0,
            !centerDate.isEqual(with: date)
        else {
            return
        }

        centerDate = date
    }
    
    private func weekRow(for page: Int, weekStartsOnMonday: Bool) -> some View {
        let dates = weekDates(for: page, weekStartsOnMonday: weekStartsOnMonday)
        let summaries = habitViewModel.weekDaySummaries(for: dates)

        return HStack {
            ForEach(Array(summaries.enumerated()), id: \.element.date) { index, summary in
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
                        habitViewModel.didChangeSelecteDate(summary.date)
                    }
                } label: {
                    VStack(spacing: 10) {
                        Text(summary.date.toString(withFormat: .dayName))
                            .font(.caption)
                            .fontDesign(.rounded)
                            .fontWeight(fontWeight)

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
                    .overlay {
                        Capsule()
                            .stroke(
                                tintColor.opacity(dateState == .unselected ? 0.45 : 0.9),
                                lineWidth: dateState == .unselected ? 0.8 : 1.4
                            )
                    }
                    .shadow(
                        color: summary.isSelected ? Color.rosePink.opacity(0.65) : .clear,
                        radius: 4,
                        y: 4
                    )
                    .scaleEffect(summary.isSelected ? 1.1 : 1)
                }
                
                if index < summaries.count - 1 {
                    Spacer()
                }
            }
        }
        .padding()
    }

    var body: some View {
        let weekStartsOnMonday = habitViewModel.weekStartsOnMonday
        
        weekRow(for: 0, weekStartsOnMonday: weekStartsOnMonday)
            .hidden()
            .accessibilityHidden(true)
            .overlay {
                TabView(selection: $weekPage) {
                    ForEach(-1...1, id: \.self) { page in
                        weekRow(for: page, weekStartsOnMonday: weekStartsOnMonday)
                            .tag(page)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        .onAppear {
            centerDate = habitViewModel.selectedDate
        }
        .onChange(of: weekPage) { _, newValue in
            guard newValue != 0 else { return }
            Haptic.selection()
            moveWeek(by: newValue, weekStartsOnMonday: weekStartsOnMonday)
        }
        .onChange(of: habitViewModel.selectedDate) { _, newValue in
            syncCenterDateIfNeeded(with: newValue)
        }
        .onChange(of: weekStartsOnMonday) {
            centerDate = habitViewModel.selectedDate
            weekPage = 0
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .borderedBackground(cornerRadius: 28)
    }
}

#Preview {
    WeekView()
}
