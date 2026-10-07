//
//  NetWorthSectionView.swift
//  Letter
//
//  Created by TiniT on 15/7/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct NetWorthSectionView: View {
    @Binding public var category: NetWorthCategoryPresentationModel
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: TODO
            HStack(alignment: .firstTextBaseline) {
                Text(category.type.localizationKey.localized)
                    .customFont(.subheadline, weight: .semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(category.totalAmount.formattedVND)
                    .customFont(.subheadline, weight: .semibold)
                    .foregroundStyle(.secondary)
            }
            
            if category.items.isEmpty {
                Text("networth.category.empty".localized)
                    .customFont(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach($category.items) { $item in
                    NetWorthItemRowView(item: $item, category: category)
                }
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
    }
}
