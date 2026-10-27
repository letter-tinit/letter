//
//  CommonEmptyView.swift
//  Letter
//
//  Created by TiniT on 23/7/26.
//

import SwiftUI
import Domain
import Utility

public struct CommonEmptyView<Action: View>: View {
    let title: String
    let systemImage: String
    let description: String?
    @ViewBuilder
    let action: Action
    
    public init(
        _ title: String = "common.empty.title".localized,
        systemImage: String = "list.bullet.rectangle",
        description: String? = nil,
        @ViewBuilder action: () -> Action = { EmptyView() }
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.action = action()
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .customFont(size: 38, weight: .medium)
                .foregroundStyle(.secondary)
            
            Text(title)
                .customFont(.headline, weight: .semibold)
                .multilineTextAlignment(.center)
            
            if let description {
                Text(description)
                    .customFont(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let description {
                Text(description)
                    .customFont(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            action
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CommonEmptyView()
}
