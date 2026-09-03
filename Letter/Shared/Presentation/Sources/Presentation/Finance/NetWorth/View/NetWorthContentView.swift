//
//  NetWorthContentView.swift
//  Letter
//
//  Created by TiniT on 15/7/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct NetWorthContentView: View {
    public let planItems: [NetWorthPlanItem]
    public let selectedSnapshot: NetWorthSnapshot
    public let isEditingUnlocked: Bool
    @State private var isItemFormPresented = false
    @State private var selectedItem: NetWorthPlanItem?
    
    public let statusMessage: String?
    public let onAddItem: (ValidatedNetWorthItemInput) throws -> Void
    public let onUpdateItem: (NetWorthPlanItem, ValidatedNetWorthItemInput) throws -> Void
    public let onDeleteItem: (NetWorthPlanItem) throws -> Void
    
    public init(
        planItems: [NetWorthPlanItem],
        snapshot: NetWorthSnapshot,
        isEditingUnlocked: Bool,
        statusMessage: String?,
        onAddItem: @escaping (ValidatedNetWorthItemInput) throws -> Void,
        onUpdateItem: @escaping (NetWorthPlanItem, ValidatedNetWorthItemInput) throws -> Void,
        onDeleteItem: @escaping (NetWorthPlanItem) throws -> Void
    ) {
        self.planItems = planItems
        self.selectedSnapshot = snapshot
        self.isEditingUnlocked = isEditingUnlocked
        self.statusMessage = statusMessage
        self.onAddItem = onAddItem
        self.onUpdateItem = onUpdateItem
        self.onDeleteItem = onDeleteItem
    }
    
    private var missingValueCount: Int {
        selectedSnapshot.missingValueCount(using: planItems)
    }
    
    public var body: some View {
        BaseScreen {
            VStack {
                NetWorthCardView(
                    amount: selectedSnapshot.netWorth(using: planItems).formattedVND,
                    missingValueCount: missingValueCount
                )
                .padding(.horizontal)
                .padding(.top)
                
                AppScrollView(.vertical) {
                    VStack(spacing: 16) {
                        summary
                            .padding(.horizontal)
                        
                        if let statusMessage {
                            Label(statusMessage, systemImage: "exclamationmark.circle.fill")
                                .customFont(.footnote)
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
                    .padding(.vertical)
                }
            }
        }
        .toolbar {
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

extension NetWorthContentView {
    public func addItem(_ input: ValidatedNetWorthItemInput) throws {
        try onAddItem(input)
    }
    
    public func updateItem(
        itemID: UUID,
        input: ValidatedNetWorthItemInput
    ) throws {
        guard let item = planItems.first(where: { $0.id == itemID }) else { return }
        try onUpdateItem(item, input)
    }
    
    public func deleteItem(itemID: UUID) throws {
        guard let item = planItems.first(where: { $0.id == itemID }) else { return }
        try onDeleteItem(item)
    }
    
    public var summary: some View {
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
    public let title: String
    public let amount: Decimal
    public let tint: Color
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .customFont(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(amount.formattedVND)
                .customFont(.headline, weight: .semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .appGlassEffect(
            .regular.interactive().tint(tint.opacity(0.1)),
            in: .rect(cornerRadius: 16)
        )
    }
}

private struct NetWorthGroupView: View {
    public let group: NetWorthGroup
    public let snapshot: NetWorthSnapshot
    public let planItems: [NetWorthPlanItem]
    public let isEditingUnlocked: Bool
    public let onEdit: (NetWorthPlanItem) -> Void
    
    private var categories: [NetWorthCategory] {
        group.categories
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(group.localizationKey.localized, systemImage: group.systemImage)
                    .customFont(.headline, weight: .semibold)
                    .foregroundStyle(group.tint)
                
                Spacer()
                
                Text("networth.column.value".localized)
                    .customFont(.caption, weight: .semibold)
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
                    .customFont(.headline, weight: .semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(snapshot.total(for: group, using: planItems).formattedVND)
                    .customFont(.headline, weight: .semibold)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassEffect(
            .regular.interactive().tint(group.tint.opacity(0.1)),
            in: .rect(cornerRadius: 20)
        )
        .padding(.horizontal)
    }
}
