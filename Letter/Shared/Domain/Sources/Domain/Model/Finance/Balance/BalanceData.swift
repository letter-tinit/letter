public struct BalanceData {
    public let transactions: [Transaction]
    public let months: [BalanceMonth]

    public init(transactions: [Transaction], months: [BalanceMonth]) {
        self.transactions = transactions
        self.months = months
    }
}
