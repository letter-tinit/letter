import Foundation
import Utility

public enum FinanceLockMethod: String, Codable, Sendable {
    case none
    case pin
    case biometrics
}

public enum FinanceBiometry: Sendable {
    case unavailable
    case touchID
    case faceID
    case other
}

public struct FinanceBiometryStatus: Sendable {
    public let biometry: FinanceBiometry
    public let isAvailable: Bool
    public init(biometry: FinanceBiometry, isAvailable: Bool) { self.biometry = biometry; self.isAvailable = isAvailable }
}

public enum FinanceAuthenticationPolicy: Sendable {
    case biometrics
    case deviceOwner
}

public enum FinanceLockError: Error, Equatable {
    case invalidPIN
    case incorrectPIN
    case unavailable
    case biometricsUnavailable
    case biometricsNotEnrolled
    case biometricsLocked
    case passcodeNotSet
    case authenticationFailed
    case authenticationCancelled
    case saveFailed
}

public enum FinancePIN {
    public static func isValid(_ pin: String) -> Bool {
        (4...6).contains(pin.count) && pin.allSatisfy { character in
            character.unicodeScalars.allSatisfy { (48...57).contains(Int($0.value)) }
        }
    }

    public static func securelyMatches(_ candidate: String, _ stored: String) -> Bool {
        let candidateBytes = Array(candidate.utf8)
        let storedBytes = Array(stored.utf8)
        guard candidateBytes.count == storedBytes.count else { return false }

        var difference: UInt8 = 0
        for index in candidateBytes.indices {
            difference |= candidateBytes[index] ^ storedBytes[index]
        }
        return difference == 0
    }
}
