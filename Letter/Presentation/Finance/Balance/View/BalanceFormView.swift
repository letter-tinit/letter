//
//  BalanceFormView.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import SwiftUI

struct BalanceFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var input: TransactionInput
    @State private var toastMessage: ToastMessage?
    @State private var isUpdate: Bool = false
    
    private let originalTransacion: Transaction?
    
    var onSave: ((TransactionInput, Transaction?) throws -> Void)?
    
    init(
        transaction: Transaction? = nil,
        onSave: ((TransactionInput, Transaction?) throws -> Void)? = nil
    ) {
        self.originalTransacion = transaction
        self.onSave = onSave
        
        if let transaction {
            _title = State(initialValue: "transaction.form.edit.title".localized)
            _input = State(initialValue: .init(transaction: transaction))
        } else {
            _title = State(initialValue: "transaction.form.title".localized)
            _input = State(initialValue: .template)
        }
    }
    
    var body: some View {
        AppScrollView {
            VStack {
                StandaloneSection(rows: "transaction.form.infomation".localized) {
                    AmountField(
                        "transaction.form.amount".localized,
                        text: $input.amountText
                    )

                    DatePicker(
                        "transaction.form.date".localized,
                        selection: $input.occurredAt,
                        displayedComponents: .date
                    )
                }
                
                StandaloneSection(rows: "Preferences") {
                    AppPicker(
                        "transaction.form.paymentMethod".localized,
                        selection: $input.paymentMethod,
                        layout: .labeledRow
                    ) {
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Text(method.localizationKey.localized)
                                .tag(method)
                        }
                    }

                    AppPicker(
                        "transaction.form.transactionType".localized,
                        selection: $input.transactionType,
                        layout: .labeledRow
                    ) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.localizedTitle)
                                .tag(type)
                        }
                    }

                    AppPicker(
                        "transaction.form.category".localized,
                        selection: $input.category,
                        layout: .labeledRow
                    ) {
                        ForEach(TransactionCategory.allCases, id: \.self) { category in
                            Label {
                                Text(category.localizedTitle)
                            } icon: {
                                Image(systemName: category.icon)
                            }
                            .tag(category)
                        }
                    }
                }
                
                StandaloneSection("transaction.form.description".localized + " " + "common.optional.bracket".localized) {
                    TextEditor(text: $input.description)
                        .frame(minHeight: 40)
                }
            }
        }
        .navigationTitle(title)
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    handleSave()
                } label: {
                    Text("common.save".localized)
                }
            }
        }
        .keyboardDoneButton()
        .toast(message: toastMessage, position: .top)
    }
}

// MARK: - PRIVATE HELPER
private extension BalanceFormView {
    func handleSave() {
        do {
            try onSave?(input, originalTransacion)
            dismiss()
        } catch let error as TransactionFormValidationError {
            makeToastError(message: error.localizedDescription)
        } catch {
            makeToastError(message: "common.error.unknown".localized)
        }
    }
    
    func makeToastError(message: String?) {
        guard let message else {
            toastMessage = nil
            return
        }
        toastMessage = ToastMessage(text: message.localized, type: .failure)
    }
}

#Preview {
    NavigationStack {
        BalanceFormView()
    }
}
