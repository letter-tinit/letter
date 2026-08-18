//
//  NetWorthRepository.swift
//  Letter
//
//  Created by TiniT on 21/7/26.
//

protocol NetWorthRepository {
    func fetchNetWorth() throws -> [NetWorthYear]
    func addNetWorth(_ netWorth: NetWorthYear) throws
    func removeNetWorth(_ netWorth: NetWorthYear) throws
    func save() throws
}
