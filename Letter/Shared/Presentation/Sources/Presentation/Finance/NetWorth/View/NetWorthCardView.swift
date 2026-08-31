//
//  NetWorthCardView.swift
//  Letter
//
//  Created by Tín Nguyễn on 19/8/26.
//

import SwiftUI
import Domain
import Core
import Utility
import Styleguide

public struct NetWorthCardView: View {
    public let amount: String
    public let missingValueCount: Int
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("networth.screen.title".localized)
                    .customFont(.headline, weight: .semibold)
                
                Spacer()
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .customFont(.title2)
                    .accessibilityHidden(true)
            }
            
            Text(amount)
                .customFont(.title, weight: .bold)
            
            if missingValueCount > 0 {
                Label(
                    String(
                        format: "networth.missing.count".localized,
                        locale: .current,
                        missingValueCount
                    ),
                    systemImage: "exclamationmark.circle.fill"
                )
                .customFont(.footnote, weight: .medium)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(.Glass.mint)
    }
}
