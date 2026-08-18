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
    
    var onSave: ((Transaction) -> Void)? = nil
    
    init(transaction: Transaction? = nil, onSave: ((Transaction) -> Void)? = nil) {
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
        List {
            Section("transaction.form.infomation".localized) {
                TextField("transaction.form.amount", text: $input.amountText)
                    .keyboardType(.numberPad)
                    .currencyInputFormat($input.amountText)
                
                DatePicker(
                    "transaction.form.date".localized,
                    selection: $input.occurredAt,
                    displayedComponents: .date
                )
            }
            
            Section("Preferences") {
                Picker(
                    "transaction.form.paymentMethod".localized,
                    selection: $input.paymentMethod
                ) {
                    ForEach(PaymentMethod.allCases, id: \.self) { method in
                        Text(method.localizationKey.localized)
                            .tag(method)
                    }
                }
                
                Picker(
                    "transaction.form.transactionType".localized,
                    selection: $input.transactionType
                ) {
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Text(type.localizedTitle)
                            .tag(type)
                    }
                }
                
                Picker(
                    "transaction.form.category".localized,
                    selection: $input.category
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
            
            Section("transaction.form.description".localized + " " + "common.optional.bracket".localized) {
                TextEditor(text: $input.description)
            }
        }
        .navigationTitle(title)
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
            if let transaction = originalTransacion {
                try input.apply(to: transaction)
                onSave?(transaction)
            } else {
                let transaction = try input.validatedInputTransaction()
                onSave?(transaction)
            }
            
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
