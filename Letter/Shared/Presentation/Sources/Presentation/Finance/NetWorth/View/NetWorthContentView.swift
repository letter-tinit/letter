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
    @Bindable public var netWorth: NetWorthPresentationModel
    
    // MARK: Private Variables
    @Environment(NetWorthViewModel.self) private var netWorthViewModel
    @State private var isItemFormPresented = false
    @State private var selectedItem: NetWorthItemPresentationModel?
    
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

private extension NetWorthContentView {
    var summary: some View {
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
