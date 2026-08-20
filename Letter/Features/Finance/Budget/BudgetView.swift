import SwiftUI

struct BudgetView: View {
    @State private var viewModel: BudgetViewModel
    @State private var isCreateBudgetPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var budgetPendingDeletion: Budget?
    @State private var budgetPendingDeletionID: UUID?
    @Environment(\.modelContext) private var modelContext
    private var isEditingUnlocked: Bool {
        !isEditingLocked
    }

    private var isEditingLocked: Bool {
        selectedBudget?.isLocked ?? false
    }

    let selectedMonth: FinanceMonth
    let makeDetailViewModel: (Budget) -> BudgetDetailViewModel

    private var selectedBudget: Budget? {
        viewModel.budgets.first {
            $0.id != budgetPendingDeletionID &&
            Calendar.current.isDate($0.periodStart, equalTo: selectedMonth.startDate, toGranularity: .month)
        }
    }

    private var latestBudget: Budget? {
        viewModel.budgets.max { $0.periodStart < $1.periodStart }
    }

    init(
        _ viewModel: BudgetViewModel,
        selectedMonth: FinanceMonth,
        makeDetailViewModel: @escaping (Budget) -> BudgetDetailViewModel
    ) {
        self.viewModel = viewModel
        self.selectedMonth = selectedMonth
        self.makeDetailViewModel = makeDetailViewModel
    }

    var body: some View {
        Group {
            if let selectedBudget {
                BudgetContentView(
                    makeDetailViewModel(selectedBudget),
                    isEditingUnlocked: isEditingUnlocked,
                    showsTitle: false
                )
                .id(selectedBudget.id)
            } else {
                BaseScreen {
                    CommonEmptyView(
                        "budget.list.empty".localized,
                        systemImage: "calendar.badge.plus",
                        description: "budget.list.empty.description".localized
                    )
                }
            }
        }
        .toolbar {
            if selectedBudget != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptic.warning()
                        toggleEditingLock()
                    } label: {
                        Image(systemName: isEditingUnlocked ? "lock.open" : "lock")
                    }
                    .accessibilityLabel(isEditingUnlocked ? "networth.edit.lock".localized : "networth.edit.unlock".localized)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        Haptic.warning()
                        isDeleteConfirmationPresented = true
                } label: {
                    Label("common.delete".localized, systemImage: "trash")
                }
                .disabled(!isEditingUnlocked)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptic.selection()
                        isCreateBudgetPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("budget.create.title".localized)
                    .disabled(!isEditingUnlocked)
                }
            }
        }
        .deleteConfirmationDialog(
            isPresented: $isDeleteConfirmationPresented,
            title: "budget.delete.title".localized,
            message: "common.delete.warning".localized
        ) {
            deleteSelectedBudget()
        }
        .sheet(isPresented: $isCreateBudgetPresented) {
            NavigationStack {
                CreateBudgetView(
                    existingBudgets: viewModel.budgets,
                    templateBudget: latestBudget,
                    initialPeriodStart: selectedMonth.startDate
                )
                .environment(viewModel)
            }
        }
        .toast(message: viewModel.toastMessage)
        .task { viewModel.load() }
        .task(id: budgetPendingDeletionID) {
            guard let pendingID = budgetPendingDeletionID,
                  let budgetPendingDeletion else { return }

            // Let SwiftUI remove BudgetContentView before SwiftData detaches its model.
            await Task.yield()
            guard self.budgetPendingDeletionID == pendingID else { return }

            viewModel.deleteBudget(budgetPendingDeletion)
            self.budgetPendingDeletion = nil
            budgetPendingDeletionID = nil
        }
    }

    private func deleteSelectedBudget() {
        guard let selectedBudget else { return }
        budgetPendingDeletion = selectedBudget
        budgetPendingDeletionID = selectedBudget.id
    }

    private func toggleEditingLock() {
        guard let budget = selectedBudget else { return }
        budget.isLocked.toggle()
        try? modelContext.save()
    }
}

import SwiftData

#Preview {
    let container = AppContainer(inMemory: true)
    BudgetView(
        container.makeBudgetViewModel(),
        selectedMonth: FinanceMonth(.now),
        makeDetailViewModel: container.makeBudgetDetailViewModel
    )
    .modelContainer(container.modelContainer)
}
