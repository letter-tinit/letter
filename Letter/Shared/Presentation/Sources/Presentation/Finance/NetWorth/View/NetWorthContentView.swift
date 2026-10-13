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
    @Environment(NetWorthViewModel.self) private var viewModel
    
    public var body: some View {
        @Bindable var viewModel = viewModel
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
                            groupType: .assets,
                            categories: $netWorth.assets,
                            isLocked: $netWorth.isLocked
                        )
                        
                        NetWorthGroupView(
                            groupType: .liabilities,
                            categories: $netWorth.liabilities,
                            isLocked: $netWorth.isLocked
                        )
                    }
                    .padding(.vertical)
                }
            }
        }
        .sheet(isPresented: $viewModel.isEditing) {
            NavigationStack {
                if let itemEditing = viewModel.itemEditing {
                    NetWorthItemFormView(itemEditing)
                }
            }
            .environment(viewModel)
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
