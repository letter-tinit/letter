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
    
    public let titleKey: String
    public let reuseHelpKey: String?
    public let itemID: UUID?
    
    @State private var formState: NetWorthItemFormState
    @State private var toastMessage: ToastMessage?
    @State private var isDeleteConfirmationPresented = false
    
    public init(
        initialState: NetWorthItemFormState = NetWorthItemFormState(),
        titleKey: String = "networth.item.form.title",
        reuseHelpKey: String? = nil,
        itemID: UUID? = nil
    ) {
        self.titleKey = titleKey
        self.reuseHelpKey = reuseHelpKey
        self.itemID = itemID
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
            
            if itemID != nil {
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
        .keyboardButtons()
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
            let input = try formState.validatedInput()
            if let itemID {
                try netWorthViewModel.updateSelectedItem(id: itemID, input: input)
            } else {
                try netWorthViewModel.addSelectedItem(input)
            }
            dismiss()
        } catch let error as NetWorthItemFormValidationError {
            showError(error.localizationKey.localized)
        } catch {
            showError("networth.item.form.error.save".localized)
        }
    }
    
    public func deleteItem() {
        do {
            if let itemID {
                try netWorthViewModel.deleteSelectedItem(id: itemID)
            }
            dismiss()
        } catch {
            showError("networth.item.form.error.delete".localized)
        }
    }
    
    public func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}

extension NetWorthItemFormState {
    init(item: NetWorthItemPresentationModel, amount: Decimal?) {
        self.init()
        category = item.category
        name = item.name
        amountText = amount.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
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
