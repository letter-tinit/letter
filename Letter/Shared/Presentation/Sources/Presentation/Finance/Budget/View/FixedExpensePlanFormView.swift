//
//  FixedExpensePlanFormView.swift
//  Letter
//
//  Created by TiniT on 14/7/26.
//

import SwiftUI
import Domain
import Core
import Utility
import Styleguide

public struct FixedExpensePlanFormView: View {
    @Environment(\.dismiss) private var dismiss

    public let titleKey: String
    public let onSave: (ValidatedFixedExpensePlanInput) throws -> Void
    public let onDelete: (() throws -> Void)?

    @State private var formState: FixedExpensePlanFormState
    @State private var toastMessage: ToastMessage?
    @State private var isDeleteConfirmationPresented = false

    public init(
        initialState: FixedExpensePlanFormState = FixedExpensePlanFormState(),
        titleKey: String = "fixed.plan.form.title",
        onSave: @escaping (ValidatedFixedExpensePlanInput) throws -> Void,
        onDelete: (() throws -> Void)? = nil
    ) {
        self.titleKey = titleKey
        self.onSave = onSave
        self.onDelete = onDelete
        _formState = State(initialValue: initialState)
    }

    public var body: some View {
        VStack {
            StandaloneSection(
                rows: "fixed.plan.form.section.details".localized,
                alignment: .leading,
                spacing: 16
            ) {
                TextField(
                    "fixed.plan.form.name".localized,
                    text: $formState.name
                )

                AmountField(
                    "fixed.plan.form.amount".localized,
                    text: $formState.amountText
                )

                Text("fixed.plan.form.amount.help".localized)
                    .customFont(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                AppPicker(
                    "fixed.plan.form.amountType".localized,
                    selection: $formState.amountType,
                    layout: .labeledRow
                ) {
                    ForEach(FixedExpensePlanAmountType.allCases, id: \.self) { type in
                        Text(type.localizationKey.localized)
                            .tag(type)
                    }
                }
            }
            
            if onDelete != nil {
                StandaloneSection {
                    Button("fixed.plan.form.delete".localized, role: .destructive) {
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
        .toast(message: toastMessage)
        .deleteConfirmationDialog(
            isPresented: $isDeleteConfirmationPresented,
            title: "fixed.plan.delete.confirmation.title".localized,
            message: "fixed.plan.delete.confirmation.message".localized
        ) {
            deletePlan()
        }
    }
}

private extension FixedExpensePlanFormView {
    enum Field: Hashable {
        case name
        case amount
    }

    public func save() {
        do {
            let input = try formState.validatedInput()
            try onSave(input)
            dismiss()
        } catch let error as FixedExpensePlanFormValidationError {
            showError(error.localizationKey.localized)
        } catch {
            showError("fixed.plan.form.error.save".localized)
        }
    }

    public func deletePlan() {
        do {
            try onDelete?()
            dismiss()
        } catch {
            showError("fixed.plan.form.error.delete".localized)
        }
    }
    
    public func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}

public extension FixedExpensePlanFormValidationError {
    public var localizationKey: String {
        switch self {
        case .nameRequired:
            "fixed.plan.form.error.name"
        case .invalidAmount:
            "fixed.plan.form.error.amount"
        }
    }
}

public extension FixedExpensePlanAmountType {
    public var localizationKey: String {
        "fixed.plan.amountType.\(rawValue)"
    }
}

