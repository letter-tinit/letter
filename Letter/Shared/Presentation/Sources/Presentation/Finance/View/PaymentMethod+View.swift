import Domain

public extension PaymentMethod {
    var localizationKey: String {
        "payment.method.\(rawValue)"
    }
}
