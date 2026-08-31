//
//  BudgetAllocationListView.swift
//  Letter
//
//  Created by TiniT on 24/7/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct BudgetAllocationListView: View {
    public let budget: Budget
    
    public var body: some View {
        AppScrollView(.vertical) {
            VStack {
                ForEach(budget.allocations.sorted(by: { $0.kind.id < $1.kind.id })) { allocation in
                    BudgetAllocationView(summary: budget.allocationSummary(for: allocation))
                }
            }
            .padding()
        }
    }
}
