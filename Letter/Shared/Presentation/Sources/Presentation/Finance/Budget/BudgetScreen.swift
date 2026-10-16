//
//  BudgetScreen.swift
//  Presentation
//
//  Created by Tín Nguyễn on 15/10/26.
//

import SwiftUI
import Styleguide
import Domain

struct BudgetScreen: View {
    @State private var viewModel: BudgetViewModel
    public let selectedMonth: FinanceMonth
    
    init(_ viewModel: BudgetViewModel, selectedMonth: FinanceMonth) {
        self.viewModel = viewModel
        self.selectedMonth = selectedMonth
    }
    
    var body: some View {
        BaseScreen {
            if let budget = viewModel.budget {
                VStack(spacing: 0) {
                    BudgetCardView(amount: budget.remainingAmount.formattedVND)
                        .padding(.top)
                        .padding(.horizontal)
                    
                    BudgetTransactionListView(transactions: budget.transactions)
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            viewModel.selectedMonth(selectedMonth)
            viewModel.load()
        }
    }
}
