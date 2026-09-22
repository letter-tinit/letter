import SwiftUI
import Domain
import Utility
import Styleguide

public struct HabitStatisticsScreen: View {
    @Environment(HabitStatisticsViewModel.self) private var viewModel
    @State private var model = HabitStatisticsScreenModel()

    public var body: some View {
        BaseScreen {
            VStack(spacing: 0) {
                StatisticsTableHeaderView(
                    scope: $model.scope,
                    date: $model.date,
                    availablePeriods: viewModel.availablePeriods(
                        scope: model.scope,
                        excludingArchived: model.mode == .byHabit && model.hidesArchivedHabits
                    )
                )
                .padding(.horizontal)
                .padding(.top, 14)

                Group {
                    switch model.mode {
                    case .overview:
                        HabitStatisticsOverviewView(
                            model: $model
                        )
                        .transition(contentTransition)
                    case .byHabit:
                        HabitStatisticsDetailView(
                            model: $model
                        )
                        .transition(contentTransition)
                    }
                }
                .id(model.mode)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Menu {
                    AppPicker(
                        "habit.statistics.view".localized,
                        selection: $model.mode,
                        layout: .control
                    ) {
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

            if model.mode == .byHabit {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptic.selection()
                        model.hidesArchivedHabits.toggle()
                    } label: {
                        Image(module: model.hidesArchivedHabits ? "archivebox.fill" : "archivebox")
                    }
                    .accessibilityLabel(
                        (model.hidesArchivedHabits
                         ? "habit.statistics.showArchived"
                         : "habit.statistics.hideArchived").localized
                    )
                    .transition(toolbarTransition)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptic.selection()
                        viewModel.toggleCompactStatisticsView()
                    } label: {
                        Image(
                            module: viewModel.usesCompactStatisticsView
                            ? "rectangle.expand.vertical"
                            : "rectangle.compress.vertical"
                        )
                    }
                    .transition(toolbarTransition)
                }
            }
        }
        .onChange(of: model.mode) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Haptic.selection()
        }
        .animation(.easeInOut(duration: 0.25), value: model.mode)
    }

    private var contentTransition: AnyTransition {
        .opacity
    }

    private var toolbarTransition: AnyTransition {
        .opacity
    }
}

struct HabitStatisticsScreenModel {
    var mode = HabitStatisticsMode.overview
    var hidesArchivedHabits = true
    var scope = StatisticsScope.month
    var date = Date()
}

enum HabitStatisticsMode: String, CaseIterable, Identifiable {
    case overview
    case byHabit

    public var id: Self { self }

    public var title: String {
        switch self {
        case .overview: "habit.statistics.overview"
        case .byHabit: "habit.statistics.byHabit"
        }
    }

    public var systemImage: String {
        switch self {
        case .overview: "chart.bar.xaxis"
        case .byHabit: "list.bullet.rectangle"
        }
    }
}
