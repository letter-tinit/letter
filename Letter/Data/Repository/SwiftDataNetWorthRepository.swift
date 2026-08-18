//
//  SwiftDataNetWorthRepository.swift
//  Letter
//
//  Created by TiniT on 21/7/26.
//

import SwiftData

final class SwiftDataNetWorthRepository: NetWorthRepository {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchNetWorth() throws -> [NetWorthYear] {
        let descriptor = FetchDescriptor<NetWorthYear>()
        
        return try modelContext.fetch(descriptor)
    }
    
    func addNetWorth(_ netWorth: NetWorthYear) throws {
        modelContext.insert(netWorth)
        try save()
    }
    
    func removeNetWorth(_ netWorth: NetWorthYear) throws {
        modelContext.delete(netWorth)
        try save()
    }
    
    func save() throws {
        try modelContext.save()
    }
}
