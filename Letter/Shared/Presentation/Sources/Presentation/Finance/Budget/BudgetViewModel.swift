//
//  BudgetViewModel.swift
//  Presentation
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Domain
import Foundation
import Observation
import Styleguide

@Observable
public final class BudgetViewModel {
    private let useCase: any BudgetUseCase
    private var selectedMonth: FinanceMonth?
    
    public var budget: BudgetPresentationModel?
    public var toastMessage: ToastMessage?
    
    public init(useCase: any BudgetUseCase) {
        self.useCase = useCase
    }
    
    public func selectedMonth(_ selectedMonth: FinanceMonth) {
        self.selectedMonth = selectedMonth
    }
    
    func load() {
        guard let date = selectedMonth?.startDate else { return }
        do {
            if let domain = try useCase.load(date) {
                budget = BudgetPresentationModel(domain: domain)
            } else {
                budget = nil
            }
        } catch {
            showError(error.localizedDescription)
        }
    }
}

private extension BudgetViewModel {
    func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}
