//
//  BudgetContentView.swift
//  Letter
//
//  Created by TiniT on 9/7/26.
//

import SwiftUI
import SwiftData

struct BudgetContentView: View {
    @State private var title: String = "salary.budget".localized
    @State private var viewModel: BudgetDetailViewModel
    @State private var segmentOption: SegmentOption = .overview
    @State private var isFixedPlanPresented = false
    @State private var isTransactionFormPresented = false
    @State private var selectedTransaction: BudgetTransaction?
    @State private var transactionPendingDeletion: BudgetTransaction?
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeleteErrorPresented = false
    private let showsTitle: Bool

    @Query
    private var observedBudgets: [Budget]

    private var isExpandAllTransaction: Bool {
        !transactionGroups.isEmpty &&
        transactionGroups.allSatisfy { expandedTransactionGroupDates.contains($0.date) }
    }

    private var budget: Budget? {
        observedBudgets.first
    }

    init(_ viewModel: BudgetDetailViewModel, showsTitle: Bool = true) {
        _viewModel = State(initialValue: viewModel)
        self.showsTitle = showsTitle

        let budgetID = viewModel.budget.id
        _observedBudgets = Query(
            filter: #Predicate<Budget> { budget in
                budget.id == budgetID
            }
        )
    }

    private var transactionGroups: [TransactionGroup] {
        guard let budget else { return [] }

        return Dictionary(grouping: budget.transactions) {
            Calendar.current.startOfDay(for: $0.occurredAt)
        }
        .map { date, transactions in
            TransactionGroup(
                date: date,
                transactions: transactions.sorted { $0.occurredAt > $1.occurredAt }
            )
        }
        .sorted { $0.date > $1.date }
    }

    @State private var expandedTransactionGroupDates: Set<Date> = []
    
    @ViewBuilder
    var body: some View {
        if let budget {
            budgetBody(budget)
        }
    }

    private func budgetBody(_ budget: Budget) -> some View {
        BaseScreen(showsTitle ? $title : .constant("")) {
            VStack {
                BudgetIncomeCardView(
                    budget: budget,
                    isExpandAllTransaction: isExpandAllTransaction,
                    onToggleTransactionGroupsExpansion: toggleTransactionGroupsExpansion,
                    isFixedPlanPresented: $isFixedPlanPresented,
                    segmentOption: $segmentOption
                )
                .padding(.horizontal)
                
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
                    onComplete: completeFixedExpensePlan
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
                        viewModel.updateTransaction(transaction, input: input)
                    },
                    onDelete: {
                        viewModel.deleteTransaction(transaction)
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
            }
        }
    }
}

private extension BudgetContentView {
    func toggleTransactionGroupsExpansion() {
        if isExpandAllTransaction {
            expandedTransactionGroupDates.removeAll()
        } else {
            expandedTransactionGroupDates = Set(transactionGroups.map(\.date))
        }
    }

    @ViewBuilder
    var content: some View {
        if let budget {
            if segmentOption == .overview {
                BudgetAllocationListView(budget: budget)
            } else {
                groupTransactionList
            }
        }
    }

    @ViewBuilder
    var groupTransactionList: some View {
        if let budget, budget.transactions.isEmpty {
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

    func expandedState(for date: Date) -> Binding<Bool> {
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

    func addFixedExpensePlan(_ input: ValidatedFixedExpensePlanInput) throws {
        viewModel.addFixedExpensePlan(input)
    }

    func updateFixedExpensePlan(planID: UUID, input: ValidatedFixedExpensePlanInput) throws {
        guard let budget,
              let plan = budget.fixedExpensePlans.first(where: { $0.id == planID }) else {
            throw BudgetError.fixedExpensePlanNotFound
        }
        viewModel.updateFixedExpensePlan(plan, input: input)
    }

    func deleteFixedExpensePlan(_ planID: UUID) throws {
        guard let budget,
              let plan = budget.fixedExpensePlans.first(where: { $0.id == planID }) else {
            throw BudgetError.fixedExpensePlanNotFound
        }
        viewModel.deleteFixedExpensePlan(plan)
    }

    func completeFixedExpensePlan(planID: UUID, input: ValidatedBudgetTransactionInput) throws {
        guard let budget,
              let plan = budget.fixedExpensePlans.first(where: { $0.id == planID }) else {
            throw BudgetError.fixedExpensePlanNotFound
        }
        viewModel.completeFixedExpensePlan(plan, input: input)
    }

    func addTransaction(_ input: ValidatedBudgetTransactionInput) throws {
        viewModel.addTransaction(input)
    }

    func deletePendingTransaction() {
        guard let transactionPendingDeletion else { return }
        viewModel.deleteTransaction(transactionPendingDeletion)
        self.transactionPendingDeletion = nil
        if viewModel.toastMessage != nil {
            isDeleteErrorPresented = true
        }
    }
}

extension BudgetContentView {
    struct TransactionGroup: Identifiable {
        let date: Date
        let transactions: [BudgetTransaction]
        var id: Date { date }
    }

    enum SegmentOption: CaseIterable, Hashable {
        case overview
        case transaction

        func displayName(budgetName: String) -> String {
            switch self {
            case .overview:
                budgetName
            case .transaction:
                "budget.segment.transactions".localized
            }
        }
    }
}
