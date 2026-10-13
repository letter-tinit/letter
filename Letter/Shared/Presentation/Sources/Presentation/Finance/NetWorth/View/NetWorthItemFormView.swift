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
    
    @State private var isDeleteConfirmationPresented = false
    @State private var titleKey: String = ""
    @State private var formState: NetWorthItemFormState
    
    init(_ itemEditing: NetWorthItemEditing) {
        self._formState = .init(initialValue: .init(itemEditing))
        
        let format = itemEditing.item == nil ?
        "networth.item.form.title".localized :
        "networth.item.form.edit.title".localized
        let argument = itemEditing.category.groupType.titleKey.localized
        
        self._titleKey = .init(initialValue: String(format: format, argument).titleCase)
    }
    
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
                        ForEach(netWorthViewModel.itemEditing?.categories ?? [], id: \.self) { category in
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
                
                if netWorthViewModel.itemEditing != nil {
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
        .navigationTitle(titleKey)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toast(message: netWorthViewModel.toastMessage)
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
            netWorthViewModel.deleteSelectedItem()
            dismiss()
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
            let input = try formState.validatedInput()
            netWorthViewModel.saveItem(input)
            dismiss()
        } catch let error as NetWorthItemFormValidationError {
            netWorthViewModel.showError(error.localizationKey.localized)
        } catch {
            netWorthViewModel.showError("networth.item.form.error.save".localized)
        }
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
