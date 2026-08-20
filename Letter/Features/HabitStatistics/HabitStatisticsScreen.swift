import SwiftUI

struct HabitStatisticsScreen: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    @State private var mode = HabitStatisticsMode.overview
    @State private var hidesArchivedHabits = true
    @State private var statisticsScope = StatisticsScope.month
    @State private var statisticsDate = Date()

    var body: some View {
        BaseScreen {
            VStack(spacing: 14) {
                StatisticsTableHeaderView(
                    scope: $statisticsScope,
                    date: $statisticsDate
                )
                .padding(.horizontal)
                .padding(.top, 14)

                Group {
                    switch mode {
                    case .overview:
                        HabitStatisticsOverviewView(
                            statisticsScope: statisticsScope,
                            statisticsDate: statisticsDate
                        )
                        .transition(contentTransition)
                    case .byHabit:
                        HabitStatisticsDetailView(
                            statisticsScope: statisticsScope,
                            statisticsDate: statisticsDate,
                            hidesArchivedHabits: $hidesArchivedHabits
                        )
                        .transition(contentTransition)
                    }
                }
                .id(mode)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Menu {
                    Picker("habit.statistics.view".localized, selection: modeBinding) {
                        ForEach(HabitStatisticsMode.allCases) { mode in
                            Label(mode.title.localized, systemImage: mode.systemImage)
                                .tag(mode)
                        }
                    }
                } label: {
                    Text("habit.statistics.title".localized.uppercased())
                        .customFont(.headline, weight: .semibold)
                        .foregroundStyle(.primary)
                }
                .menuStyle(.button)
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .endTapHaptic()
            }

            if mode == .byHabit {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptic.selection()
                        hidesArchivedHabits.toggle()
                    } label: {
                        Image(module: hidesArchivedHabits ? "archivebox.fill" : "archivebox")
                    }
                    .accessibilityLabel(
                        (hidesArchivedHabits
                         ? "habit.statistics.showArchived"
                         : "habit.statistics.hideArchived").localized
                    )
                    .transition(toolbarTransition)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptic.selection()
                        habitViewModel.usesCompactStatisticsView.toggle()
                    } label: {
                        Image(
                            module: habitViewModel.usesCompactStatisticsView
                            ? "rectangle.expand.vertical"
                            : "rectangle.compress.vertical"
                        )
                    }
                    .transition(toolbarTransition)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: mode)
    }

    private var modeBinding: Binding<HabitStatisticsMode> {
        Binding(
            get: { mode },
            set: { newMode in
                guard newMode != mode else { return }
                Haptic.selection()
                withAnimation(.easeInOut(duration: 0.25)) {
                    mode = newMode
                }
            }
        )
    }

    private var contentTransition: AnyTransition {
        .opacity
    }

    private var toolbarTransition: AnyTransition {
        .opacity
    }
}

private enum HabitStatisticsMode: String, CaseIterable, Identifiable {
    case overview
    case byHabit

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "habit.statistics.overview"
        case .byHabit: "habit.statistics.byHabit"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "chart.bar.xaxis"
        case .byHabit: "list.bullet.rectangle"
        }
    }
}

#Preview {
    HabitStatisticsScreen()
}
