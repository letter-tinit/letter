//
//  BalanceCardView.swift
//  Letter
//
//  Created by TiniT on 16/7/26.
//

import SwiftUI

struct BalanceCardView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var isExpand: Bool = false
    
    let balance: Balance
    
    var body: some View {
        Group {
            if verticalSizeClass == .regular {
                VStack(alignment: .leading) {
                    VStack {
                        HStack {
                            Image(systemName: balance.symbol)
                            
                            Text(balance.name.localized)
                                .customSubHeadline()
                            
                            Spacer()
                            
                            Button {
                                baseAnimation {
                                    isExpand.toggle()
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .rotationEffect(.degrees(isExpand ? 90 : 0))
                            }
                        }
                        
                        Text(balance.displayBalance)
                            .customTitle()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .borderedBackground(fillColor: balance.color.opacity(0.5), cornerRadius: 8, lineWidth: 0)
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
                                
                                Text(hasInflow ? "+\(balance.inflow.formattedVND)" : "0 ₫")
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .borderedBackground(fillColor: Color.Common.success.opacity(0.5), cornerRadius: 8, lineWidth: 0)
                            }
                            .customHeadline()
                            
                            HStack {
                                Image(systemName: "chart.line.downtrend.xyaxis")
                                
                                Text("balance.outflow".localized)
                                
                                Spacer()
                                
                                Text(hasOutflow ? "-\(balance.outflow.formattedVND)" : "0 ₫")
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .borderedBackground(fillColor: Color.Common.failure.opacity(0.5), cornerRadius: 8, lineWidth: 0)
                            }
                            .customHeadline()
                        }
                    }
                }
                .foregroundStyle(Color.Common.surface)
                .frame(maxWidth: .infinity)
                .padding()
                .shadow(color: .primary.opacity(0.3), radius: 1, x: 1, y: 1)
                .borderedBackground(
                    linearGradient: LinearGradient(
                        gradient: .Glass.mint,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    cornerRadius: 16,
                    lineWidth: 0
                )
            } else {
                HStack {
                    Image(systemName: balance.symbol)
                    Text(balance.displayBalance)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .frame(width: 200, alignment: .leading)
                .customHeadline()
                .borderedBackground(fillColor: balance.color.opacity(0.5), cornerRadius: 8, lineWidth: 0)
            }
        }
    }
}

#Preview {
    BalanceCardView(balance: .init(transactions: []))
}
