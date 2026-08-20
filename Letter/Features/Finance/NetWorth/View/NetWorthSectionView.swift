//
//  NetWorthSectionView.swift
//  Letter
//
//  Created by TiniT on 15/7/26.
//

import SwiftUI

struct NetWorthSectionView: View {
    let category: NetWorthCategory
    let items: [NetWorthPlanItem]
    let snapshot: NetWorthSnapshot
    let isEditingUnlocked: Bool
    let onEdit: (NetWorthPlanItem) -> Void

    private var subtotal: Decimal {
        items
            .compactMap { snapshot.amount(for: $0) }
            .reduce(.zero, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.localizationKey.localized)
                    .customFont(.subheadline, weight: .semibold)
                    .foregroundStyle(.primary)

                Spacer()

                Text(subtotal.formattedVND)
                    .customFont(.subheadline, weight: .semibold)
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                Text("networth.category.empty".localized)
                    .customFont(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    NetWorthItemRowView(
                        name: item.name,
                        amount: snapshot.amount(for: item),
                        isEditingUnlocked: isEditingUnlocked,
                        onEdit: {
                            onEdit(item)
                        }
                    )
                }
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
    }
}

private struct NetWorthItemRowView: View {
    let name: String
    let amount: Decimal?
    let isEditingUnlocked: Bool
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(name)
                    .customFont(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                if let amount {
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
        .disabled(!isEditingUnlocked)
        .accessibilityHint("networth.item.form.edit.accessibilityHint".localized)
        .accessibilityElement(children: .combine)
        .padding(.vertical, 5)
    }
}

extension NetWorthCategory {
    var localizationKey: String {
        switch self {
        case .cashAndCashEquivalents:
            "networth.category.cashAndCashEquivalents"
        case .receivables:
            "networth.category.receivables"
        case .tangibleAssets:
            "networth.category.tangibleAssets"
        case .financialAssets:
            "networth.category.financialAssets"
        case .shortTermDebt:
            "networth.category.shortTermDebt"
        case .longTermDebt:
            "networth.category.longTermDebt"
        }
    }
}

extension NetWorthGroup {
    var localizationKey: String {
        switch self {
        case .assets:
            "networth.group.assets"
        case .liabilities:
            "networth.group.liabilities"
        }
    }

    var systemImage: String {
        switch self {
        case .assets:
            "building.columns"
        case .liabilities:
            "creditcard"
        }
    }

    var totalLocalizationKey: String {
        switch self {
        case .assets:
            "networth.total.assets"
        case .liabilities:
            "networth.total.liabilities"
        }
    }

    var tint: Color {
        switch self {
        case .assets:
            .green
        case .liabilities:
            .orange
        }
    }
}
