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
                VStack {
                    BudgetCardView(amount: budget.remainingAmount.formattedVND)
                        .padding(.top)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    BudgetTransactionListView(transactions: budget.transactions)
                }
            }
        }
        .onAppear {
            viewModel.selectedMonth(selectedMonth)
            viewModel.load()
        }
    }
}
