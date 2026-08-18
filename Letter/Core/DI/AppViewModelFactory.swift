//
//  BalanceViewModelFactory.swift
//  Personal Finance
//
//  Created by TiniT on 20/7/26.
//

protocol AppViewModelFactory {
    func makeBudgetViewModel() -> BudgetViewModel
    func makeBudgetDetailViewModel(budget: Budget) -> BudgetDetailViewModel
    func makeBalanceViewModel() -> BalanceViewModel
    func makeNetWorthViewModel() -> NetWorthViewModel
    func makeProfileBackupViewModel() -> ProfileBackupViewModel
}
