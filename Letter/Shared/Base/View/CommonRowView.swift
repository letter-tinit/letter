//
//  CommonRowView.swift
//  Letter
//
//  Created by TiniT on 13/7/26.
//

import SwiftUI

struct CommonRowView<Content: View>: View {
    private let model: Model
    private let content: (() -> Content)?
    
    init(
        _ model: Model,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.model = model
        self.content = content
    }

    var body: some View {
        HStack {
            Text(model.title)
                .customFont(.subheadline)
            
            Spacer()
            
            if let content {
                content()
            } else {
                Text(model.value)
                    .customFont(.headline, weight: .semibold)
                    .foregroundStyle(model.isHighlight ? model.highlightColor : Color.primary)
            }
        }
    }
}

extension CommonRowView {
    struct Model {
        let title: String
        var value: String = ""
        var isHighlight: Bool = false
        var highlightColor: Color = .accentColor
    }
}

extension CommonRowView where Content == EmptyView {
    init(_ model: Model) {
        self.model = model
        self.content = nil
    }
}
