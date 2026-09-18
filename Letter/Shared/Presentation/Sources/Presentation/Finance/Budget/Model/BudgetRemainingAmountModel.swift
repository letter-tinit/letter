import Foundation
import Utility

/// Immutable keyboard input values, prepared from the budget's available balances.
public struct BudgetRemainingAmountModel: Equatable {
    public struct Amount: Equatable {
        public let text: String
        public let title: String
    }

    private let amounts: [UUID: Amount]

    public init() {
        amounts = [:]
    }

    @MainActor
    public init(remainingAmounts: [UUID: Decimal]) {
        amounts = remainingAmounts.reduce(into: [:]) { result, entry in
            var amount = entry.value
            var rounded = Decimal.zero
            NSDecimalRound(&rounded, &amount, 0, .down)
            guard rounded > 0 else { return }
            let text = CurrencyInputFormatter.format(NSDecimalNumber(decimal: rounded).stringValue)
            result[entry.key] = Amount(text: text, title: "\(text) ₫")
        }
    }

    public func amount(for allocationID: UUID?) -> Amount? {
        guard let allocationID else { return nil }
        return amounts[allocationID]
    }
}
