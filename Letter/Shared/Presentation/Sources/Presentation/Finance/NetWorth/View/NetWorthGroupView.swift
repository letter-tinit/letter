//
//  NetWorthGroupView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 5/10/26.
//

import SwiftUI
import Domain

struct NetWorthGroupView: View {
    @Binding public var group: NetWorthGroupPresentationModel
    public let onEdit: (NetWorthItemPresentationModel) -> Void
    
    public var body: some View {
        let groupName = group.type.localizationKey.localized
        let groupIcon = group.type.localizationKey.localized
        let groupTotal = group.type.totalLocalizationKey.localized
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(groupName, systemImage: groupIcon)
                    .customFont(.headline, weight: .semibold)
                    .foregroundStyle(group.type.tint)
                
                Spacer()
                
                Text("networth.column.value".localized)
                    .customFont(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            ForEach($group.categories, id: \.self) { $category in
                NetWorthSectionView(
                    category: $category,
                    onEdit: onEdit
                )
            }
            
            Divider()
            
            HStack {
                Text(groupTotal)
                    .customFont(.headline, weight: .semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(group.totalAmount.formattedVND)
                    .customFont(.headline, weight: .semibold)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassEffect(
            .regular.interactive().tint(group.type.tint.opacity(0.1)),
            in: .rect(cornerRadius: 20)
        )
        .padding(.horizontal)
    }
}
