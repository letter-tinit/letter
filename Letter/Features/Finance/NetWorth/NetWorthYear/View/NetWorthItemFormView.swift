//
//  NetWorthItemFormView.swift
//  Personal Finance
//

import SwiftUI

struct NetWorthItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    let titleKey: String
    let reuseHelpKey: String?
    let onSave: (ValidatedNetWorthItemInput) throws -> Void
    let onDelete: (() throws -> Void)?
    
    @State private var formState: NetWorthItemFormState
    @State private var toastMessage: ToastMessage?
    @State private var isDeleteConfirmationPresented = false
    
    init(
        initialState: NetWorthItemFormState = NetWorthItemFormState(),
        titleKey: String = "networth.item.form.title",
        reuseHelpKey: String? = nil,
        onSave: @escaping (ValidatedNetWorthItemInput) throws -> Void,
        onDelete: (() throws -> Void)? = nil
    ) {
        var formattedState = initialState
        formattedState.amountText = CurrencyInputFormatter.format(initialState.amountText)
        
        self.titleKey = titleKey
        self.reuseHelpKey = reuseHelpKey
        self.onSave = onSave
        self.onDelete = onDelete
        _formState = State(initialValue: formattedState)
    }
    
    var body: some View {
        Form {
            Section("networth.item.form.section".localized) {
                Picker(
                    "networth.item.form.category".localized,
                    selection: $formState.category
                ) {
                    ForEach(NetWorthCategory.allCases, id: \.self) { category in
                        Text(category.localizationKey.localized)
                            .tag(category)
                    }
                }
                
                TextField(
                    "networth.item.form.name".localized,
                    text: $formState.name
                )
                
                TextField(
                    "networth.item.form.amount".localized,
                    text: $formState.amountText
                )
                .keyboardType(.numberPad)
                .currencyInputFormat($formState.amountText)
                
                Text("networth.item.form.amount.help".localized)
                    .secondarySubHeadline()
                
                if let reuseHelpKey {
                    Text(reuseHelpKey.localized)
                        .secondarySubHeadline()
                }
            }
            
            if onDelete != nil {
                Section {
                    Button("networth.item.form.delete".localized, role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(titleKey.localized)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toast(message: toastMessage)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel".localized) {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("common.save".localized) {
                    save()
                }
            }
        }
        .keyboardDoneButton()
        .deleteConfirmationDialog(
            isPresented: $isDeleteConfirmationPresented,
            title: "networth.item.delete.confirmation.title".localized,
            message: "networth.item.delete.confirmation.message".localized
        ) {
            deleteItem()
        }
    }
}

// MARK: - PRIVATE HELPER
private extension NetWorthItemFormView {
    enum Field: Hashable {
        case name
        case amount
    }
    
    func save() {
        do {
            try onSave(formState.validatedInput())
            dismiss()
        } catch let error as NetWorthItemFormValidationError {
            showError(error.localizationKey.localized)
        } catch {
            showError("networth.item.form.error.save".localized)
        }
    }
    
    func deleteItem() {
        do {
            try onDelete?()
            dismiss()
        } catch {
            showError("networth.item.form.error.delete".localized)
        }
    }
    
    func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}

private extension NetWorthItemFormValidationError {
    var localizationKey: String {
        switch self {
        case .nameRequired:
            "networth.item.form.error.name"
        case .invalidAmount:
            "networth.item.form.error.amount"
        }
    }
}

#Preview {
    NavigationStack {
        NetWorthItemFormView(onSave: { _ in })
    }
}
