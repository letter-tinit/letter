//
//  WeekView.swift
//  Letter
//
//  Created by TiniT on 29/4/26.
//

import SwiftUI

struct WeekView: View {
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
                WeekItem(summary: summary) { date in
                    habitViewModel.didChangeSelecteDate(date)
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
            .appGlassEffect(
                .regular,
                in: .rect(cornerRadius: 28)
            )
    }
}

#Preview {
    WeekView()
}
