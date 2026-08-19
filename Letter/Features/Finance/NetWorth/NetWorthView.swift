//
//  NetWorthView.swift
//  Letter
//

import SwiftUI
import SwiftData

/// Displays the Net Worth snapshot for the month selected by `FinanceScreen`.
struct NetWorthView: View {
    @State private var viewModel: NetWorthViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var isDeleteConfirmationPresented = false
    let selectedMonth: FinanceMonth
    
    @Query(sort: \NetWorthSnapshot.asOfDate, order: .reverse)
    private var snapshots: [NetWorthSnapshot]
    @Query(sort: \NetWorthPlanItem.displayOrder)
    private var planItems: [NetWorthPlanItem]
    
    init(_ viewModel: NetWorthViewModel, selectedMonth: FinanceMonth) {
        self.viewModel = viewModel
        self.selectedMonth = selectedMonth
    }

    private var selectedSnapshot: NetWorthSnapshot? {
        snapshots.first {
            Calendar.current.isDate($0.asOfDate, equalTo: selectedMonth.startDate, toGranularity: .month)
        }
    }
    
    var body: some View {
        Group {
            if let selectedSnapshot {
                NetWorthContentView(
                    planItems: planItems,
                    snapshot: selectedSnapshot,
                    isEditingUnlocked: !selectedSnapshot.isLocked,
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
            if let selectedSnapshot {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        selectedSnapshot.isLocked.toggle()
                    } label: {
                        Image(systemName: selectedSnapshot.isLocked ? "lock" : "lock.open")
                    }
                    .accessibilityLabel(
                        selectedSnapshot.isLocked
                        ? "networth.edit.unlock".localized
                        : "networth.edit.lock".localized
                    )
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        Haptic.warning()
                        isDeleteConfirmationPresented = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedSnapshot.isLocked)
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
                modelContext.delete(selectedSnapshot)
                try? modelContext.save()
            }
        }
        .onChange(of: snapshots) {
            viewModel.save()
        }
        .onChange(of: planItems) {
            viewModel.save()
        }
    }
}

#Preview {
    NetWorthView(PreviewHelper.makeNetWorthViewModel(), selectedMonth: FinanceMonth(.now))
        .modelContainer(
            PreviewContainer.shared.container
        )
}
