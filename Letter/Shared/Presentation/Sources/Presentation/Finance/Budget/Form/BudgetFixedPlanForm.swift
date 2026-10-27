import SwiftUI
import Domain
import Styleguide

struct BudgetFixedPlanForm: View {
    @Environment(\.dismiss) private var dismiss
    let plan: BudgetFixedPlan?
    let onSave: (BudgetFixedPlan) -> Void

    @State private var description = ""
    @State private var amount = ""
    @State private var category: BudgetTransactionCategory = .other
    @State private var descriptionEdited = false

    var body: some View {
        AppScrollView {
            VStack {
                StandaloneSection(rows: "budget.fixedPlan.details".localized) {
                    AppTextField("budget.fixedPlan.name".localized, text: $description, isEdited: $descriptionEdited, maxLength: 30, maxLines: 1)
                    AmountField("transaction.form.amount".localized, text: $amount)
                    AppPicker("transaction.form.allocation".localized, selection: $category, layout: .labeledRow) {
                        ForEach(BudgetTransactionCategory.allCases) { category in
                            Text(category.localizedTitle.localized).tag(category)
                        }
                    }
                }
            }
        }
        .navigationTitle(plan == nil ? "budget.fixedPlan.create".localized : "budget.fixedPlan.edit".localized)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel".localized) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("common.save".localized) {
                    let name = description.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty, amount.toDecimal() > .zero else { return }
                    onSave(BudgetFixedPlan(id: plan?.id ?? UUID(), description: name, amount: amount.toDecimal(), category: category))
                    dismiss()
                }
                .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount.toDecimal() <= .zero)
            }
        }
        .onAppear {
            guard let plan else { return }
            description = plan.description
            amount = plan.amount.toAmountString
            category = plan.category
        }
    }
}
