//
//  ToastMessage.swift
//  Letter
//
//  Created by TiniT on 22/7/26.
//

import Foundation

enum ToastType {
    case success
    case failure
    case warning
    case info
    
    var icon: String {
        switch self {
        case .success:
            "checkmark.circle"
        case .failure:
            "exclamationmark.circle"
        case .warning:
            "exclamationmark.triangle"
        case .info:
            "info.circle"
        }
    }
}

struct ToastMessage: Equatable {
    let id = UUID()
    let text: String
    let type: ToastType
}
