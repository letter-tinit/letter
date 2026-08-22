//
//  StandaloneSection.swift
//  Letter
//
//  Created by Tín Nguyễn on 21/8/26.
//

import SwiftUI

struct StandaloneSection<Content: View>: View {
    private let title: String?
    private let content: () -> Content
    
    init(
        _ title: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .appSectionHeaderStyle()
                    .padding(.horizontal)
            }
            
            content()
                .padding()
                .frame(maxWidth: .infinity)
                .appGlassEffect(
                    in: .rect(cornerRadius: 16)
                )
        }
        .padding(.horizontal)
        .padding(.top)
    }
}
