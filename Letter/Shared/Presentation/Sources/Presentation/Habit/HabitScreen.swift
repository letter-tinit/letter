//
//  HabitScreen.swift
//  Letter
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI
import Utility
import Styleguide

public struct HabitScreen: View {
    @AppStorage(AppLanguage.preferenceKey)
    private var languageCode = AppLanguage.vietnamese.rawValue
    @Environment(HabitRouter.self) private var router
    @Environment(HabitViewModel.self) private var habitViewModel
    
    public var body: some View {
        @Bindable var habitViewModel = habitViewModel

        BaseScreen($habitViewModel.title) {
            VStack(spacing: 0) {
                WeekView()
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                if habitViewModel.filteredHabits.isEmpty {
                    CommonEmptyView(
                        "habit.empty.title".localized,
                        systemImage: "figure.run.square.stack",
                        description: "habit.empty.description".localized
                    )
                } else {
                    AppList {
                        ForEach($habitViewModel.filteredHabits) { $row in
                            HabitListRow(item: $row)
                            .id(HabitListRow.ID(
                                habitID: row.id,
                                completed: row.entryIsCompleted,
                                skipped: row.isSkipped
                            ))
                        }
                    }
                    .listRowSpacing(20)
                    .contentMargins(.vertical, 20)
                    .scrollIndicators(.hidden)
                    .animation(.easeInOut(duration: 0.22), value: habitViewModel.filteredHabits.map(\.id))
                }
            }
        } didTapOnTitle: {
            Haptic.selection()
            habitViewModel.backToday()
        }
        // MARK: - BaseScreen Configure
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptic.impact(.medium)
                    router.push(.createHabit)
                } label: {
                    Image(module: "plus")
                        .fontWeight(.bold)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .onChange(of: languageCode) { _, _ in
            habitViewModel.refreshLocalizedText()
        }
    }
}
