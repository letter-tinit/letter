import SwiftUI
import Domain
import Utility
import Styleguide

public struct MainTabScreen: View {
    @Environment(\.scenePhase) private var scenePhase

    private let factory: AppViewModelFactory
    
    @State private var habitViewModel: HabitViewModel
    @State private var profileViewModel: ProfileViewModel
    @State private var audioBookViewModel: AudioBookViewModel
    @State private var financeLockManager: FinanceLockManager
    @State private var balanceViewModel: BalanceViewModel
    @State private var netWorthViewModel: NetWorthViewModel
    @State private var budgetViewModel: BudgetViewModel
    @State private var habitStatisticsViewModel: HabitStatisticsViewModel
    @State private var selectedTab = LetterTab.audioBook
    
    @State private var habitRouter = HabitRouter()
    @State private var habitStatisticsRouter = HabitStatisticsRouter()
    @State private var profileRouter = ProfileRouter()
    
    @AppStorage(AppLanguage.preferenceKey) private var languageCode = AppLanguage.vietnamese.rawValue
    
    public init(factory: AppViewModelFactory) {
        self.factory = factory
        _habitViewModel = State(initialValue: factory.makeHabitViewModel())
        _profileViewModel = State(initialValue: factory.makeProfileViewModel())
        _audioBookViewModel = State(initialValue: factory.makeAudioBookViewModel())
        _financeLockManager = State(initialValue: factory.makeFinanceLockManager())
        _balanceViewModel = State(initialValue: factory.makeBalanceViewModel())
        _netWorthViewModel = State(initialValue: factory.makeNetWorthViewModel())
        _budgetViewModel = State(initialValue: factory.makeBudgetViewModel())
        _habitStatisticsViewModel = State(initialValue: factory.makeHabitStatisticsViewModel())
    }
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            Group {
                habitTab
                habitStatisticsTab
                audioBookTab
                financeTab
                profileTab
            }
            .tint(.primary)
            .environment(\.topicColor, selectedTab.color)
        }
        .id(languageCode)
        .tint(selectedTab.color)
        .environment(\.locale, (AppLanguage(rawValue: languageCode) ?? .vietnamese).locale)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            if AppLanguage(rawValue: languageCode) == nil {
                languageCode = AppLanguage.vietnamese.rawValue
            }
        }
        .onChange(of: languageCode) { _, _ in habitViewModel.refreshLocalizedText() }
        .onChange(of: selectedTab) { _, _ in Haptic.selection() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                habitViewModel.rescheduleHabitNotifications()
            } else {
                audioBookViewModel.persistPlaybackCheckpoint()
                if phase == .background || !financeLockManager.isAuthenticating {
                    financeLockManager.lock()
                }
            }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch profileViewModel.colorScheme {
        case .light: .light
        case .dark: .dark
        }
    }
    
    private var habitTab: some View {
        AppNavigationStack(path: $habitRouter.path) {
            HabitScreen()
                .environment(habitRouter)
        } destination: { route in
            switch route {
            case .habitDetail(let habitID):
                HabitDetailScreen(
                    viewModel: factory.makeHabitDetailViewModel(habitID: habitID),
                    factory: factory,
                    onHabitsChanged: habitViewModel.fetchHabits
                )
                .environment(habitRouter)
            case .createHabit:
                CreateHabitScreen(
                    viewModel: factory.makeCreateHabitViewModel(mode: .create),
                    onHabitSaved: { _ in habitViewModel.fetchHabits() }
                )
                .environment(habitRouter)
            }
        }
        .environment(habitViewModel)
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
                    netWorthViewModel: netWorthViewModel
                )
            }
        }
        .environment(financeLockManager)
        .tabItem { LetterTab.finance.label }
        .tag(LetterTab.finance)
    }

    private var audioBookTab: some View {
        NavigationStack {
            AudioBookScreen()
        }
        .environment(audioBookViewModel)
        .tabItem { LetterTab.audioBook.label }
        .tag(LetterTab.audioBook)
    }
    
    private var profileTab: some View {
        AppNavigationStack(path: $profileRouter.path) {
            ProfileScreen(
                onDataChanged: habitViewModel.fetchHabits
            )
            .environment(profileRouter)
        } destination: { route in
            switch route {
            case .editProfile: EditProfileView().environment(profileRouter)
            }
        }
        .environment(profileViewModel)
        .environment(financeLockManager)
        .tabItem { LetterTab.profile.label }
        .tag(LetterTab.profile)
    }
}

private enum LetterTab: Hashable {
    case habits
    case habitStatistics
    case audioBook
    case finance
    case profile

    @ViewBuilder
    public var label: some View {
        switch self {
        case .habits:
            Label("habit.tab.title".localized, systemImage: "figure.run")
                .foregroundStyle(.tint)
        case .habitStatistics:
            Label("habit.statistics.title".localized, systemImage: "chart.bar.xaxis")
        case .audioBook:
            Label("audioBook.tab.title".localized, systemImage: "headphones")
        case .finance:
            Label("finance.tab.title".localized, systemImage: "wallet.bifold")
        case .profile:
            Label("profile.tab.title".localized, systemImage: "person.crop.circle")
        }
    }

    public var color: Color {
        switch self {
        case .habits:
            Color.rosePink
        case .habitStatistics:
            Color.royalBlue
        case .audioBook:
            Color.purple
        case .finance:
            Color.sunsetOrange
        case .profile:
            Color.oceanTeal
        }
    }
}

private struct TopicColorKey: EnvironmentKey {
    public static let defaultValue: Color = .primary
}

extension EnvironmentValues {
    public var topicColor: Color {
        get { self[TopicColorKey.self] }
        set { self[TopicColorKey.self] = newValue }
    }
}
