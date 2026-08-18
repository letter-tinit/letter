import SwiftUI

struct HabitStatisticsScreen: View {
    @State private var mode = HabitStatisticsMode.overview

    var body: some View {
        Group {
            switch mode {
            case .overview:
                AggregateStatisticalScreen()
            case .byHabit:
                StatisticalScreen()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Statistics view", selection: $mode) {
                ForEach(HabitStatisticsMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.Common.background)
        }
    }
}

private enum HabitStatisticsMode: String, CaseIterable, Identifiable {
    case overview
    case byHabit

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .byHabit: "By Habit"
        }
    }
}

#Preview {
    HabitStatisticsScreen()
}
