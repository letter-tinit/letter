//
//  BudgetCreationForm.swift
//  Presentation
//
//  Created by Tín Nguyễn on 16/10/26.
//


import SwiftUI
import Styleguide

public struct BudgetInputForm: View {
    @Environment(BudgetViewModel.self) private var viewModel
    
    public var body: some View {
        @Bindable var form = viewModel.budgetInputFormState
        
        AppScrollView {
            VStack {
                StandaloneSection(rows: "budget.creation.income".localized) {
                    AmountField(
                        "transaction.form.amount".localized,
                        text: $form.incomeAmount
                    )
                }
                
                StandaloneSection(rows: "budget.creation.pyf".localized) {
                    AmountField(
                        "transaction.form.amount".localized,
                        text: $form.pyfAmount
                    )
                }
                
                Label(
                    String(
                        format: "budget.creation.remaing".localized,
                        form.spendingAmountString
                    ),
                    systemImage: "wallet.bifold"
                )
                .padding(.top)
                .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            form.reset()
        }
        .keyboardButtons()
        .toast(message: viewModel.toastMessage)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("common.save".localized) {
                    viewModel.didTapSubmitBudgetCreationForm()
                }
            }
        }
    }
}
