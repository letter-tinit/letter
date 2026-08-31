//
//  AppPicker.swift
//  Letter
//
//  Created by Codex on 25/8/26.
//

import SwiftUI
import Domain
import Utility

public enum AppPickerLayout {
    /// Places the title at the leading edge and the compact picker at the
    /// trailing edge, matching a picker row in a form or list.
    case labeledRow

    /// Preserves the picker's native layout for segmented, wheel, and menu
    /// contexts.
    case control
}

/// The app-wide picker entry point.
public struct AppPicker<SelectionValue: Hashable, Content: View>: View {
    private let title: String
    private let selection: Binding<SelectionValue>
    private let layout: AppPickerLayout
    private let content: Content

    public init(
        _ title: String,
        selection: Binding<SelectionValue>,
        layout: AppPickerLayout,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.selection = selection
        self.layout = layout
        self.content = content()
    }

    @ViewBuilder
    public var body: some View {
        switch layout {
        case .labeledRow:
            LabeledContent {
                picker
                    .labelsHidden()
            } label: {
                Text(title)
            }
            .labeledContentStyle(AppPickerLabeledContentStyle())

        case .control:
            picker
        }
    }

    private var picker: some View {
        SwiftUI.Picker(title, selection: selection) {
            content
        }
    }
}

private struct AppPickerLabeledContentStyle: LabeledContentStyle {
    public func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer(minLength: 16)

            configuration.content
        }
        .frame(maxWidth: .infinity)
    }
}

@available(*, unavailable, message: "Use AppPicker instead of Picker")
typealias Picker<Label: View, SelectionValue: Hashable, Content: View> =
    SwiftUI.Picker<Label, SelectionValue, Content>
