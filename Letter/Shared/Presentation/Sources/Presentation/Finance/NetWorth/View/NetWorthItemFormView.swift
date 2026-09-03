//
//  NetWorthItemFormView.swift
//  Letter
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct NetWorthItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    public let titleKey: String
    public let reuseHelpKey: String?
    public let onSave: (ValidatedNetWorthItemInput) throws -> Void
    public let onDelete: (() throws -> Void)?
    
    @State private var formState: NetWorthItemFormState
    @State private var toastMessage: ToastMessage?
    @State private var isDeleteConfirmationPresented = false
    
    public init(
        initialState: NetWorthItemFormState = NetWorthItemFormState(),
        titleKey: String = "networth.item.form.title",
        reuseHelpKey: String? = nil,
        onSave: @escaping (ValidatedNetWorthItemInput) throws -> Void,
        onDelete: (() throws -> Void)? = nil
    ) {
        self.titleKey = titleKey
        self.reuseHelpKey = reuseHelpKey
        self.onSave = onSave
        self.onDelete = onDelete
        _formState = State(initialValue: initialState)
    }
    
    public var body: some View {
        VStack {
            StandaloneSection(
                rows: "networth.item.form.section".localized,
                alignment: .leading
            ) {
                AppPicker(
                    "networth.item.form.category".localized,
                    selection: $formState.category,
                    layout: .labeledRow
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

                AmountField(
                    "networth.item.form.amount".localized,
                    text: $formState.amountText
                )

                Text("networth.item.form.amount.help".localized)
                    .customFont(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let reuseHelpKey {
                    Text(reuseHelpKey.localized)
                        .customFont(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            if onDelete != nil {
                StandaloneSection {
                    Button("networth.item.form.delete".localized, role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            Spacer()
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
extension NetWorthItemFormView {
    enum Field: Hashable {
        case name
        case amount
    }
    
    public func save() {
        do {
            try onSave(formState.validatedInput())
            dismiss()
        } catch let error as NetWorthItemFormValidationError {
            showError(error.localizationKey.localized)
        } catch {
            showError("networth.item.form.error.save".localized)
        }
    }
    
    public func deleteItem() {
        do {
            try onDelete?()
            dismiss()
        } catch {
            showError("networth.item.form.error.delete".localized)
        }
    }
    
    public func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}

extension NetWorthItemFormValidationError {
    public var localizationKey: String {
        switch self {
        case .nameRequired:
            "networth.item.form.error.name"
        case .invalidAmount:
            "networth.item.form.error.amount"
        }
    }
}
