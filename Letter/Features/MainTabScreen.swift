import SwiftUI
import SwiftData

struct MainTabScreen: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    private let factory: AppViewModelFactory
    
    @State private var balanceViewModel: BalanceViewModel
    @State private var netWorthViewModel: NetWorthViewModel
    @State private var budgetViewModel: BudgetViewModel
    @State private var habitStatisticsViewModel: HabitStatisticsViewModel
    @State private var selectedTab = LetterTab.habits
    
    @State private var habitRouter = HabitRouter()
    @State private var habitStatisticsRouter = HabitStatisticsRouter()
    @State private var profileRouter = ProfileRouter()
    
    @AppStorage(AppLanguage.preferenceKey) private var languageCode = AppLanguage.vietnamese.rawValue
    
    init(factory: AppViewModelFactory) {
        self.factory = factory
        _balanceViewModel = State(initialValue: factory.makeBalanceViewModel())
        _netWorthViewModel = State(initialValue: factory.makeNetWorthViewModel())
        _budgetViewModel = State(initialValue: factory.makeBudgetViewModel())
        _habitStatisticsViewModel = State(initialValue: factory.makeHabitStatisticsViewModel())
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Group {
                habitTab
                habitStatisticsTab
                financeTab
                profileTab
            }
            .tint(.primary)
            .environment(\.topicColor, selectedTab.color)
        }
        .id(languageCode)
        .tint(selectedTab.color)
        .environment(\.locale, (AppLanguage(rawValue: languageCode) ?? .vietnamese).locale)
        .onAppear {
            if AppLanguage(rawValue: languageCode) == nil {
                languageCode = AppLanguage.vietnamese.rawValue
            }
        }
        .onChange(of: languageCode) { _, _ in habitViewModel.refreshLocalizedText() }
        .onChange(of: selectedTab) { _, _ in Haptic.selection() }
    }
    
    private var habitTab: some View {
        AppNavigationStack(path: $habitRouter.path) {
            HabitScreen()
                .environment(habitRouter)
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
                .environment(habitStatisticsViewModel)
                .onAppear {
                    habitStatisticsViewModel.reload()
                }
        } destination: { _ in }
            .tabItem { LetterTab.habitStatistics.label }
            .tag(LetterTab.habitStatistics)
    }
    
    private var financeTab: some View {
        NavigationStack {
            FinanceAccessGate(isActive: selectedTab == .finance) {
                FinanceScreen(
                    budgetViewModel: budgetViewModel,
                    balanceViewModel: balanceViewModel,
                    netWorthViewModel: netWorthViewModel,
                    makeBudgetDetailViewModel: factory.makeBudgetDetailViewModel
                )
            }
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
    case habits
    case habitStatistics
    case finance
    case profile

    @ViewBuilder
    var label: some View {
        switch self {
        case .habits:
            Label("habit.tab.title".localized, systemImage: "figure.run")
                .foregroundStyle(.tint)
        case .habitStatistics:
            Label("habit.statistics.title".localized, systemImage: "chart.bar.xaxis")
        case .finance:
            Label("finance.tab.title".localized, systemImage: "wallet.bifold")
        case .profile:
            Label("profile.tab.title".localized, systemImage: "person.crop.circle")
        }
    }

    var color: Color {
        switch self {
        case .habits:
            Color.rosePink
        case .habitStatistics:
            Color.royalBlue
        case .finance:
            Color.sunsetOrange
        case .profile:
            Color.oceanTeal
        }
    }
}

private struct TopicColorKey: EnvironmentKey {
    static let defaultValue: Color = .primary
}

extension EnvironmentValues {
    var topicColor: Color {
        get { self[TopicColorKey.self] }
        set { self[TopicColorKey.self] = newValue }
    }
}

#Preview {
    let container = AppContainer(inMemory: true)
    MainTabScreen(factory: container)
        .customFont(.body)
        .modelContainer(container.modelContainer)
        .environment(container.makeHabitViewModel())
        .environment(FinanceLockManager())
}
