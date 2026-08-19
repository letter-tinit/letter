import SwiftUI

struct BudgetView: View {
    @State private var viewModel: BudgetViewModel
    @State private var isCreateBudgetPresented = false
    @State private var isDeleteConfirmationPresented = false

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
            if selectedBudget != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        Label("common.delete".localized, systemImage: "trash")
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
