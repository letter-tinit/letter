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

    private var selectedSnapshot: NetWorthSnapshot? {
        viewModel.snapshots.first {
            Calendar.current.isDate($0.asOfDate, equalTo: selectedMonth.startDate, toGranularity: .month)
        }
    }
    
    public var body: some View {
        Group {
            if let selectedSnapshot {
                NetWorthContentView(
                    planItems: viewModel.planItems,
                    snapshot: selectedSnapshot,
                    isEditingUnlocked: !selectedSnapshot.isLocked,
                    statusMessage: nil,
                    onAddItem: { try viewModel.addItem($0, to: selectedSnapshot, existingItems: viewModel.planItems) },
                    onUpdateItem: { try viewModel.updateItem($0, input: $1, snapshot: selectedSnapshot, existingItems: viewModel.planItems) },
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
            if let selectedSnapshot {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptic.selection()
                        viewModel.toggleEditingLock(for: selectedSnapshot)
                    } label: {
                        Image(systemName: selectedSnapshot.isLocked ? "lock" : "lock.open")
                    }
                    .accessibilityLabel(
                        selectedSnapshot.isLocked
                        ? "networth.edit.unlock".localized
                        : "networth.edit.lock".localized
                    )
                }

                if !selectedSnapshot.isLocked {
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
            
            if selectedSnapshot == nil {
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
            if let selectedSnapshot {
                viewModel.deleteSnapshot(selectedSnapshot)
            }
        }
        .task { viewModel.load() }
    }
}

