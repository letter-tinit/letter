//
//  BalanceCardView.swift
//  Letter
//
//  Created by TiniT on 16/7/26.
//

import SwiftUI
import Domain
import Core
import Utility
import Styleguide

public struct BalanceCardView: View {
    @State private var isExpand: Bool = false
    
    public let balance: Balance
    
    public var body: some View {
        VStack(alignment: .leading) {
            VStack {
                HStack {
                    Image(systemName: balance.symbol)
                    
                    Text(balance.name.localized)
                        .customFont(.subheadline, weight: .semibold)
                    
                    Spacer()
                    
                    Button {
                        baseAnimation {
                            Haptic.selection()
                            isExpand.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpand ? 90 : 0))
                    }
                }
                
                Text(balance.displayBalance)
                    .customFont(.title, weight: .bold)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .appGlassEffect(
                        .regular.interactive(),
                        in: .rect(cornerRadius: 8)
                    )
                    .foregroundStyle(balance.color)
            }
            
            if isExpand {
                VStack {
                    let hasInflow = balance.inflow != .zero
                    let hasOutflow = balance.outflow != .zero
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        
                        Text("balance.inflow".localized)
                        
                        Spacer()
                        
                        Text(hasInflow ? "+\(balance.inflow.formattedVND)" : "0₫")
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .appGlassEffect(
                                .regular.interactive(),
                                in: .rect(cornerRadius: 8)
                            )
                            .foregroundStyle(Color.Common.success)
                    }
                    .customFont(.headline, weight: .semibold)
                    
                    HStack {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                        
                        Text("balance.outflow".localized)
                        
                        Spacer()
                        
                        Text(hasOutflow ? "-\(balance.outflow.formattedVND)" : "0₫")
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .appGlassEffect(
                                .regular.interactive(),
                                in: .rect(cornerRadius: 8)
                            )
                            .foregroundStyle(Color.Common.failure)
                    }
                    .customFont(.headline, weight: .semibold)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle(.Glass.blue)
    }
}

