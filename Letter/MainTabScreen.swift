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
            financeTab
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
    
    private var financeTab: some View {
        NavigationStack {
            FinanceScreen(
                budgetViewModel: budgetViewModel,
                balanceViewModel: balanceViewModel,
                netWorthViewModel: netWorthViewModel,
                makeBudgetDetailViewModel: factory.makeBudgetDetailViewModel
            )
        }
        .tabItem { LetterTab.finance.label }
        .tag(LetterTab.finance)
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
    case habits, habitStatistics, finance, profile
    
    @ViewBuilder var label: some View {
        switch self {
        case .habits: Label("habit.tab.title".localized, systemImage: "figure.run")
        case .habitStatistics: Label("habit.statistics.title".localized, systemImage: "chart.bar.xaxis")
        case .finance: Label("finance.tab.title".localized, systemImage: "wallet.bifold")
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
