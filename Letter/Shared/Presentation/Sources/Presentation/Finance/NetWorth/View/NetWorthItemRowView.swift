//
//  NetWorthItemRowView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 6/10/26.
//

import SwiftUI
import Domain


struct NetWorthItemRowView: View {
    @Environment(NetWorthViewModel.self) private var netWorthViewModel
    @Binding var item: NetWorthItemPresentationModel
    var category: NetWorthCategoryPresentationModel
    
    public var body: some View {
        Button {
            netWorthViewModel.presentEditForm(item, category: category.type)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(item.name)
                    .customFont(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer(minLength: 12)
                
                if let amount = item.amount {
                    Text(amount.formattedVND)
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
        .disabled(netWorthViewModel.isNetWorthLocked())
    }
}
