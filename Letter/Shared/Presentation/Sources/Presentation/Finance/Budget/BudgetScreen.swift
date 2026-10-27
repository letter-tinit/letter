//
//  BudgetScreen.swift
//  Presentation
//
//  Created by Tín Nguyễn on 15/10/26.
//

import SwiftUI
import Styleguide
import Domain

struct BudgetScreen: View {
    @State private var viewModel: BudgetViewModel
    public let selectedMonth: FinanceMonth
    
    init(_ viewModel: BudgetViewModel, selectedMonth: FinanceMonth) {
        self.viewModel = viewModel
        self.selectedMonth = selectedMonth
    }
    
    var body: some View {
        BaseScreen {
            if let budget = viewModel.budget {
                VStack(spacing: 0) {
                    BudgetCardView(amount: budget.remainingAmount.formattedVND)
                        .padding(.top)
                        .padding(.horizontal)
                    
                    if budget.noTransaction && !budget.isLocked {
                        CommonEmptyView {
                            Button {
                                viewModel.didTapCreateNewTransaction()
                            } label: {
                                LiquidGlassPlusView()
                            }
                        }
                    } else {
                        BudgetTransactionListView(transactions: budget.transactions, isLocked: budget.isLocked)
                    }
                    
                    Spacer()
                }
            } else {
                CommonEmptyView(
                    "budget.empty".localized,
                    systemImage: "wallet.bifold"
                )
            }
        }
        // MARK: - TOOLBAR
        .toolbar {
            if let budget = viewModel.budget {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptic.selection()
                        viewModel.didTapLockButton()
                    } label: {
                        Image(systemName: budget.isLocked ? "lock" : "lock.open")
                    }
                    .accessibilityLabel(
                        budget.isLocked
                        ? "networth.edit.lock".localized
                        : "networth.edit.unlock".localized
                    )
                }
                
                if !budget.isLocked {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            viewModel.didTapDeleteBudgetButton()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(Color.Common.failure)
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.didTapCreateNewBudget()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        // MARK: - SHEET
        .sheet(isPresented: $viewModel.transactionInputFormPresenting) {
            NavigationStack {
                BudgetTransactionInputForm()
            }
        }
        .sheet(isPresented: $viewModel.budgetInputFormPresenting) {
            NavigationStack {
                BudgetInputForm()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .deleteConfirmationDialog(isPresented: $viewModel.budgetDeleteConfirmation) {
            viewModel.didConfirmDeleteBudget()
        }
        // MARK: - LIFE CYCLE
        .onAppear {
            viewModel.selectedMonth(selectedMonth)
            viewModel.load()
        }
        // MARK: - ENVIRONMENT
        .environment(viewModel)
    }
}
