//
//  NetWorthContentView.swift
//  Letter
//
//  Created by TiniT on 15/7/26.
//

import SwiftUI

struct NetWorthContentView: View {
    let planItems: [NetWorthPlanItem]
    let selectedSnapshot: NetWorthSnapshot
    @State private var isItemFormPresented = false
    @State private var selectedItem: NetWorthPlanItem?
    @State private var isEditingUnlocked = false
    
    let statusMessage: String?
    let onAddItem: (ValidatedNetWorthItemInput) throws -> Void
    let onUpdateItem: (NetWorthPlanItem, ValidatedNetWorthItemInput) throws -> Void
    let onDeleteItem: (NetWorthPlanItem) throws -> Void

    init(
        planItems: [NetWorthPlanItem],
        snapshot: NetWorthSnapshot,
        statusMessage: String?,
        onAddItem: @escaping (ValidatedNetWorthItemInput) throws -> Void,
        onUpdateItem: @escaping (NetWorthPlanItem, ValidatedNetWorthItemInput) throws -> Void,
        onDeleteItem: @escaping (NetWorthPlanItem) throws -> Void
    ) {
        self.planItems = planItems
        self.selectedSnapshot = snapshot
        self.statusMessage = statusMessage
        self.onAddItem = onAddItem
        self.onUpdateItem = onUpdateItem
        self.onDeleteItem = onDeleteItem
    }

    private var missingValueCount: Int {
        selectedSnapshot.missingValueCount(using: planItems)
    }

    var body: some View {
        BaseScreen {
            AppScrollView(.vertical) {
                VStack(spacing: 16) {
                    header
                    
                    summary

                    if let statusMessage {
                        Label(statusMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.Common.failure)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    NetWorthGroupView(
                        group: .assets,
                        snapshot: selectedSnapshot,
                        planItems: planItems,
                        isEditingUnlocked: isEditingUnlocked,
                        onEdit: { item in
                            selectedItem = item
                        }
                    )

                    NetWorthGroupView(
                        group: .liabilities,
                        snapshot: selectedSnapshot,
                        planItems: planItems,
                        isEditingUnlocked: isEditingUnlocked,
                        onEdit: { item in
                            selectedItem = item
                        }
                    )
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isEditingUnlocked.toggle()
                } label: {
                    Image(systemName: isEditingUnlocked ? "lock.open" : "lock")
                }
                .accessibilityLabel(
                    isEditingUnlocked
                        ? "networth.edit.lock".localized
                        : "networth.edit.unlock".localized
                )
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isItemFormPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("networth.item.form.add".localized)
                .disabled(!isEditingUnlocked)
            }
        }
        .sheet(isPresented: $isItemFormPresented) {
            NavigationStack {
                NetWorthItemFormView(onSave: addItem)
            }
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                NetWorthItemFormView(
                    initialState: NetWorthItemFormState(
                        item: item,
                        amount: selectedSnapshot.amount(for: item)
                    ),
                    titleKey: "networth.item.form.edit.title",
                    reuseHelpKey: "networth.item.form.edit.reuse.help",
                    onSave: { input in
                        try updateItem(itemID: item.id, input: input)
                    },
                    onDelete: {
                        try deleteItem(itemID: item.id)
                    }
                )
            }
        }
    }
}

private extension NetWorthContentView {
    func addItem(_ input: ValidatedNetWorthItemInput) throws {
        try onAddItem(input)
    }

    func updateItem(
        itemID: UUID,
        input: ValidatedNetWorthItemInput
    ) throws {
        guard let item = planItems.first(where: { $0.id == itemID }) else { return }
        try onUpdateItem(item, input)
    }

    func deleteItem(itemID: UUID) throws {
        guard let item = planItems.first(where: { $0.id == itemID }) else { return }
        try onDeleteItem(item)
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("networth.screen.title".localized)
                        .customHeadline()
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
                
            }
            
            Divider()

            Text("networth.total".localized)
                .customSubHeadline()
                .foregroundStyle(.secondary)

            Text(selectedSnapshot.netWorth(using: planItems).formattedVND)
                .customTitle()
                .foregroundStyle(.primary)

            if missingValueCount > 0 {
                Label(
                    String(
                        format: "networth.missing.count".localized,
                        locale: .current,
                        missingValueCount
                    ),
                    systemImage: "exclamationmark.circle.fill"
                )
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .borderedBackground(
            linearGradient: LinearGradient(
                colors: [Color.Common.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            cornerRadius: 20
        )
    }

    var summary: some View {
        HStack(spacing: 12) {
            NetWorthSummaryView(
                title: "networth.total.assets".localized,
                amount: selectedSnapshot.total(for: .assets, using: planItems),
                tint: .green
            )

            NetWorthSummaryView(
                title: "networth.total.liabilities".localized,
                amount: selectedSnapshot.total(for: .liabilities, using: planItems),
                tint: .orange
            )
        }
    }
}

private struct NetWorthSummaryView: View {
    let title: String
    let amount: Decimal
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .customSubText()
                .foregroundStyle(.secondary)

            Text(amount.formattedVND)
                .customHeadline()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .borderedBackground(
            fillColor: tint.opacity(0.10),
            borderColor: tint.opacity(0.28),
            cornerRadius: 16
        )
    }
}

private struct NetWorthGroupView: View {
    let group: NetWorthGroup
    let snapshot: NetWorthSnapshot
    let planItems: [NetWorthPlanItem]
    let isEditingUnlocked: Bool
    let onEdit: (NetWorthPlanItem) -> Void
    
    private var categories: [NetWorthCategory] {
        group.categories
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(group.localizationKey.localized, systemImage: group.systemImage)
                    .customHeadline()
                    .foregroundStyle(group.tint)

                Spacer()

                Text("networth.column.value".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Divider()

            ForEach(categories, id: \.self) { category in
                NetWorthSectionView(
                    category: category,
                    items: planItems.filter { $0.category == category }.sorted { $0.displayOrder < $1.displayOrder },
                    snapshot: snapshot,
                    isEditingUnlocked: isEditingUnlocked,
                    onEdit: onEdit
                )
            }

            Divider()

            HStack {
                Text(group.totalLocalizationKey.localized)
                    .customHeadline()
                    .foregroundStyle(.primary)

                Spacer()

                Text(snapshot.total(for: group, using: planItems).formattedVND)
                    .customHeadline()
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .borderedBackground(
            fillColor: Color.Common.background,
            borderColor: group.tint.opacity(0.25),
            cornerRadius: 20
        )
    }
}
