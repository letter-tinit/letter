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
    @Environment(NetWorthViewModel.self) private var netWorthViewModel
    
    @State private var titleKey: String = "networth.item.form.title"
    @State private var formState: NetWorthItemFormState = NetWorthItemFormState()
    @State private var toastMessage: ToastMessage?
    @State private var isDeleteConfirmationPresented = false
    
    public var body: some View {
        AppScrollView {
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
                        ForEach(NetWorthCategoryType.allCases, id: \.self) { category in
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
                }
                
                if netWorthViewModel.editingItem != nil {
                    StandaloneSection {
                        Button("networth.item.form.delete".localized, role: .destructive) {
                            isDeleteConfirmationPresented = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                Spacer()
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
        .keyboardButtons()
        .deleteConfirmationDialog(
            isPresented: $isDeleteConfirmationPresented,
            title: "networth.item.delete.confirmation.title".localized,
            message: "networth.item.delete.confirmation.message".localized
        ) {
            deleteItem()
        }
        .onAppear {
            if let item = netWorthViewModel.editingItem {
                self.titleKey = "networth.item.form.edit.title"
                self.formState = NetWorthItemFormState(
                    category: netWorthViewModel.editingItemCategory,
                    name: item.name,
                    amountText: String(describing: item.amount)
                )
            }
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
            let input = try formState.validatedInput()
            try netWorthViewModel.saveItem(input)
            dismiss()
        } catch let error as NetWorthItemFormValidationError {
            showError(error.localizationKey.localized)
        } catch {
            showError("networth.item.form.error.save".localized)
        }
    }
    
    public func deleteItem() {
        do {
            try netWorthViewModel.deleteSelectedItem()
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
