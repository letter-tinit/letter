//
//  BalanceViewModelFactory.swift
//  Letter
//  Created by TiniT on 20/7/26.
//

import Foundation
import Domain

public protocol AppViewModelFactory {
    func makeBudgetViewModel() -> BudgetViewModel
    func makeBalanceViewModel() -> BalanceViewModel
    func makeNetWorthViewModel() -> NetWorthViewModel
    func makeHabitViewModel() -> HabitViewModel
    func makeProfileViewModel() -> ProfileViewModel
    func makeCreateHabitViewModel(mode: HabitFormMode) -> CreateHabitViewModel
    func makeHabitDetailViewModel(habitID: UUID) -> HabitDetailViewModel
    func makeHabitStatisticsViewModel() -> HabitStatisticsViewModel
    func makeFinanceLockManager() -> FinanceLockManager
    func makeAudioBookViewModel() -> AudioBookViewModel
    func makeAudioBookPlayerViewModel() -> AudioBookPlayerViewModel
    func makeAudioBookDetailViewModel() -> AudioBookDetailViewModel
}
