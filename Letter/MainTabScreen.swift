import SwiftUI
import SwiftData

struct MainTabScreen: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    private let factory: AppViewModelFactory
    
    @State private var balanceViewModel: BalanceViewModel
    @State private var netWorthViewModel: NetWorthViewModel
    @State private var budgetViewModel: BudgetViewModel
    @State private var selectedTab = LetterTab.habits
    
    @State private var habitRouter = HabitRouter()
    @State private var habitStatisticsRouter = HabitStatisticsRouter()
    @State private var balanceRouter = BalanceRouter()
    @State private var netWorthRouter = NetWorthRouter()
    @State private var budgetRouter = BudgetRouter()
    @State private var profileRouter = ProfileRouter()
    
    @AppStorage(AppLanguage.preferenceKey) private var languageCode = AppLanguage.system.rawValue
    
    init(factory: AppViewModelFactory) {
        self.factory = factory
        _balanceViewModel = State(initialValue: factory.makeBalanceViewModel())
        _netWorthViewModel = State(initialValue: factory.makeNetWorthViewModel())
        _budgetViewModel = State(initialValue: factory.makeBudgetViewModel())
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            habitTab
            habitStatisticsTab
            balanceTab
            netWorthTab
            budgetTab
            profileTab
        }
        .id(languageCode)
        .tint(.primary)
        .environment(\.locale, (AppLanguage(rawValue: languageCode) ?? .system).locale)
        .onChange(of: languageCode) { _, _ in habitViewModel.refreshLocalizedText() }
        .onChange(of: selectedTab) { _, _ in Haptic.selection() }
    }
    
    private var habitTab: some View {
        AppNavigationStack(path: $habitRouter.path) {
            HabitScreen().environment(habitRouter)
        } destination: { route in
            switch route {
            case .habitDetail(let habitID):
                HabitDetailView(habitID: habitID).environment(habitRouter)
            case .createHabit:
                CreateHabitView().environment(habitRouter)
            }
        }
        .tabItem { LetterTab.habits.label }
        .tag(LetterTab.habits)
    }
    
    private var habitStatisticsTab: some View {
        AppNavigationStack(path: $habitStatisticsRouter.path) {
            HabitStatisticsScreen()
        } destination: { _ in }
            .tabItem { LetterTab.habitStatistics.label }
            .tag(LetterTab.habitStatistics)
    }
    
    private var balanceTab: some View {
        AppNavigationStack(path: $balanceRouter.path) {
            BalanceScreen(balanceViewModel).environment(balanceRouter)
        } destination: { _ in }
            .tabItem { LetterTab.balance.label }
            .tag(LetterTab.balance)
    }
    
    private var netWorthTab: some View {
        AppNavigationStack(path: $netWorthRouter.path) {
            NetWorthScreen(netWorthViewModel).environment(netWorthRouter)
        } destination: { route in
            switch route {
            case .yearNetworth(let data): NetWorthYearView(data: data)
            }
        }
        .tabItem { LetterTab.netWorth.label }
        .tag(LetterTab.netWorth)
    }
    
    private var budgetTab: some View {
        AppNavigationStack(path: $budgetRouter.path) {
            BudgetScreen(budgetViewModel).environment(budgetRouter)
        } destination: { route in
            switch route {
            case .budget(let budget):
                BudgetDetailView(factory.makeBudgetDetailViewModel(budget: budget))
            }
        }
        .tabItem { LetterTab.budget.label }
        .tag(LetterTab.budget)
    }
    
    private var profileTab: some View {
        AppNavigationStack(path: $profileRouter.path) {
            ProfileScreen(factory: factory).environment(profileRouter)
        } destination: { route in
            switch route {
            case .editProfile: EditProfileView().environment(profileRouter)
            }
        }
        .tabItem { LetterTab.profile.label }
        .tag(LetterTab.profile)
    }
}

private enum LetterTab: Hashable {
    case habits, habitStatistics, balance, netWorth, budget, profile
    
    @ViewBuilder var label: some View {
        switch self {
        case .habits: Label("habit.tab.title".localized, systemImage: "figure.run")
        case .habitStatistics: Label("habit.statistics.title".localized, systemImage: "chart.bar.xaxis")
        case .balance: Label("balance".localized, systemImage: "banknote")
        case .netWorth: Label("networth.tab.title".localized, systemImage: "chart.line.uptrend.xyaxis")
        case .budget: Label("salary.budget".localized, systemImage: "wallet.bifold")
        case .profile: Label("profile.tab.title".localized, systemImage: "person.crop.circle")
        }
    }
}

#Preview {
    let container = AppContainer(inMemory: true)
    MainTabScreen(factory: container)
        .modelContainer(container.modelContainer)
        .environment(container.makeHabitViewModel())
}
