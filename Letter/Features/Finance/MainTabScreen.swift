//
//  FinanceMainScreen.swift
//  Personal Finance
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI

typealias MainTabFactory = AppViewModelFactory

struct FinanceMainScreen: View {
    private let factory: MainTabFactory
    
    // MARK: - Bindable
    @State private var balanceViewModel: BalanceViewModel
    @State private var netWorthViewModel: NetWorthViewModel
    @State private var budgetViewModel: BudgetViewModel
    @State private var selectedTab: AppTab = .balance
    
    // MARK: - AppStorage
    @AppStorage(AppLanguage.preferenceKey) private var languageCode = AppLanguage.system.rawValue
    
    // MARK: - Router
    @State private var balanceRouter = BalanceRouter()
    @State private var netWorthRouter = NetWorthRouter()
    @State private var budgetRouter = BudgetRouter()
    @State private var profileRouter = FinanceProfileRouter()
    
    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }
    
    // MARK: - Init
    init(factory: MainTabFactory) {
        self.factory = factory
        _balanceViewModel = State(initialValue: factory.makeBalanceViewModel())
        _netWorthViewModel = State(initialValue: factory.makeNetWorthViewModel())
        _budgetViewModel = State(initialValue: factory.makeBudgetViewModel())
    }
    
    // MARK: - View
    var body: some View {
        TabView(selection: $selectedTab) {
            balanceTab
            netWorthTab
            budgetTab
            profileTab
        }
        .id(languageCode)
        .tint(.primary)
        .environment(\.locale, selectedLanguage.locale)
    }

    private var balanceTab: some View {
        AppNavigationStack(path: $balanceRouter.path) {
            BalanceScreen(balanceViewModel)
                .environment(balanceRouter)
        } destination: { _ in
        }
        .tabItem { tabLabel(.balance) }
        .tag(AppTab.balance)
    }

    private var netWorthTab: some View {
        AppNavigationStack(path: $netWorthRouter.path) {
            NetWorthListScreen(netWorthViewModel)
                .environment(netWorthRouter)
        } destination: { route in
            switch route {
            case .yearNetworth(let data):
                NetWorthYearScreen(data: data)
            }
        }
        .tabItem { tabLabel(.netWorth) }
        .tag(AppTab.netWorth)
    }

    private var budgetTab: some View {
        AppNavigationStack(path: $budgetRouter.path) {
            BudgetListScreen(budgetViewModel)
                .environment(budgetRouter)
        } destination: { route in
            switch route {
            case .budget(let budget):
                BudgetDetailScreen(factory.makeBudgetDetailViewModel(budget: budget))
            }
        }
        .tabItem { tabLabel(.budget) }
        .tag(AppTab.budget)
    }

    private var profileTab: some View {
        AppNavigationStack(path: $profileRouter.path) {
            FinanceProfileScreen(factory: factory)
                .environment(profileRouter)
        } destination: { _ in }
        .tabItem { tabLabel(.profile) }
        .tag(AppTab.profile)
    }

    private func tabLabel(_ tab: AppTab) -> some View {
        Label(tab.name.localized, systemImage: tab.icon)
    }
}

// MARK: - Tab Enum
private enum AppTab: Hashable {
    case balance
    case netWorth
    case budget
    case profile
    
    var name: String {
        switch self {
        case .balance:
            "balance"
        case .netWorth:
            "networth.tab.title"
        case .budget:
            "salary.budget"
        case .profile:
            "profile.tab.title"
        }
    }
    
    var icon: String {
        switch self {
        case .balance:
            "banknote"
        case .netWorth:
            "chart.bar.xaxis"
        case .budget:
            "wallet.bifold"
        case .profile:
            "person.crop.circle"
        }
    }
}

import SwiftData
#Preview {
    let container = AppContainer(inMemory: true)
    
    FinanceMainScreen(factory: container)
        .modelContainer(container.modelContainer)
}
