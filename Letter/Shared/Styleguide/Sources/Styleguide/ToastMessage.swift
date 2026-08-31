//
//  ToastMessage.swift
//  Letter
//
//  Created by TiniT on 22/7/26.
//

import Foundation
import Domain
import Core
import Utility

public enum ToastType {
    case success
    case failure
    case warning
    case info
    
    public var icon: String {
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

public struct ToastMessage: Equatable {
    public let id = UUID()
    public let text: String
    public let type: ToastType
    public init(text: String, type: ToastType) { self.text = text; self.type = type }
}
