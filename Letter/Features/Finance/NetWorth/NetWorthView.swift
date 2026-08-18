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
    
    @Query(sort: \NetWorthSnapshot.asOfDate, order: .reverse)
    private var snapshots: [NetWorthSnapshot]
    @Query(sort: \NetWorthPlanItem.displayOrder)
    private var planItems: [NetWorthPlanItem]
    
    init(_ viewModel: NetWorthViewModel, selectedMonth: Date) {
        self.viewModel = viewModel
        self.selectedMonth = selectedMonth
    }

    private var selectedSnapshot: NetWorthSnapshot? {
        snapshots.first {
            Calendar.current.isDate($0.asOfDate, equalTo: selectedMonth, toGranularity: .month)
        }
    }
    
    var body: some View {
        Group {
            if let selectedSnapshot {
                NetWorthContentView(
                    planItems: planItems,
                    snapshot: selectedSnapshot,
                    statusMessage: nil,
                    onAddItem: { try viewModel.addItem($0, to: selectedSnapshot, existingItems: planItems) },
                    onUpdateItem: { try viewModel.updateItem($0, input: $1, snapshot: selectedSnapshot, existingItems: planItems) },
                    onDeleteItem: { try viewModel.deleteItem($0) }
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
            if selectedSnapshot == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.createSnapshot(for: selectedMonth)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .toast(message: viewModel.toastMessage, position: .top)
        .onChange(of: snapshots) {
            viewModel.save()
        }
        .onChange(of: planItems) {
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
