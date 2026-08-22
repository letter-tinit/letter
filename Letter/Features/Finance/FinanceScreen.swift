import SwiftUI
import SwiftData

struct FinanceScreen: View {
    @State private var selectedSection = FinanceSection.budget
    @State private var selectedMonth = FinanceMonth(.now)
    @AppStorage(FinanceSettings.earliestMonthKey) private var earliestMonthTimestamp = FinanceMonth(.now).startDate.timeIntervalSinceReferenceDate
    
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
                    .id(selectedMonth)
            case .netWorth:
                NetWorthView(netWorthViewModel, selectedMonth: selectedMonth)
                    .id(selectedMonth)
            }
        }
        .onChange(of: selectedSection, { _, _ in
            Haptic.selection()
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                MonthPickerMenu(
                    selectedMonth: $selectedMonth,
                    months: availableMonths,
                    monthsWithData: monthsWithData,
                    isUppercase: true
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
            .background(Color.Common.background)
        }
    }
    
    private var availableMonths: [FinanceMonth] {
        let dates = transactions.map(\.occurredAt)
        + budgets.map(\.periodStart)
        + netWorthSnapshots.map(\.asOfDate)
        let earliestMonth = FinanceMonth(
            Date(timeIntervalSinceReferenceDate: earliestMonthTimestamp)
        )
        return FinanceMonthTimeline.months(
            from: dates,
            startingAt: earliestMonth
        )
    }
    
    private var monthsWithData: Set<FinanceMonth> {
        switch selectedSection {
        case .budget:
            return Set(budgets.map { FinanceMonth($0.periodStart) })
        case .balance:
            return Set(transactions.map { FinanceMonth($0.occurredAt) })
        case .netWorth:
            return Set(netWorthSnapshots.map { FinanceMonth($0.asOfDate) })
        }
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
