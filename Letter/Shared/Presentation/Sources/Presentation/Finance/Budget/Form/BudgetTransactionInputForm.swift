//
//  BudgetTransactionInputForm.swift
//  Presentation
//
//  Created by Tín Nguyễn on 22/10/26.
//

import SwiftUI
import Domain
import Styleguide

struct BudgetTransactionInputForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetViewModel.self) private var viewModel
    
    @State private var isManualEdit: Bool = false
    
    var body: some View {
        @Bindable var formState = viewModel.budgetTransactionInputFormState
        AppScrollView {
            VStack {
                StandaloneSection(rows: "budget.transaction.creation.info".localized) {
                    AmountField(
                        "transaction.form.amount".localized,
                        text: $formState.amount
                    )
                    
                    DatePicker(
                        "transaction.form.date".localized,
                        selection: $formState.date,
                        displayedComponents: .date
                    )
                    
                    AppPicker(
                        "transaction.form.allocation".localized,
                        selection: $formState.category,
                        layout: .labeledRow
                    ) {
                        ForEach(BudgetTransactionCategory.allCases) { category in
                            Label(
                                category.localizedTitle.localized,
                                systemImage: ""
                            )
                            .tag(category.id)
                        }
                    }
                }
                
                StandaloneSection(rows: "budget.transaction.creation.description".localized) {
                    AppTextField("", text: $formState.description, isEdited: $isManualEdit, maxLength: 20, maxLines: 2)
                }
            }
        }
        .onChange(of: formState.category) { _, newValue in
            if !isManualEdit || viewModel.budgetTransactionInputFormState.description.isEmpty {
                viewModel.budgetTransactionInputFormState.description = newValue.defaultDescription
            }
        }
        .navigationTitle(viewModel.transactionInputTitle())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel".localized) {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("common.save".localized) {
                    viewModel.didTapSaveTransaction()
                    if viewModel.budgetTransactionInputFormState.isValid {
                        dismiss()
                    }
                }
            }
        }
        .keyboardButtons()
        .toast(message: viewModel.toastMessage)
    }
}
