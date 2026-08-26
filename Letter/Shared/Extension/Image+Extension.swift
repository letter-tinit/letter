//
//  Image+Extension.swift
//  Letter
//
//  Created by TiniT on 27/5/26.
//

import SwiftUI
import UIKit

extension Image {
    init(module name: String) {
        if UIImage(systemName: name) != nil {
            self = Image(systemName: name)
        } else {
            self = Image(name)
                .resizable()
        }
        
    }
    
    func circularImageStyle(with color: Color) -> some View {
        self
            .customFont(.title)
            .padding()
            .appGlassEffect(
                .regular.interactive().tint(color.opacity(0.5)),
                in: .circle
            )
    }
}
