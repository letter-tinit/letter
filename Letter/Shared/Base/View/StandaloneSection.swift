//
//  StandaloneSection.swift
//  Letter
//
//  Created by Tín Nguyễn on 21/8/26.
//

import SwiftUI

struct StandaloneSection<Content: View>: View {
    @Environment(\.defaultMinListRowHeight) private var defaultMinRowHeight

    private let title: String?
    private let footer: String?
    private let footerColor: Color
    private let layout: Layout
    private let content: () -> Content
    
    init(
        _ title: String? = nil,
        footer: String? = nil,
        footerColor: Color = .secondary,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.footerColor = footerColor
        self.layout = .custom
        self.content = content
    }

    /// Creates a glass section whose direct children are vertically arranged
    /// rows with automatic dividers between them.
    init(
        rows title: String?,
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        footer: String? = nil,
        footerColor: Color = .secondary,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.footerColor = footerColor
        self.layout = .rows(alignment: alignment, spacing: spacing)
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .appSectionHeaderStyle()
                    .padding(.horizontal)
            }
            
            arrangedContent
                .padding()
                .frame(maxWidth: .infinity)
                .appGlassEffect(
                    in: .rect(cornerRadius: 16)
                )
            
            if let footer {
                Text(footer)
                    .appSectionHeaderStyle()
                    .foregroundStyle(footerColor)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }

    @ViewBuilder
    private var arrangedContent: some View {
        switch layout {
        case .custom:
            content()
        case .rows(let alignment, let spacing):
            Group(subviews: content()) { rows in
                VStack(alignment: alignment, spacing: spacing) {
                    ForEach(rows.indices, id: \.self) { index in
                        if index != rows.startIndex {
                            Divider()
                        }
                        rows[index]
                            .frame(minHeight: defaultMinRowHeight)
                    }
                }
            }
        }
    }

    private enum Layout {
        case custom
        case rows(alignment: HorizontalAlignment, spacing: CGFloat?)
    }
}
