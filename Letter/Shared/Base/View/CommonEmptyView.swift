//
//  CommonEmptyView.swift
//  Personal Finance
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
        ContentUnavailableView {
            Label(
                title,
                systemImage: systemImage
            )
        } description: {
            Text(description)
        }
    }
}

#Preview {
    CommonEmptyView()
}
