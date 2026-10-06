//
//  NetWorthItemRowView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 6/10/26.
//

import SwiftUI

struct NetWorthItemRowView: View {
    @Binding var item: NetWorthItemPresentationModel
    // MARK: TODO
    public let onEdit: () -> Void
    
    public var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(item.name)
                    .customFont(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer(minLength: 12)
                
                if item.amount == .zero {
                    Text(item.amount.formattedVND)
                        .customFont(.subheadline, weight: .medium)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("networth.value.missing".localized)
                        .customFont(.footnote, weight: .medium)
                        .foregroundStyle(.orange)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("networth.item.form.edit.accessibilityHint".localized)
        .accessibilityElement(children: .combine)
        .padding(.vertical, 5)
    }
}
