//
//  Enum+Style.swift
//  Letter
//
//  Created by TiniT on 10/7/26.
//

import SwiftUI
import Domain
import Utility

extension TransactionType {
    public var color: Color {
        switch self {
        case .expense:
            return Color.Common.failure
        case .income:
            return Color.Common.success
        }
    }
}

extension PaymentMethod {
    public var color: Color {
        switch self {
        case .banking:
            return .blue
            
        case .cash:
            return .green
            
        case .card:
            return .indigo
            
        case .mixed:
            return .cyan
        }
    }
}

extension ToastType {
    public var color: Color {
        switch self {
        case .success: .green
        case .failure: Color.Common.failure
        case .warning: .orange
        case .info: .blue
        }
    }
}

extension NetWorthGroupType {
    public var tint: Color {
        switch self {
        case .assets: .green
        case .liabilities: .orange
        }
    }
}
