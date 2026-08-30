//
//  PreviewContainer.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import SwiftData

@MainActor
final class PreviewContainer {
    static let shared: PreviewContainer = {
        let container = try! ModelContainer(
            for: TransactionRecord.self,
            BalanceMonthRecord.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true
            )
        )
        
        return PreviewContainer(container: container)
    }()
    
    let container: ModelContainer
    
    private init(container: ModelContainer) {
        self.container = container
    }
}
