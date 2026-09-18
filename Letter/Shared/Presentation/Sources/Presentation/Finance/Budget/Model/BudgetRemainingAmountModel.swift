import Foundation
import Utility

/// Immutable keyboard input values, prepared from the whole budget's net balance.
public struct BudgetRemainingAmountModel: Equatable {
    public struct Amount: Equatable {
        public let text: String
        public let title: String
    }

    public let amount: Amount?

    public init() {
        amount = nil
    }

    @MainActor
    public init(remainingAmount: Decimal) {
        var balance = remainingAmount
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &balance, 0, .down)
        guard rounded > 0 else {
            amount = nil
            return
        }
        let text = CurrencyInputFormatter.format(NSDecimalNumber(decimal: rounded).stringValue)
        amount = Amount(text: text, title: "\(text) ₫")
    }
}
