//
//  Image+Extension.swift
//  Habit
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
}
