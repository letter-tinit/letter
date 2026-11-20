import SwiftUI
import Domain
import Styleguide

struct BudgetTransactionTemplateListView: View {
    let plans: [BudgetTransactionTemplate]
    let canCreateTransaction: Bool
    let cycleDay: Int
    let onCycleDayChange: (Int) -> Void
    let onCreateTransaction: (BudgetTransactionTemplate) -> Void
    let onSave: (BudgetTransactionTemplate) -> Void
    let onDelete: (UUID) -> Void

    @State private var editor: Editor?

    var body: some View {
        List {
            Section("budget.cycleDay.title".localized) {
                Picker("budget.cycleDay.label".localized, selection: Binding(
                    get: { cycleDay },
                    set: onCycleDayChange
                )) {
                    ForEach(1...28, id: \.self) { day in
                        Text(String(format: "%02d", day)).tag(day)
                    }
                }
                .pickerStyle(.menu)
            }

            if plans.isEmpty {
                Text("budget.transactionTemplate.empty".localized)
                    .customFont(.body)
                    .foregroundStyle(.secondary)
            }

            ForEach(plans) { plan in
                HStack(spacing: 12) {
                    Button { onCreateTransaction(plan) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(plan.description).customFont(.body, weight: .medium)
                            Text("\(plan.category.localizedTitle.localized) · \(plan.amount?.formattedVND ?? "budget.transactionTemplate.amount.optional".localized)")
                                .customFont(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCreateTransaction)

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
        .navigationTitle("budget.transactionTemplate.title".localized)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editor = Editor(plan: nil) } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editor) { item in
            NavigationStack {
                BudgetTransactionTemplateForm(plan: item.plan, onSave: onSave)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private struct Editor: Identifiable {
        let id = UUID()
        let plan: BudgetTransactionTemplate?
        init(plan: BudgetTransactionTemplate?) { self.plan = plan }
    }
}
