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
            VStack {
                Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
                
                Spacer()
            }
        }
    }
}
