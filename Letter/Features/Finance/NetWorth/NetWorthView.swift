//
//  NetWorthView.swift
//  Letter
//

import SwiftUI
import SwiftData

/// Displays the Net Worth snapshot for the month selected by `FinanceScreen`.
struct NetWorthView: View {
    @State private var viewModel: NetWorthViewModel
    let selectedMonth: Date
    
    @Query(
        sort: \NetWorthYear.year,
        order: .reverse
    )
    private var netWorthYears: [NetWorthYear]
    
    init(_ viewModel: NetWorthViewModel, selectedMonth: Date) {
        self.viewModel = viewModel
        self.selectedMonth = selectedMonth
    }

    private var selectedYear: NetWorthYear? {
        let year = Calendar.current.component(.year, from: selectedMonth)
        return netWorthYears.first { $0.year == year }
    }

    private var selectedSnapshot: NetWorthSnapshot? {
        selectedYear?.snapshots.first {
            Calendar.current.isDate($0.asOfDate, equalTo: selectedMonth, toGranularity: .month)
        }
    }
    
    var body: some View {
        Group {
            if let selectedYear, let selectedSnapshot {
                NetWorthContentView(
                    year: selectedYear,
                    snapshot: selectedSnapshot,
                    statusMessage: nil,
                    onDeleteItem: { try selectedYear.removeItem(id: $0) }
                )
            } else {
                BaseScreen {
                    CommonEmptyView(
                        "networth.list.empty".localized,
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: "networth.list.empty.description".localized
                    )
                }
            }
        }
        .toolbar {
            if selectedYear == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.createNetWorthYear(
                            Calendar.current.component(.year, from: selectedMonth)
                        )
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .toast(message: viewModel.toastMessage, position: .top)
        .onChange(of: netWorthYears) {
            viewModel.save()
        }
    }
}

#Preview {
    NetWorthView(PreviewHelper.makeNetWorthViewModel(), selectedMonth: .now)
        .modelContainer(
            PreviewContainer.shared.container
        )
}
