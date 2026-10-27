//
//  NetWorthGroupView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 5/10/26.
//

import SwiftUI
import Domain
import Styleguide

struct NetWorthGroupView: View {
    @Environment(NetWorthViewModel.self) private var viewModel
    
    // MARK: - PROPERTY
    let groupType: NetWorthGroupType
    @Binding var categories: [NetWorthCategoryPresentationModel]
    @Binding public var isLocked: Bool
    
    // MARK: - PRIVATE PROPERTY
    private var tint: Color {
        groupType.tint
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(groupType.titleKey.localized, systemImage: groupType.iconName)
                    .customFont(.headline, weight: .semibold)
                
                Spacer()
                
                Button {
                    Haptic.impact()
                    viewModel.itemEditing = .init(category: groupType.defaultCategory)
                    viewModel.isEditing = true
                } label: {
                    LiquidGlassPlusView(padding: 8)
                }
                .accessibilityLabel("networth.item.form.add".localized)
                .opacity(isLocked ? 0 : 1)
            }
            .foregroundStyle(tint)
            
            Divider()
            
            if categories.isEmpty {
                Label(String(format: "networth.list.group.empty".localized, groupType.titleKey.localized), systemImage: "info.circle")
                    .customFont(.caption, weight: .medium)
                    .foregroundStyle(.secondary)
                
            } else {
                ForEach(
                    $categories
                        .sorted { $0.wrappedValue.type.rawValue < $1.wrappedValue.type.rawValue }
                ) { $category in
                    NetWorthSectionView(category: $category)
                }
            }
            
            HStack {
                Text(groupType.totalLabelKey.localized)
                    .customFont(.headline, weight: .semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(categories.totalAmount.formattedVND)
                    .customFont(.headline, weight: .semibold)
                    .foregroundStyle(.primary)
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
