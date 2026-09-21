//
//  FixedExpensePlanFormView.swift
//  Letter
//
//  Created by TiniT on 14/7/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct FixedExpensePlanFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetViewModel.self) private var budgetViewModel

    public let titleKey: String
    public let budgetID: UUID
    public let planID: UUID?

    @State private var formState: FixedExpensePlanFormState
    @State private var toastMessage: ToastMessage?
    @State private var isDeleteConfirmationPresented = false

    public init(
        budgetID: UUID,
        initialState: FixedExpensePlanFormState = FixedExpensePlanFormState(),
        titleKey: String = "fixed.plan.form.title",
        planID: UUID? = nil
    ) {
        self.titleKey = titleKey
        self.budgetID = budgetID
        self.planID = planID
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
            
            if planID != nil {
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
        .keyboardButtons()
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

extension FixedExpensePlanFormView {
    enum Field: Hashable {
        case name
        case amount
    }

    public func save() {
        do {
            let input = try formState.validatedInput()
            if let planID {
                try budgetViewModel.updateFixedExpensePlan(
                    id: planID,
                    input: input,
                    in: budgetID
                )
            } else {
                try budgetViewModel.addFixedExpensePlan(input, to: budgetID)
            }
            dismiss()
        } catch let error as FixedExpensePlanFormValidationError {
            showError(error.localizationKey.localized)
        } catch {
            showError("fixed.plan.form.error.save".localized)
        }
    }

    public func deletePlan() {
        do {
            if let planID {
                try budgetViewModel.deleteFixedExpensePlan(id: planID, from: budgetID)
            }
            dismiss()
        } catch {
            showError("fixed.plan.form.error.delete".localized)
        }
    }
    
    public func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}

extension FixedExpensePlanFormValidationError {
    public var localizationKey: String {
        switch self {
        case .nameRequired:
            "fixed.plan.form.error.name"
        case .invalidAmount:
            "fixed.plan.form.error.amount"
        }
    }
}

extension FixedExpensePlanAmountType {
    public var localizationKey: String {
        "fixed.plan.amountType.\(rawValue)"
    }
}
