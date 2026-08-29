import Foundation

enum FinanceLockMethod: String, Codable, Sendable {
    case none
    case pin
    case biometrics
}

enum FinanceBiometry: Sendable {
    case unavailable
    case touchID
    case faceID
    case other
}

struct FinanceBiometryStatus: Sendable {
    let biometry: FinanceBiometry
    let isAvailable: Bool
}

enum FinanceAuthenticationPolicy: Sendable {
    case biometrics
    case deviceOwner
}

enum FinanceLockError: Error, Equatable {
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

enum FinancePIN {
    static func isValid(_ pin: String) -> Bool {
        (4...6).contains(pin.count) && pin.allSatisfy { character in
            character.unicodeScalars.allSatisfy { (48...57).contains(Int($0.value)) }
        }
    }

    static func securelyMatches(_ candidate: String, _ stored: String) -> Bool {
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
