//
//  NetWorthYearRow.swift
//  Personal Finance
//
//  Created by TiniT on 24/7/26.
//

import SwiftUI

struct NetWorthYearRow: View {
    let data: NetWorthYear
    
    var body: some View {
        HStack {
            Text(String(data.year))
                .font(.headline)
            
            Spacer()
            
            Text(
                String(
                    format: "networth.year.monthCount".localized,
                    locale: .current,
                    data.snapshots.filter({ !$0.isGhoshSnapshot() }).count
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}
