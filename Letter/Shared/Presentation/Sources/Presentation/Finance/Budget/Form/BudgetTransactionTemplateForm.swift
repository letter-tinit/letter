import SwiftUI
import Domain
import Styleguide

struct BudgetTransactionTemplateForm: View {
    @Environment(\.dismiss) private var dismiss
    let plan: BudgetTransactionTemplate?
    let onSave: (BudgetTransactionTemplate) -> Void

    @State private var description = ""
    @State private var amount = ""
    @State private var category: BudgetTransactionCategory = .other
    @State private var descriptionEdited = false

    var body: some View {
        AppScrollView {
            VStack {
                StandaloneSection(rows: "budget.transactionTemplate.details".localized) {
                    AppTextField("budget.transactionTemplate.name".localized, text: $description, isEdited: $descriptionEdited, maxLength: 30, maxLines: 1)
                    AmountField("budget.transactionTemplate.amount.optional".localized, text: $amount)
                    AppPicker("transaction.form.allocation".localized, selection: $category, layout: .labeledRow) {
                        ForEach(BudgetTransactionCategory.allCases) { category in
                            Text(category.localizedTitle.localized).tag(category)
                        }
                    }
                }
            }
        }
        .navigationTitle(plan == nil ? "budget.transactionTemplate.create".localized : "budget.transactionTemplate.edit".localized)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel".localized) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("common.save".localized) {
                    let name = description.trimmingCharacters(in: .whitespacesAndNewlines)
                    let amountValue = amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : amount.toDecimal()
                    guard !name.isEmpty, amountValue.map({ $0 > .zero }) ?? true else { return }
                    onSave(BudgetTransactionTemplate(id: plan?.id ?? UUID(), description: name, amount: amountValue, category: category))
                    dismiss()
                }
                .disabled(
                    description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || (amount.isEmpty == false && amount.toDecimal() <= .zero)
                )
            }
        }
        .onAppear {
            guard let plan else { return }
            description = plan.description
            amount = plan.amount?.toAmountString ?? ""
            category = plan.category
        }
    }
}
