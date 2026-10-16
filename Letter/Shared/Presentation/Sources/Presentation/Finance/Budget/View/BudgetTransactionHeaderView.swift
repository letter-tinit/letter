//
//  BudgetTransactionHeaderView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 16/10/26.
//

import SwiftUI

struct BudgetTransactionHeaderView: View {
    let dateNo: String
    
    var body: some View {
        HStack {
            Text("common.day".localized)
                .customFont(.headline, weight: .semibold)
            
            Image(systemName: "\(dateNo).calendar")
        }
        .customFont(.title3)
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
        .appGlassEffect(
            .regular.tint(.mint.opacity(0.2)),
            in: .rect(cornerRadius: 4)
        )
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing)
        .foregroundStyle(.primary)
    }
}
