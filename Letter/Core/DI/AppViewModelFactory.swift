//
//  BalanceViewModelFactory.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

protocol AppViewModelFactory {
    func makeBudgetViewModel() -> BudgetViewModel
    func makeBudgetDetailViewModel(budget: Budget) -> BudgetDetailViewModel
    func makeBalanceViewModel() -> BalanceViewModel
    func makeNetWorthViewModel() -> NetWorthViewModel
    func makeAppBackupViewModel() -> AppBackupViewModel
    func makeHabitViewModel() -> HabitViewModel
    func makeHabitStatisticsViewModel() -> HabitStatisticsViewModel
}
