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
    @State private var title: String = "salary.budget".localized
    @State private var segmentOption: SegmentOption = .transaction
    @State private var isFixedPlanPresented = false
    @State private var isTransactionFormPresented = false
    @State private var selectedTransaction: BudgetTransaction?
    @State private var transactionPendingDeletion: BudgetTransaction?
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeleteErrorPresented = false
    private let showsTitle: Bool
    public let budget: Budget
    public let isEditingUnlocked: Bool
    public let onAddTransaction: (ValidatedBudgetTransactionInput) throws -> Void
    public let onUpdateTransaction: (UUID, ValidatedBudgetTransactionInput) throws -> Void
    public let onDeleteTransaction: (UUID) throws -> Void
    public let onAddFixedExpensePlan: (ValidatedFixedExpensePlanInput) throws -> Void
    public let onUpdateFixedExpensePlan: (UUID, ValidatedFixedExpensePlanInput) throws -> Void
    public let onDeleteFixedExpensePlan: (UUID) throws -> Void
    public let onCompleteFixedExpensePlan: (UUID, ValidatedBudgetTransactionInput) throws -> Void

    private var isExpandAllTransaction: Bool {
        !transactionGroups.isEmpty &&
        transactionGroups.allSatisfy { expandedTransactionGroupDates.contains($0.date) }
    }

    public init(
        budget: Budget,
        isEditingUnlocked: Bool,
        showsTitle: Bool = true,
        onAddTransaction: @escaping (ValidatedBudgetTransactionInput) throws -> Void,
        onUpdateTransaction: @escaping (UUID, ValidatedBudgetTransactionInput) throws -> Void,
        onDeleteTransaction: @escaping (UUID) throws -> Void,
        onAddFixedExpensePlan: @escaping (ValidatedFixedExpensePlanInput) throws -> Void,
        onUpdateFixedExpensePlan: @escaping (UUID, ValidatedFixedExpensePlanInput) throws -> Void,
        onDeleteFixedExpensePlan: @escaping (UUID) throws -> Void,
        onCompleteFixedExpensePlan: @escaping (UUID, ValidatedBudgetTransactionInput) throws -> Void
    ) {
        self.budget = budget
        self.isEditingUnlocked = isEditingUnlocked
        self.showsTitle = showsTitle
        self.onAddTransaction = onAddTransaction
        self.onUpdateTransaction = onUpdateTransaction
        self.onDeleteTransaction = onDeleteTransaction
        self.onAddFixedExpensePlan = onAddFixedExpensePlan
        self.onUpdateFixedExpensePlan = onUpdateFixedExpensePlan
        self.onDeleteFixedExpensePlan = onDeleteFixedExpensePlan
        self.onCompleteFixedExpensePlan = onCompleteFixedExpensePlan
    }

    private var transactionGroups: [TransactionGroup] {
        return Dictionary(grouping: budget.transactions) {
            Calendar.current.startOfDay(for: $0.occurredAt)
        }
        .map { date, transactions in
            TransactionGroup(
                date: date,
                transactions: transactions.sorted { $0.occurredAt > $1.occurredAt },
                isEditingUnlocked: isEditingUnlocked
            )
        }
        .sorted { $0.date > $1.date }
    }

    @State private var expandedTransactionGroupDates: Set<Date> = []
    
    @ViewBuilder
    public var body: some View {
        budgetBody(budget)
    }

    private func budgetBody(_ budget: Budget) -> some View {
        BaseScreen(showsTitle ? $title : .constant("")) {
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
            // MARK: - Make default toggle all transaction groups
            expandedTransactionGroupDates = Set(transactionGroups.map(\.date))
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
                    onSave: addTransaction
                )
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack {
                TransactionFormView(
                    allocations: budget.allocations,
                    initialState: TransactionFormState(transaction: transaction),
                    titleKey: "transaction.form.edit.title",
                    onSave: { input in
                        try onUpdateTransaction(transaction.id, input)
                    },
                    onDelete: {
                        try onDeleteTransaction(transaction.id)
                    }
                )
            }
        }
        .onChange(of: transactionPendingDeletion) { _, newValue in
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
            transactionPendingDeletion = nil
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

private extension BudgetContentView {
    public func toggleTransactionGroupsExpansion() {
        if isExpandAllTransaction {
            expandedTransactionGroupDates.removeAll()
        } else {
            expandedTransactionGroupDates = Set(transactionGroups.map(\.date))
        }
    }

    @ViewBuilder
    public var content: some View {
        if segmentOption == .bucket {
            BudgetAllocationListView(budget: budget)
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
                        isExpand: expandedState(for: group.date),
                        selectedTransaction: $selectedTransaction,
                        transactionPendingDeletion: $transactionPendingDeletion
                    )
                }
                .padding()
            }
        }
    }

    public func expandedState(for date: Date) -> Binding<Bool> {
        Binding {
            expandedTransactionGroupDates.contains(date)
        } set: { isExpanded in
            if isExpanded {
                expandedTransactionGroupDates.insert(date)
            } else {
                expandedTransactionGroupDates.remove(date)
            }
        }
    }

    public func addFixedExpensePlan(_ input: ValidatedFixedExpensePlanInput) throws {
        try onAddFixedExpensePlan(input)
    }

    public func updateFixedExpensePlan(planID: UUID, input: ValidatedFixedExpensePlanInput) throws {
        try onUpdateFixedExpensePlan(planID, input)
    }

    public func deleteFixedExpensePlan(_ planID: UUID) throws {
        try onDeleteFixedExpensePlan(planID)
    }

    public func completeFixedExpensePlan(planID: UUID, input: ValidatedBudgetTransactionInput) throws {
        try onCompleteFixedExpensePlan(planID, input)
    }

    public func addTransaction(_ input: ValidatedBudgetTransactionInput) throws {
        try onAddTransaction(input)
    }

    public func deletePendingTransaction() {
        guard let transactionPendingDeletion else { return }
        do {
            try onDeleteTransaction(transactionPendingDeletion.id)
            self.transactionPendingDeletion = nil
        } catch {
            self.transactionPendingDeletion = nil
            isDeleteErrorPresented = true
        }
    }
}

public extension BudgetContentView {
    struct TransactionGroup: Identifiable {
        let date: Date
        let transactions: [BudgetTransaction]
        let isEditingUnlocked: Bool
        public var id: Date { date }
    }

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
