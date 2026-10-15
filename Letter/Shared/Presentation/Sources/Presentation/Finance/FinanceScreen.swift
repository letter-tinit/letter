import SwiftUI
import Domain
import Utility
import Styleguide

public struct FinanceScreen: View {
    @State private var selectedSection = FinanceSection.budget
    @State private var selectedMonth = FinanceMonth(.now)
    @AppStorage(FinanceSettings.earliestMonthKey) private var earliestMonthTimestamp = FinanceMonth(.now).startDate.timeIntervalSinceReferenceDate
    
    private let budgetViewModel: BudgetViewModel
    private let balanceViewModel: BalanceViewModel
    private let netWorthViewModel: NetWorthViewModel
    
    public init(
        budgetViewModel: BudgetViewModel,
        balanceViewModel: BalanceViewModel,
        netWorthViewModel: NetWorthViewModel
    ) {
        self.budgetViewModel = budgetViewModel
        self.balanceViewModel = balanceViewModel
        self.netWorthViewModel = netWorthViewModel
    }
    
    public var body: some View {
        Group {
            switch selectedSection {
            case .budget:
                BudgetScreen(budgetViewModel, selectedMonth: selectedMonth)
                    .id(selectedMonth)
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
            AppPicker(
                "finance.section.title".localized,
                selection: $selectedSection,
                layout: .control
            ) {
                ForEach(FinanceSection.allCases) { section in
                    Text(section.title.localized).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .background(Color.Common.background)
        }
        .task {
            balanceViewModel.load()
            netWorthViewModel.load()
        }
    }
    
    private var availableMonths: [FinanceMonth] {
        let dates = balanceViewModel.transactions.map(\.occurredAt)
        + netWorthViewModel.financeMonths.map(\.startDate)
        
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
            return Set(
                [
                    FinanceMonth(Date())
                ]
            )
        case .balance:
            return Set(balanceViewModel.transactions.map { FinanceMonth($0.occurredAt) })
        case .netWorth:
            return netWorthViewModel.financeMonths
        }
    }
}

private enum FinanceSection: String, CaseIterable, Identifiable {
    case budget
    case balance
    case netWorth
    
    public var id: Self { self }
    
    public var title: String {
        switch self {
        case .budget : "budget.title"
        case .balance: "balance"
        case .netWorth: "networth.tab.title"
        }
    }
}
