//
//  FixedPlanView.swift
//  Letter
//
//  Created by TiniT on 14/7/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct FixedPlanView: View {
    @Environment(BudgetViewModel.self) private var budgetViewModel
    public let budgetID: UUID
    public let plans: [FixedExpensePlan]
    public let isEditingUnlocked: Bool
    
    @State private var isAddFormPresented = false
    @State private var selectedPlan: FixedExpensePlan?
    @State private var planPendingDeletion: FixedExpensePlan?
    @State private var planPendingCompletion: FixedExpensePlan?
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeleteErrorPresented = false
    
    public init(
        budgetID: UUID,
        plans: [FixedExpensePlan],
        isEditingUnlocked: Bool = true
    ) {
        self.budgetID = budgetID
        self.plans = plans
        self.isEditingUnlocked = isEditingUnlocked
    }
    
    private var totalAmount: Decimal {
        plans.reduce(.zero) { partialResult, plan in
            partialResult + plan.amount
        }
    }
    
    public var body: some View {
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
                FixedExpensePlanFormView(budgetID: budgetID)
                    .environment(budgetViewModel)
            }
        }
        .sheet(item: $selectedPlan) { plan in
            NavigationStack {
                FixedExpensePlanFormView(
                    budgetID: budgetID,
                    initialState: FixedExpensePlanFormState(plan: plan),
                    titleKey: "fixed.plan.form.edit.title",
                    planID: plan.id
                )
                .environment(budgetViewModel)
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
                    budgetID: budgetID,
                    fixedExpensePlanID: plan.id
                )
                .environment(budgetViewModel)
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
extension FixedPlanView {
    public func deletePendingPlan() {
        guard let planPendingDeletion else {
            return
        }
        
        do {
            try budgetViewModel.deleteFixedExpensePlan(id: planPendingDeletion.id, from: budgetID)
            self.planPendingDeletion = nil
        } catch {
            self.planPendingDeletion = nil
            isDeleteErrorPresented = true
        }
    }
    
    public var totalSection: some View {
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
    
    public var emptyView: some View {
        CommonEmptyView(
            "fixed.plan.empty.title".localized,
            systemImage: "list.bullet.rectangle",
            description: "fixed.plan.empty.description".localized
        )
    }
}

// MARK: - Preview
