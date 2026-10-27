import SwiftUI
import Domain
import Styleguide

struct BudgetFixedPlanListView: View {
    let plans: [BudgetFixedPlan]
    let completedIDs: Set<UUID>
    let canApply: Bool
    let onApply: (UUID) -> Void
    let onCreateTransaction: (BudgetFixedPlan) -> Void
    let onSave: (BudgetFixedPlan) -> Void
    let onDelete: (UUID) -> Void

    @State private var editor: Editor?

    var body: some View {
        List {
            if plans.isEmpty {
                Text("budget.fixedPlan.empty".localized)
                    .customFont(.body)
                    .foregroundStyle(.secondary)
            }

            ForEach(plans) { plan in
                HStack(spacing: 12) {
                    Button {
                        if !completedIDs.contains(plan.id) { onApply(plan.id) }
                    } label: {
                        Image(systemName: completedIDs.contains(plan.id) ? "checkmark.circle.fill" : "circle")
                            .customFont(.title3)
                            .foregroundStyle(completedIDs.contains(plan.id) ? Color.Common.success : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canApply || completedIDs.contains(plan.id))
                    .accessibilityLabel(completedIDs.contains(plan.id) ? "budget.fixedPlan.completed".localized : "budget.fixedPlan.apply".localized)

                    Button { onCreateTransaction(plan) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(plan.description).customFont(.body, weight: .medium)
                            Text("\(plan.category.localizedTitle.localized) · \(plan.amount.formattedVND)")
                                .customFont(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canApply || completedIDs.contains(plan.id))

                    Button { editor = Editor(plan: plan) } label: {
                        Image(systemName: "pencil").customFont(.body)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("common.edit".localized)
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                offsets.map { plans[$0].id }.forEach(onDelete)
            }
        }
        .navigationTitle("budget.fixedPlan.title".localized)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editor = Editor(plan: nil) } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editor) { item in
            NavigationStack {
                BudgetFixedPlanForm(plan: item.plan, onSave: onSave)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private struct Editor: Identifiable {
        let id = UUID()
        let plan: BudgetFixedPlan?
        init(plan: BudgetFixedPlan?) { self.plan = plan }
    }
}
