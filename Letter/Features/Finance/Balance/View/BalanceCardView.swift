//
//  BalanceCardView.swift
//  Letter
//
//  Created by TiniT on 16/7/26.
//

import SwiftUI

struct BalanceCardView: View {
    @State private var isExpand: Bool = false
    
    let balance: Balance
    
    var body: some View {
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
                        .regular.interactive().tint(balance.color.opacity(0.7)),
                        in: .rect(cornerRadius: 8)
                    )
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
                                .regular.interactive().tint(balance.color.opacity(0.7)),
                                in: .rect(cornerRadius: 8)
                            )
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
                                .regular.interactive().tint(balance.color.opacity(0.7)),
                                in: .rect(cornerRadius: 8)
                            )
                    }
                    .customFont(.headline, weight: .semibold)
                }
            }
        }
        .foregroundStyle(Color.Common.surface)
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle(.Glass.mint)
    }
}

#Preview {
    BalanceCardView(balance: .init(transactions: []))
}
