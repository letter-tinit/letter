//
//  BudgetAllocationView.swift
//  Letter
//
//  Created by TiniT on 23/7/26.
//

import SwiftUI
import Domain
import Core
import Utility
import Styleguide

public struct BudgetAllocationView: View {
    public let summary: BudgetAllocationSummary
    
    private var allocation: BudgetAllocation { summary.allocation }
    private var isSaving: Bool { allocation.kind.isSavingsLike }
    private var planRatioText: String { "\((summary.planRatio.doubleValue * 100).ceiledToTwoDecimalPlaces)%" }
    private var actualRatioText: String { "\((summary.actualRatio.doubleValue * 100).ceiledToTwoDecimalPlaces)%" }
    private var differenceAmount: Decimal { summary.remainingAmount < 0 ? -summary.remainingAmount : summary.remainingAmount }
    private var differenceTitle: String {
        summary.remainingAmount < 0
        ? "budget.metric.overTarget".localized
        : (isSaving ? "budget.metric.remainingToSave".localized : "budget.metric.remaining".localized)
    }
    private let topOffset: CGFloat = 30
    
    public var body: some View {
        VStack(alignment: .leading) {
            CommonRowView(.init(title: "budget.metric.target".localized, value: allocation.targetAmount.formattedVND))
            CommonRowView(.init(
                title: isSaving ? "budget.metric.saved".localized : "budget.metric.spent".localized,
                value: summary.actualAmount.formattedVND
            ))
            Divider()
            CommonRowView(.init(title: "budget.metric.planRatio".localized, value: planRatioText))
            CommonRowView(.init(title: "budget.metric.actualRatio".localized, value: actualRatioText))
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(differenceTitle)
                        .customFont(.subheadline)
                    Text(differenceAmount.formattedVND)
                        .customFont(.title, weight: .bold)
                }
                
                Spacer()
                
                statusBadge
            }
            progressBar
        }
        .padding()
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
        .borderedBackground(
            linearGradient: LinearGradient(
                colors: [
                    allocation.kind.topicColor.opacity(0.3),
                    allocation.kind.topicColor.opacity(0.2),
                    allocation.kind.topicColor.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .appGlassEffect(
            .regular
                .tint(allocation.kind.topicColor.opacity(0.18)),
            in: .rect(cornerRadius: 16)
        )
        .overlay(alignment: .top) {
            HStack(spacing: 6) {
                Image(systemName: allocation.kind.systemImageName)
                Text(allocation.kind.localizationKey.localized)
            }
            .customFont(.headline, weight: .semibold)
            .foregroundStyle(.white)
            .padding(4)
            .padding(.horizontal, 16)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 12,
                    topTrailingRadius: 12
                )
            )
            .appGlassEffect(
                .regular
                    .tint(allocation.kind.topicColor.opacity(0.85)),
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 12,
                    topTrailingRadius: 12
                )
            )
            .offset(y: -topOffset)
        }
        .padding(.top, topOffset)
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: summary.status.systemImageName)
            Text(summary.status.localizationKey.localized)
        }
        .customFont(.subheadline, weight: .semibold)
        .foregroundStyle(summary.status.tintColor(for: allocation.kind))
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.gray.opacity(0.2)
                allocation.kind.topicColor
                    .clipShape(.capsule)
                    .frame(width: geometry.size.width * summary.displayBarProgress)
            }
        }
        .frame(height: 10)
        .clipShape(.capsule)
    }
}
