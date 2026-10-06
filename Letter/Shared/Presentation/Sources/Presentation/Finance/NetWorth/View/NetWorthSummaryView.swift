//
//  NetWorthSummaryView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 5/10/26.
//

import SwiftUI

 struct NetWorthSummaryView: View {
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
