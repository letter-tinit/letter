//
//  NetWorthGroupView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 5/10/26.
//

import SwiftUI
import Domain

struct NetWorthGroupView: View {
    let name: String
    let iconName: String
    let tint: Color
    @Binding public var categories: [NetWorthCategoryPresentationModel]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(name, systemImage: iconName)
                    .customFont(.headline, weight: .semibold)
                
                Spacer()
                
                Text(categories.totalAmount.formattedVND)
                    .customFont(.caption, weight: .semibold)
            }
            .foregroundStyle(tint)
            
            Divider()
            
            if categories.isEmpty {
                Label(String(format: "networth.list.group.empty".localized, name), systemImage: "info.circle")
                    .customFont(.caption, weight: .medium)
                    .foregroundStyle(.secondary)
                
            } else {
                ForEach($categories, id: \.self) { $category in
                    NetWorthSectionView(category: $category)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassEffect(
            .regular.interactive().tint(tint.opacity(0.1)),
            in: .rect(cornerRadius: 20)
        )
        .padding(.horizontal)
    }
}
