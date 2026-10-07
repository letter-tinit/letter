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
    @Binding public var netWorth: NetWorthPresentationModel
    
    // MARK: Private Variables
    @Environment(NetWorthViewModel.self) private var netWorthViewModel
    
    public var body: some View {
        @Bindable var viewModel = netWorthViewModel
        BaseScreen {
            VStack {
                NetWorthCardView(
                    amount: netWorth.netWorth.formattedVND,
                    missingItemCount: netWorth.missingItemCount
                )
                .padding(.horizontal)
                .padding(.top)
                
                AppScrollView(.vertical) {
                    VStack(spacing: 16) {
                        summary
                            .padding(.horizontal)
                        
                        NetWorthGroupView(
                            name: "networth.group.assets".localized,
                            iconName: "building.columns",
                            tint: .green,
                            categories: $netWorth.assets
                        )
                        
                        NetWorthGroupView(
                            name: "networth.group.liabilities".localized,
                            iconName: "creditcard",
                            tint: .orange,
                            categories: $netWorth.liabilities
                        )
                    }
                    .padding(.vertical)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.presentEditForm()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("networth.item.form.add".localized)
                .disabled(netWorth.isLocked)
            }
        }
        .sheet(isPresented: $viewModel.itemFormEditing) {
            NavigationStack {
                NetWorthItemFormView()
                    .environment(viewModel)
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
