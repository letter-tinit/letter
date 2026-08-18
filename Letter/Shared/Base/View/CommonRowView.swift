//
//  CommonRowView.swift
//  Personal Finance
//
//  Created by TiniT on 13/7/26.
//

import SwiftUI

struct CommonRowView: View {
    let model: Model
    
    init(_ model: Model) {
        self.model = model
    }

    var body: some View {
        HStack {
            Text(model.title)
                .customSubText()
            
            Spacer()
            
            Text(model.value)
                .customHeadline()
                .foregroundStyle(model.isHighlight ? model.highlightColor : Color.primary)
        }
    }
}

extension CommonRowView {
    struct Model {
        let title: String
        let value: String
        var isHighlight: Bool = false
        var highlightColor: Color = .accentColor
    }
}
