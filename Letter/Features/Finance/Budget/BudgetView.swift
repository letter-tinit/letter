import SwiftUI

struct BudgetView: View {
    @State private var viewModel: BudgetViewModel
    @State private var isCreateBudgetPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var budgetToLock: Budget?

    let selectedMonth: Date
    let makeDetailViewModel: (Budget) -> BudgetDetailViewModel

    private var selectedBudget: Budget? {
        viewModel.budgets.first {
            Calendar.current.isDate($0.periodStart, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var latestBudget: Budget? {
        viewModel.budgets.max { $0.periodStart < $1.periodStart }
    }

    init(
        _ viewModel: BudgetViewModel,
        selectedMonth: Date,
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
            if let selectedBudget {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if !selectedBudget.isLocked {
                            Button {
                                budgetToLock = selectedBudget
                            } label: {
                                Label("common.lock".localized, systemImage: "archivebox")
                            }
                        }

                        Button(role: .destructive) {
                            isDeleteConfirmationPresented = true
                        } label: {
                            Label("common.delete".localized, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreateBudgetPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("budget.create.title".localized)
                }
            }
        }
        .commonConfirmationDialog(
            isPresented: Binding(
                get: { budgetToLock != nil },
                set: { if !$0 { budgetToLock = nil } }
            ),
            title: "budget.lock.title".localized,
            message: "budget.lock.warning".localized,
            actions: [
                ConfirmationDialogAction("common.confirm".localized, role: .destructive) {
                    lockSelectedBudget()
                },
                ConfirmationDialogAction("common.cancel".localized, role: .cancel) {
                    budgetToLock = nil
                }
            ]
        )
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
                    initialPeriodStart: selectedMonth
                )
                .environment(viewModel)
            }
        }
        .toast(message: viewModel.toastMessage)
        .task { viewModel.load() }
    }

    private func lockSelectedBudget() {
        guard let budgetToLock else { return }
        viewModel.lockBudget(budgetToLock)
        self.budgetToLock = nil
    }

    private func deleteSelectedBudget() {
        guard let selectedBudget else { return }
        viewModel.deleteBudget(selectedBudget)
    }
}

import SwiftData

#Preview {
    let container = AppContainer(inMemory: true)
    BudgetView(
        container.makeBudgetViewModel(),
        selectedMonth: .now,
        makeDetailViewModel: container.makeBudgetDetailViewModel
    )
    .modelContainer(container.modelContainer)
}
