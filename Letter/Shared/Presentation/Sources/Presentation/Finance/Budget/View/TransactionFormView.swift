//
//  TransactionFormView.swift
//  Letter
//
//  Created by TiniT on 14/7/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetViewModel.self) private var budgetViewModel

    public let allocations: [BudgetAllocation]
    public let showsAllocationPicker: Bool
    public let titleKey: String
    public let budgetID: UUID?
    public let transactionID: UUID?
    public let fixedExpensePlanID: UUID?
    private let remainingAmountModel: BudgetRemainingAmountModel
    @State private var formState: TransactionFormState
    @State private var toastMessage: ToastMessage?
    @State private var isDeleteConfirmationPresented = false
    @FocusState private var focusedField: Field?

    public init(
        allocations: [BudgetAllocation],
        remainingAmountModel: BudgetRemainingAmountModel = BudgetRemainingAmountModel(),
        showsAllocationPicker: Bool = true,
        initialState: TransactionFormState = TransactionFormState(),
        titleKey: String = "transaction.form.title",
        budgetID: UUID? = nil,
        transactionID: UUID? = nil,
        fixedExpensePlanID: UUID? = nil
    ) {
        var formattedState = initialState
        if formattedState.allocationID == nil {
            formattedState.allocationID = allocations.max(by: { $0.ratio < $1.ratio })?.id
        }

        self.allocations = allocations
        self.showsAllocationPicker = showsAllocationPicker
        self.titleKey = titleKey
        self.budgetID = budgetID
        self.transactionID = transactionID
        self.fixedExpensePlanID = fixedExpensePlanID
        self.remainingAmountModel = remainingAmountModel
        _formState = State(initialValue: formattedState)
    }

    public var body: some View {
        AppScrollView {
            VStack {
                StandaloneSection(rows: "transaction.form.section.details".localized) {
                    TextField(
                        "transaction.form.description".localized,
                        text: $formState.description
                    )
                    .focused($focusedField, equals: .description)

                    AmountField(
                        "transaction.form.amount".localized,
                        text: $formState.amountText
                    )
                    .focused($focusedField, equals: .amount)

                    if showsAllocationPicker {
                        AppPicker(
                            "transaction.form.allocation".localized,
                            selection: $formState.allocationID,
                            layout: .labeledRow
                        ) {
                            ForEach(allocations) { allocation in
                                Label(
                                    allocation.kind.localizationKey.localized,
                                    systemImage: allocation.kind.systemImageName
                                )
                                .tag(allocation.id as UUID?)
                            }
                        }
                    }

                    DatePicker(
                        "transaction.form.date".localized,
                        selection: $formState.occurredAt,
                        displayedComponents: .date
                    )
                }

                StandaloneSection(rows: "transaction.form.section.payment".localized) {
                    AppPicker(
                        "transaction.form.paymentMethod".localized,
                        selection: $formState.paymentMethod,
                        layout: .labeledRow
                    ) {
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Text(method.localizationKey.localized)
                                .tag(method)
                        }
                    }

                    TextField(
                        "transaction.form.note".localized,
                        text: $formState.note,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .note)
                }

                if transactionID != nil {
                    StandaloneSection {
                        Button(
                            "transaction.form.delete".localized,
                            role: .destructive
                        ) {
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
        .keyboardButtons(items: keyboardToolbarItems)
        .toast(message: toastMessage)
        .deleteConfirmationDialog(
            isPresented: $isDeleteConfirmationPresented,
            title: "transaction.form.delete.confirmation.title".localized,
            message: "common.delete.warning".localized
        ) {
            deleteTransaction()
        }
    }
}

extension TransactionFormView {
    private var keyboardToolbarItems: [KeyboardToolbarItem] {
        guard focusedField == .amount,
              let amount = remainingAmountModel.amount else {
            return []
        }
        let remainingAmountButton = KeyboardToolbarItem.button(
            title: amount.title,
            action: { formState.amountText = amount.text }
        )
        return [remainingAmountButton, .spacer]
    }

    enum Field: Hashable {
        case description
        case amount
        case note
    }

    public func save() {
        do {
            let input = try formState.validatedInput()
            if let budgetID, let fixedExpensePlanID {
                try budgetViewModel.completeFixedExpensePlan(
                    id: fixedExpensePlanID,
                    input: input,
                    in: budgetID
                )
            } else if let budgetID, let transactionID {
                try budgetViewModel.updateTransaction(
                    id: transactionID,
                    input: input,
                    in: budgetID
                )
            } else if let budgetID {
                try budgetViewModel.addTransaction(input, to: budgetID)
            }
            dismiss()
        } catch let error as BudgetTransactionFormValidationError {
            showError(error.localizationKey.localized)
        } catch {
            showError("transaction.form.error.save".localized)
        }
    }

    public func deleteTransaction() {
        do {
            if let budgetID, let transactionID {
                try budgetViewModel.deleteTransaction(id: transactionID, from: budgetID)
            }
            dismiss()
        } catch {
            showError("transaction.form.error.delete".localized)
        }
    }

    public func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}

extension BudgetTransactionFormValidationError {
    public var localizationKey: String {
        switch self {
        case .descriptionRequired:
            "transaction.form.error.description"
        case .allocationRequired:
            "transaction.form.error.allocation"
        case .invalidAmount:
            "transaction.form.error.amount.positive"
        }
    }
}
