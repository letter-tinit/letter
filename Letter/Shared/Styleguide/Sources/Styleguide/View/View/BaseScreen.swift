//
//  BaseScreen.swift
//  Letter
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI
import Domain
import Utility

public struct BaseScreen<Content: View>: View {
    @Binding private var title: String
    private var content: () -> Content
    private var didTapOnTitle: (() -> Void)?
    
    public init(
        _ title: Binding<String> = .constant(""),
        @ViewBuilder content: @escaping () -> Content,
        didTapOnTitle: (() -> Void)? = nil
    ) {
        self._title = title
        self.content = content
        self.didTapOnTitle = didTapOnTitle
    }
    
    public var body: some View {
        ZStack {
            Color.Common.background
                .ignoresSafeArea()

            content()
        }
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !title.isEmpty {
                ToolbarItem(placement: .principal) {
                    Button {
                        didTapOnTitle?()
                    } label: {
                        Text(title.uppercased())
                            .customFont(.headline, weight: .semibold)
                    }
                    .allowsHitTesting(didTapOnTitle != nil)
                }
            }
        }
        .keyboardDoneButton()
    }
}
