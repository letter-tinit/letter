//
//  CalendarPickerSheetView.swift
//  Letter
//

import SwiftUI
import Utility

public struct CalendarPickerSheetView: View {
    public let title: String
    public var minimumDate: Date?
    public var clearTitle: String?
    public var onDone: (() -> Void)?
    public var onClear: (() -> Void)?

    @Binding private var selectedDate: Date
    @State private var draftDate: Date
    @Environment(\.dismiss) private var dismiss

    public init(
        title: String,
        selectedDate: Binding<Date>,
        minimumDate: Date? = nil,
        clearTitle: String? = nil,
        onDone: (() -> Void)? = nil,
        onClear: (() -> Void)? = nil
    ) {
        self.title = title
        _selectedDate = selectedDate
        _draftDate = State(initialValue: selectedDate.wrappedValue)
        self.minimumDate = minimumDate
        self.clearTitle = clearTitle
        self.onDone = onDone
        self.onClear = onClear
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let minimumDate {
                    DatePicker(
                        title,
                        selection: $draftDate,
                        in: minimumDate...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                } else {
                    DatePicker(title, selection: $draftDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
            }
            .ignoresSafeArea()
            .offset(y: -30)
            .padding(.horizontal)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }

                if let clearTitle, let onClear {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) {
                            onClear()
                            dismiss()
                        } label: {
                            Text(clearTitle)
                                .foregroundStyle(.red)
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) {
                        selectedDate = draftDate
                        onDone?()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
