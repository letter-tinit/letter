//
//  NetWorthView.swift
//  Letter
//

import SwiftUI
import Domain
import Utility
import Styleguide

/// Displays the Net Worth snapshot for the month selected by `FinanceScreen`.
public struct NetWorthView: View {
    @State private var viewModel: NetWorthViewModel
    @State private var isDeleteConfirmationPresented = false
    public let selectedMonth: FinanceMonth
    
    public init(_ viewModel: NetWorthViewModel, selectedMonth: FinanceMonth) {
        self.viewModel = viewModel
        self.selectedMonth = selectedMonth
    }

    public var body: some View {
        Group {
            if let netWorth = viewModel.netWorth {
                NetWorthContentView(
                    netWorth: Binding(
                        get: { netWorth },
                        set: { viewModel.netWorth = $0 }
                    )
                )
                .environment(viewModel)
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
            if let netWorth = viewModel.netWorth {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptic.selection()
                        viewModel.toggleSelectedSnapshotEditingLock()
                    } label: {
                        Image(systemName: netWorth.isLocked ? "lock.open" : "lock")
                    }
                    .accessibilityLabel(
                        netWorth.isLocked
                        ? "networth.edit.lock".localized
                        : "networth.edit.unlock".localized
                    )
                }

                if netWorth.isLocked {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) {
                            Haptic.warning()
                            isDeleteConfirmationPresented = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            
            if viewModel.netWorth == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // MARK: TODO
                        //                        viewModel.createSnapshot(for: selectedMonth.startDate)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .toast(message: viewModel.toastMessage, position: .top)
        .deleteConfirmationDialog(
            isPresented: $isDeleteConfirmationPresented,
            title: "common.delete".localized,
            message: "common.delete.warning".localized
        ) {
            // MARK: TODO
            //            viewModel.deleteSelectedSnapshot()
        }
        .task {
            viewModel.load()
            viewModel.selectMonth(selectedMonth)
        }
    }
}
