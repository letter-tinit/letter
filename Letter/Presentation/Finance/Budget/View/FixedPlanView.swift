//
//  FixedPlanView.swift
//  Letter
//
//  Created by TiniT on 14/7/26.
//

import SwiftUI

struct FixedPlanView: View {
    let plans: [FixedExpensePlan]
    let onAdd: (ValidatedFixedExpensePlanInput) throws -> Void
    let onUpdate: (UUID, ValidatedFixedExpensePlanInput) throws -> Void
    let onDelete: (UUID) throws -> Void
    let onComplete: (UUID, ValidatedBudgetTransactionInput) throws -> Void
    let isEditingUnlocked: Bool
    
    @State private var isAddFormPresented = false
    @State private var selectedPlan: FixedExpensePlan?
    @State private var planPendingDeletion: FixedExpensePlan?
    @State private var planPendingCompletion: FixedExpensePlan?
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeleteErrorPresented = false
    
    init(
        plans: [FixedExpensePlan],
        onAdd: @escaping (ValidatedFixedExpensePlanInput) throws -> Void = { _ in },
        onUpdate: @escaping (UUID, ValidatedFixedExpensePlanInput) throws -> Void = { _, _ in },
        onDelete: @escaping (UUID) throws -> Void = { _ in },
        onComplete: @escaping (UUID, ValidatedBudgetTransactionInput) throws -> Void = { _, _ in },
        isEditingUnlocked: Bool = true
    ) {
        self.plans = plans
        self.onAdd = onAdd
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onComplete = onComplete
        self.isEditingUnlocked = isEditingUnlocked
    }
    
    private var totalAmount: Decimal {
        plans.reduce(.zero) { partialResult, plan in
            partialResult + plan.amount
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                if plans.isEmpty {
                    emptyView
                } else {
                    ForEach(plans, id: \.self) { plan in
                        HStack(spacing: 12) {
                            if plan.transaction == nil {
                                Button {
                                    planPendingCompletion = plan
                                } label: {
                                    Image(systemName: "circle")
                                        .customFont(.title3)
                                }
                                .accessibilityLabel("fixed.plan.complete".localized)
                                .disabled(!isEditingUnlocked)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                        .customFont(.title3)
                                    .foregroundStyle(Color.Common.success)
                                    .accessibilityLabel("fixed.plan.completed".localized)
                            }
                            
                            Button {
                                selectedPlan = plan
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    CommonRowView(
                                        .init(
                                            title: plan.name,
                                            value: plan.amount.formattedVND
                                        )
                                    )
                                    
                                    Text(plan.amountType.localizationKey.localized)
                                        .customFont(.subheadline)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("fixed.plan.edit.accessibilityHint".localized)
                            .disabled(!isEditingUnlocked)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                planPendingDeletion = plan
                                isDeleteConfirmationPresented = true
                            } label: {
                                Label(
                                    "common.delete".localized,
                                    systemImage: "trash"
                                )
                            }
                            .tint(Color.Common.failure)
                            .disabled(!isEditingUnlocked)
                        }
                    }
                }
            }
            .listStyle(.grouped)
            .scrollIndicators(.hidden)
            
            totalSection
        }
        .navigationTitle("fixed.plan.title".localized)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddFormPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("fixed.plan.form.add".localized)
                .disabled(!isEditingUnlocked)
            }
        }
        .sheet(isPresented: $isAddFormPresented) {
            NavigationStack {
                FixedExpensePlanFormView(onSave: onAdd)
            }
        }
        .sheet(item: $selectedPlan) { plan in
            NavigationStack {
                FixedExpensePlanFormView(
                    initialState: FixedExpensePlanFormState(plan: plan),
                    titleKey: "fixed.plan.form.edit.title",
                    onSave: { input in
                        try onUpdate(plan.id, input)
                    },
                    onDelete: {
                        try onDelete(plan.id)
                    }
                )
            }
        }
        .sheet(item: $planPendingCompletion) { plan in
            NavigationStack {
                TransactionFormView(
                    allocations: [],
                    showsAllocationPicker: false,
                    initialState: TransactionFormState(
                        fixedExpensePlan: plan
                    ),
                    titleKey: "fixed.plan.complete.title",
                    onSave: { input in
                        try onComplete(plan.id, input)
                    }
                )
            }
        }
        .deleteConfirmationDialog(
            isPresented: $isDeleteConfirmationPresented,
            title: "fixed.plan.delete.confirmation.title".localized,
            message: "fixed.plan.delete.confirmation.message".localized
        ) {
            deletePendingPlan()
        } cancelAction: {
            planPendingDeletion = nil
        }
        .alert(
            "fixed.plan.form.error.delete".localized,
            isPresented: $isDeleteErrorPresented
        ) {
            Button("common.ok".localized, role: .cancel) {}
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

// MARK: - Subviews
private extension FixedPlanView {
    func deletePendingPlan() {
        guard let planPendingDeletion else {
            return
        }
        
        do {
            try onDelete(planPendingDeletion.id)
            self.planPendingDeletion = nil
        } catch {
            self.planPendingDeletion = nil
            isDeleteErrorPresented = true
        }
    }
    
    var totalSection: some View {
        CommonRowView(
            .init(
                title: "fixed.plan.total".localized,
                value: totalAmount.formattedVND,
                isHighlight: true
            )
        )
        .padding()
        .padding(.bottom)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground)
                .overlay(BudgetBucketKind.needs.topicColor.opacity(0.12))
        )
    }
    
    var emptyView: some View {
        CommonEmptyView(
            "fixed.plan.empty.title".localized,
            systemImage: "list.bullet.rectangle",
            description: "fixed.plan.empty.description".localized
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FixedPlanView(
            plans: []
        )
    }
}
