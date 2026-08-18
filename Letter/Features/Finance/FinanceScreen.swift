import SwiftUI
import SwiftData

struct FinanceScreen: View {
    @State private var selectedSection = FinanceSection.budget
    @State private var selectedMonth = Date()

    @Query private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var netWorthSnapshots: [NetWorthSnapshot]

    private let budgetViewModel: BudgetViewModel
    private let balanceViewModel: BalanceViewModel
    private let netWorthViewModel: NetWorthViewModel
    private let makeBudgetDetailViewModel: (Budget) -> BudgetDetailViewModel

    init(
        budgetViewModel: BudgetViewModel,
        balanceViewModel: BalanceViewModel,
        netWorthViewModel: NetWorthViewModel,
        makeBudgetDetailViewModel: @escaping (Budget) -> BudgetDetailViewModel
    ) {
        self.budgetViewModel = budgetViewModel
        self.balanceViewModel = balanceViewModel
        self.netWorthViewModel = netWorthViewModel
        self.makeBudgetDetailViewModel = makeBudgetDetailViewModel
    }

    var body: some View {
        Group {
            switch selectedSection {
            case .budget:
                BudgetView(
                    budgetViewModel,
                    selectedMonth: selectedMonth,
                    makeDetailViewModel: makeBudgetDetailViewModel
                )
            case .balance:
                BalanceView(balanceViewModel, selectedMonth: selectedMonth)
                    .id(selectedMonth.startOfMonth)
            case .netWorth:
                NetWorthView(netWorthViewModel, selectedMonth: selectedMonth)
                    .id(selectedMonth.startOfMonth)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                MonthPickerMenu(
                    selectedMonth: $selectedMonth,
                    months: availableMonths
                )
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("finance.section.title".localized, selection: $selectedSection) {
                ForEach(FinanceSection.allCases) { section in
                    Text(section.title.localized).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(Color.Common.background)
        }
    }

    private var availableMonths: [Date] {
        let dates = transactions.map(\.occurredAt)
            + budgets.map(\.periodStart)
            + netWorthSnapshots.map(\.asOfDate)
        let firstMonth = dates.min()?.startOfMonth ?? Date().startOfMonth
        return firstMonth.generateMonthsTo(to: .now)
    }
}

private enum FinanceSection: String, CaseIterable, Identifiable {
    case budget
    case balance
    case netWorth

    var id: Self { self }

    var title: String {
        switch self {
        case .budget: "salary.budget"
        case .balance: "balance"
        case .netWorth: "networth.tab.title"
        }
    }
}

#Preview {
    let container = AppContainer(inMemory: true)
    FinanceScreen(
        budgetViewModel: container.makeBudgetViewModel(),
        balanceViewModel: container.makeBalanceViewModel(),
        netWorthViewModel: container.makeNetWorthViewModel(),
        makeBudgetDetailViewModel: container.makeBudgetDetailViewModel
    )
    .modelContainer(container.modelContainer)
}
