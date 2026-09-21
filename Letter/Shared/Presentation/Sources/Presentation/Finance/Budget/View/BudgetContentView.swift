//
//  BudgetContentView.swift
//  Letter
//
//  Created by TiniT on 9/7/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct BudgetContentView: View {
    @Environment(BudgetViewModel.self) private var budgetViewModel
    @State private var title: String = "salary.budget".localized
    @State private var segmentOption: SegmentOption = .transaction
    @State private var isFixedPlanPresented = false
    @State private var isTransactionFormPresented = false
    @State private var selectedTransaction: BudgetTransactionRowModel?
    @State private var transactionPendingDeletionID: BudgetTransaction.ID?
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeleteErrorPresented = false
    @State private var transactionGroups: [BudgetTransactionGroupModel] = []
    @Binding private var budget: Budget
    private var remainingAmountModel: BudgetRemainingAmountModel {
        budgetViewModel.remainingAmountModels[budget.id] ?? BudgetRemainingAmountModel()
    }
    public let isEditingUnlocked: Bool

    private var isExpandAllTransaction: Bool {
        !transactionGroups.isEmpty &&
        transactionGroups.allSatisfy(\.isExpanded)
    }

    public init(
        budget: Binding<Budget>,
        isEditingUnlocked: Bool
    ) {
        self._budget = budget
        self.isEditingUnlocked = isEditingUnlocked
    }

    @ViewBuilder
    public var body: some View {
        budgetBody(budget)
    }

    private func budgetBody(_ budget: Budget) -> some View {
        BaseScreen($title) {
            VStack {
                BudgetIncomeCardView(
                    budget: budget,
                    isExpandAllTransaction: isExpandAllTransaction,
                    isEditingUnlocked: isEditingUnlocked,
                    onToggleTransactionGroupsExpansion: toggleTransactionGroupsExpansion,
                    isFixedPlanPresented: $isFixedPlanPresented,
                    segmentOption: $segmentOption
                )
                .padding(.horizontal)
                .padding(.top)
                
                content
            }
        }
        .onAppear {
            title = budget.periodStart.toString(withFormat: .month)
            syncTransactionGroups()
        }
        .onChange(of: budget.transactions.budgetTransactionGroupSnapshot) {
            syncTransactionGroups()
        }
        .sheet(isPresented: $isFixedPlanPresented) {
            NavigationStack {
                FixedPlanView(
                    plans: budget.fixedExpensePlans,
                    onAdd: addFixedExpensePlan,
                    onUpdate: updateFixedExpensePlan,
                    onDelete: deleteFixedExpensePlan,
                    onComplete: completeFixedExpensePlan,
                    isEditingUnlocked: isEditingUnlocked
                )
            }
        }
        .sheet(isPresented: $isTransactionFormPresented) {
            NavigationStack {
                TransactionFormView(
                    allocations: budget.allocations,
                    remainingAmountModel: remainingAmountModel) { input in
                        try budgetViewModel.addTransaction(input, to: budget.id)
                    }
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack {
                TransactionFormView(
                    allocations: budget.allocations,
                    remainingAmountModel: remainingAmountModel,
                    initialState: TransactionFormState(transaction: transaction),
                    titleKey: "transaction.form.edit.title",
                    onSave: { input in
                        try budgetViewModel.updateTransaction(
                            id: transaction.id,
                            input: input,
                            in: budget.id
                        )
                    },
                    onDelete: {
                        try budgetViewModel.deleteTransaction(id: transaction.id, from: budget.id)
                    }
                )
            }
        }
        .onChange(of: transactionPendingDeletionID) { _, newValue in
            if newValue != nil {
                isDeleteConfirmationPresented = true
            }
        }
        .deleteConfirmationDialog(
            isPresented: $isDeleteConfirmationPresented,
            title: "transaction.form.delete.confirmation.title".localized,
            message: "common.delete.warning".localized
        ) {
            deletePendingTransaction()
        } cancelAction: {
            transactionPendingDeletionID = nil
        }
        .alert(
            "transaction.form.error.delete".localized,
            isPresented: $isDeleteErrorPresented
        ) {
            Button("common.ok".localized, role: .cancel) {}
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Haptic.selection()
                    isTransactionFormPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("transaction.form.add".localized)
                .disabled(!isEditingUnlocked)
            }
        }
    }
}

extension BudgetContentView {
    public func toggleTransactionGroupsExpansion() {
        if isExpandAllTransaction {
            transactionGroups.forEach { $0.isExpanded = false }
        } else {
            transactionGroups.forEach { $0.isExpanded = true }
        }
    }

    @ViewBuilder
    public var content: some View {
        if segmentOption == .bucket {
            BudgetAllocationListView(budget: $budget)
        } else {
            groupTransactionList
        }
    }

    @ViewBuilder
    public var groupTransactionList: some View {
        if budget.transactions.isEmpty {
            CommonEmptyView(
                systemImage: "list.bullet.rectangle",
                description: "budget.transactions.empty".localized
            )
        } else {
            AppScrollView {
                ForEach(transactionGroups) { group in
                    BudgetTransactionGroupRowView(
                        group: group,
                        selectedTransaction: $selectedTransaction,
                        transactionPendingDeletionID: $transactionPendingDeletionID,
                        isEditingUnlocked: isEditingUnlocked
                    )
                }
                .padding()
            }
        }
    }

    public func addFixedExpensePlan(_ input: ValidatedFixedExpensePlanInput) throws {
        try budgetViewModel.addFixedExpensePlan(input, to: budget.id)
    }

    public func updateFixedExpensePlan(planID: UUID, input: ValidatedFixedExpensePlanInput) throws {
        try budgetViewModel.updateFixedExpensePlan(
            id: planID,
            input: input,
            in: budget.id
        )
    }

    public func deleteFixedExpensePlan(_ planID: UUID) throws {
        try budgetViewModel.deleteFixedExpensePlan(id: planID, from: budget.id)
    }

    public func completeFixedExpensePlan(planID: UUID, input: ValidatedBudgetTransactionInput) throws {
        try budgetViewModel.completeFixedExpensePlan(
            id: planID,
            input: input,
            in: budget.id
        )
    }

    public func deletePendingTransaction() {
        guard let transactionPendingDeletionID else { return }
        do {
            try budgetViewModel.deleteTransaction(id: transactionPendingDeletionID, from: budget.id)
            self.transactionPendingDeletionID = nil
        } catch {
            self.transactionPendingDeletionID = nil
            isDeleteErrorPresented = true
        }
    }

    func syncTransactionGroups() {
        let expansionByDate = Dictionary(uniqueKeysWithValues: transactionGroups.map {
            ($0.date, $0.isExpanded)
        })
        transactionGroups = Dictionary(grouping: budget.transactions) {
            Calendar.current.startOfDay(for: $0.occurredAt)
        }
        .map { date, transactions in
            BudgetTransactionGroupModel(
                date: date,
                transactions: transactions
                    .sorted { $0.occurredAt > $1.occurredAt }
                    .map(BudgetTransactionRowModel.init),
                isExpanded: expansionByDate[date] ?? true
            )
        }
        .sorted { $0.date > $1.date }
    }
}

public extension BudgetContentView {
    enum SegmentOption: CaseIterable, Hashable {
        case transaction
        case bucket

        func displayName(budgetName: String) -> String {
            switch self {
            case .bucket:
                budgetName
            case .transaction:
                "budget.segment.transactions".localized
            }
        }
    }
}
