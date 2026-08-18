//
//  NetWorthViewModel.swift
//  Personal Finance
//
//  Created by TiniT on 21/7/26.
//

import Foundation

@Observable
final class NetWorthViewModel {
    private let repository: NetWorthRepository
    
    var toastMessage: ToastMessage?
    
    init(repository: NetWorthRepository) {
        self.repository = repository
    }
    
    func createNetWorthYear(_ year: Int) {
        let existingYears = load()
        
        guard !existingYears.contains(where: { $0.year == year }) else {
            showError(String(format: "networth.year.existed".localized, year))
            return
        }
        
        let newNetWorthYear: NetWorthYear
        
        if let latestYear = existingYears.max(by: { $0.year < $1.year }) {
            newNetWorthYear = latestYear.reusingPlan(for: year)
        } else {
            newNetWorthYear = NetWorthYear(year: year)
            
            do {
                try newNetWorthYear.addSnapshotsForAllMonths()
            } catch {
                showError(error.localizedDescription)
                return
            }
        }
        
        addNewNetWorth(newNetWorthYear)
    }
    
    func removeNetWorth(_ netWorth: NetWorthYear?) {
        guard let netWorth else { return }
        do {
            try repository.removeNetWorth(netWorth)
            Haptic.warning()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func save() {
        do {
            try repository.save()
        } catch {
            showError(error.localizedDescription)
        }
    }
}

// MARK: - PRIVATE HELPER
private extension NetWorthViewModel {
    func load() -> [NetWorthYear] {
        do {
            return try repository.fetchNetWorth()
        } catch {
            showError(error.localizedDescription)
            return []
        }
    }
    
    func addNewNetWorth(_ netWorth: NetWorthYear) {
        do {
            try repository.addNetWorth(netWorth)
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func showError(_ text: String) {
        toastMessage = ToastMessage(text: text, type: .failure)
    }
}
