//
//  NetWorthGroupView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 5/10/26.
//

import SwiftUI
import Domain

struct NetWorthGroupView: View {
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
