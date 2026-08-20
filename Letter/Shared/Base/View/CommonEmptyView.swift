//
//  CommonEmptyView.swift
//  Letter
//
//  Created by TiniT on 23/7/26.
//

import SwiftUI

struct CommonEmptyView: View {
    let title: String
    let systemImage: String
    let description: String
    
    init(
        _ title: String = "common.empty.title".localized,
        systemImage: String = "list.bullet.rectangle",
        description: String = "common.empty.description".localized,
    ) {
        self.title = title
        self.description = description
        self.systemImage = systemImage
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .customFont(size: 38, weight: .medium)
                .foregroundStyle(.secondary)

            Text(title)
                .customFont(.headline, weight: .semibold)
                .multilineTextAlignment(.center)

            Text(description)
                .customFont(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CommonEmptyView()
}
