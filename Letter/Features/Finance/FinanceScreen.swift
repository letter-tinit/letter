import SwiftUI

struct FinanceScreen: View {
    @State private var selectedSection = FinanceSection.budget

    private let budgetViewModel: BudgetViewModel
    private let balanceViewModel: BalanceViewModel
    private let netWorthViewModel: NetWorthViewModel

    init(
        budgetViewModel: BudgetViewModel,
        balanceViewModel: BalanceViewModel,
        netWorthViewModel: NetWorthViewModel
    ) {
        self.budgetViewModel = budgetViewModel
        self.balanceViewModel = balanceViewModel
        self.netWorthViewModel = netWorthViewModel
    }

    var body: some View {
        Group {
            switch selectedSection {
            case .budget:
                BudgetView(budgetViewModel)
            case .balance:
                BalanceView(balanceViewModel)
            case .netWorth:
                NetWorthOverviewView(netWorthViewModel)
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

import SwiftData
#Preview {
    let container = AppContainer(inMemory: true)
    FinanceScreen(
        budgetViewModel: container.makeBudgetViewModel(),
        balanceViewModel: container.makeBalanceViewModel(),
        netWorthViewModel: container.makeNetWorthViewModel()
    )
    .environment(FinanceRouter())
    .modelContainer(container.modelContainer)
}
