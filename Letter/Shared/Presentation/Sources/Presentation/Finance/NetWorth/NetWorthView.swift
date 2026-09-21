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
                NetWorthContentView(netWorth: netWorth, statusMessage: nil)
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
                        Image(systemName: netWorth.isEditingUnlocked ? "lock.open" : "lock")
                    }
                    .accessibilityLabel(
                        netWorth.isEditingUnlocked
                        ? "networth.edit.lock".localized
                        : "networth.edit.unlock".localized
                    )
                }

                if netWorth.isEditingUnlocked {
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
                        viewModel.createSnapshot(for: selectedMonth.startDate)
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
            viewModel.deleteSelectedSnapshot()
        }
        .task {
            viewModel.load()
            viewModel.selectMonth(selectedMonth)
        }
    }
}
