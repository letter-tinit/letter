//
//  NetWorthItemRowView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 6/10/26.
//

import SwiftUI
import Domain
import Styleguide

struct NetWorthItemRowView: View {
    @Environment(NetWorthViewModel.self) private var netWorthViewModel
    @State private var isDeleteConfirmationPresented: Bool = false
    
    @Binding var item: NetWorthItemPresentationModel
    var category: NetWorthCategoryPresentationModel
    
    
    public var body: some View {
        Button {
            netWorthViewModel.itemEditing = .init(item: item, category: category.type)
            netWorthViewModel.isEditing = true
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
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.1, maximumDistance: 0.3)
                    .onEnded { _ in
                        Haptic.impact()
                        isDeleteConfirmationPresented = true
                    }
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("networth.item.form.edit.accessibilityHint".localized)
        .accessibilityElement(children: .combine)
        .padding(.vertical, 5)
        .disabled(netWorthViewModel.isNetWorthLocked())
        .deleteConfirmationDialog(
            isPresented: $isDeleteConfirmationPresented,
            title: "networth.item.delete.confirmation.title".localized,
            message: "networth.item.delete.confirmation.message".localized
        ) {
            netWorthViewModel.itemEditing = .init(item: item)
            netWorthViewModel.deleteSelectedItem()
        }
    }
}
