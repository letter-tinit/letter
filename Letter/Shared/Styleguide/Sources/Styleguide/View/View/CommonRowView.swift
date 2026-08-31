//
//  CommonRowView.swift
//  Letter
//
//  Created by TiniT on 13/7/26.
//

import SwiftUI
import Domain
import Utility

public struct CommonRowView<Content: View>: View {
    private let model: Model
    private let content: (() -> Content)?
    
    public init(
        _ model: Model,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.model = model
        self.content = content
    }

    public var body: some View {
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
    public struct Model {
        public let title: String
        public var value: String = ""
        public var isHighlight: Bool = false
        public var highlightColor: Color = .accentColor
        public init(title: String, value: String = "", isHighlight: Bool = false, highlightColor: Color = .accentColor) { self.title=title; self.value=value; self.isHighlight=isHighlight; self.highlightColor=highlightColor }
    }
}

extension CommonRowView where Content == EmptyView {
    public init(_ model: Model) {
        self.model = model
        self.content = nil
    }
}
