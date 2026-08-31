//
//  WeekView.swift
//  Letter
//
//  Created by TiniT on 29/4/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct WeekView: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    @State private var centerDate = Date()
    @State private var weekPage = 0
    
    private func weekDates(for page: Int) -> [Date] {
        let calendar = habitViewModel.calendar
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
    
    private func moveWeek(by value: Int) {
        let calendar = habitViewModel.calendar
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
            habitViewModel.changeSelectedDate(date)
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
    
    private func weekRow(for page: Int) -> some View {
        let dates = weekDates(for: page)
        let summaries = habitViewModel.weekDaySummaries(for: dates)
        
        return HStack {
            ForEach(Array(summaries.enumerated()), id: \.element.date) { index, summary in
                WeekItem(summary: summary) { date in
                        habitViewModel.changeSelectedDate(date)
                }
                
                if index < summaries.count - 1 {
                    Spacer()
                }
            }
        }
        .padding()
    }
    
    public var body: some View {
        let weekStartsOnMonday = habitViewModel.weekStartsOnMonday
        
        weekRow(for: 0)
            .hidden()
            .accessibilityHidden(true)
            .overlay {
                TabView(selection: $weekPage) {
                    ForEach(-1...1, id: \.self) { page in
                        weekRow(for: page)
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
                moveWeek(by: newValue)
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

