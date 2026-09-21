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
    @Environment(NetWorthViewModel.self) private var netWorthViewModel
    @Bindable public var netWorth: NetWorthPresentationModel
    @State private var isItemFormPresented = false
    @State private var selectedItem: NetWorthItemPresentationModel?
    
    public let statusMessage: String?
    
    public init(
        netWorth: NetWorthPresentationModel,
        statusMessage: String?
    ) {
        self.netWorth = netWorth
        self.statusMessage = statusMessage
    }
    
    public var body: some View {
        BaseScreen {
            VStack {
                NetWorthCardView(
                    amount: netWorth.netWorth.formattedVND,
                    missingValueCount: netWorth.missingValueCount
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
                            netWorth: netWorth,
                            onEdit: { item in
                                selectedItem = item
                            }
                        )
                        
                        NetWorthGroupView(
                            group: .liabilities,
                            netWorth: netWorth,
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
                .disabled(!netWorth.isEditingUnlocked)
            }
        }
        .sheet(isPresented: $isItemFormPresented) {
            NavigationStack {
                NetWorthItemFormView()
                    .environment(netWorthViewModel)
            }
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                NetWorthItemFormView(
                    initialState: NetWorthItemFormState(
                        item: item,
                        amount: item.amount
                    ),
                    titleKey: "networth.item.form.edit.title",
                    reuseHelpKey: "networth.item.form.edit.reuse.help",
                    itemID: item.id
                )
                .environment(netWorthViewModel)
            }
        }
    }

}

extension NetWorthContentView {
    public var summary: some View {
        HStack(spacing: 12) {
            NetWorthSummaryView(
                title: "networth.total.assets".localized,
                amount: netWorth.totalAssets,
                tint: .green
            )
            
            NetWorthSummaryView(
                title: "networth.total.liabilities".localized,
                amount: netWorth.totalLiabilities,
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
    @Bindable public var netWorth: NetWorthPresentationModel
    public let onEdit: (NetWorthItemPresentationModel) -> Void
    
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
                    netWorth: netWorth,
                    onEdit: onEdit
                )
            }
            
            Divider()
            
            HStack {
                Text(group.totalLocalizationKey.localized)
                    .customFont(.headline, weight: .semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(netWorth.total(for: group).formattedVND)
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
