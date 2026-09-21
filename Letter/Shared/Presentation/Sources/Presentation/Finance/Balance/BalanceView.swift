//
//  BalanceView.swift
//  Letter
//
//  Created by TiniT on 16/7/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct BalanceView: View {
    @State private var viewModel: BalanceViewModel
    private let selectedMonth: FinanceMonth
    @State private var isDeleteConfirmationPresented = false
    
    public init(_ viewModel: BalanceViewModel, selectedMonth: FinanceMonth) {
        self.viewModel = viewModel
        self.selectedMonth = selectedMonth
        
    }
    
    public var body: some View {
        @Bindable var balance = viewModel.balance

        BaseScreen {
            VStack {
                // MARK: - BALANCE VIEW
                if balance.transactionRows.isEmpty {
                    CommonEmptyView()
                } else {
                    BalanceCardView(balance: balance)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // MARK: - TRANSACTIONS
                    BalanceListView(
                        balance: balance
                    )
                }
            }
        }
        .environment(viewModel)
        .navigationBarTitleDisplayMode(.automatic)
        .toolbar {
            if !balance.transactions.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptic.warning()
                        viewModel.toggleSelectedMonthEditingLock()
                    } label: {
                        Image(systemName: balance.isEditingUnlocked ? "lock.open" : "lock")
                    }
                    .accessibilityLabel(balance.isEditingUnlocked ? "networth.edit.lock".localized : "networth.edit.unlock".localized)
                }
                
                if balance.isEditingUnlocked {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) {
                            Haptic.warning()
                            isDeleteConfirmationPresented = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptic.selection()
                    viewModel.isCreateNewBalancePresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!balance.isEditingUnlocked)
            }
        }
        .sheet(isPresented: $viewModel.isCreateNewBalancePresented) {
            NavigationStack {
                BalanceFormView()
                    .environment(viewModel)
            }
        }
        .toast(message: viewModel.toastMessage)
        .deleteConfirmationDialog(
            isPresented: $isDeleteConfirmationPresented,
            title: "common.delete".localized,
            message: "common.delete.warning".localized
        ) {
            viewModel.deleteSelectedMonthTransactions()
        }
        .onAppear {
            viewModel.selectMonth(selectedMonth)
        }
    }
}
