import SwiftUI
import Domain
import Utility
import Styleguide

public struct FinanceAccessGate<Content: View>: View {
    @Environment(FinanceLockManager.self) private var lockManager

    public let isActive: Bool
    private let content: () -> Content

    public init(isActive: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.isActive = isActive
        self.content = content
    }

    public var body: some View {
        Group {
            if lockManager.requiresAuthentication {
                FinanceLockedView(isActive: isActive)
            } else {
                content()
            }
        }
        .onChange(of: isActive) { wasActive, isActive in
            if wasActive && !isActive {
                lockManager.lock()
            }
        }
    }
}

private struct FinanceLockedView: View {
    @Environment(FinanceLockManager.self) private var lockManager

    public let isActive: Bool

    @State private var pin = ""
    @FocusState private var isPINFocused: Bool

    public var body: some View {
        ZStack {
            Color.Common.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: lockManager.method == .biometrics
                      ? lockManager.biometry.systemImage
                      : "lock.shield.fill")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("finance.lock.screen.title".localized)
                        .customFont(size: 24, weight: .bold)

                    Text(lockDescription)
                        .customFont(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if lockManager.method == .pin {
                    pinControls
                } else {
                    biometricControls
                }

                if let errorMessage = lockManager.errorMessage {
                    Text(errorMessage)
                        .customFont(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel(errorMessage)
                }
            }
            .padding(28)
            .frame(maxWidth: 420)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("finance.tab.title".localized.uppercased())
                    .customFont(.headline, weight: .semibold)
            }
        }
        .task(id: automaticAuthenticationID) {
            guard isActive, lockManager.method == .biometrics else { return }
            await lockManager.unlockWithDeviceAuthentication()
        }
        .onChange(of: pin) { _, newValue in
            let filtered = newValue.filter { character in
                character.unicodeScalars.allSatisfy { (48...57).contains(Int($0.value)) }
            }
            pin = String(filtered.prefix(6))
            lockManager.clearError()
        }
    }

    private var automaticAuthenticationID: String {
        "\(isActive)-\(lockManager.method.rawValue)"
    }

    private var lockDescription: String {
        switch lockManager.method {
        case .pin:
            "finance.lock.screen.pinDescription".localized
        case .biometrics:
            "finance.lock.screen.biometricDescription".localized(lockManager.biometry.title)
        case .none:
            ""
        }
    }

    private var pinControls: some View {
        VStack(spacing: 12) {
            SecureField("finance.lock.pin.placeholder".localized, text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.password)
                .multilineTextAlignment(.center)
                .padding(12)
                .background(.quaternary, in: .rect(cornerRadius: 12))
                .focused($isPINFocused)
                .onSubmit(unlockWithPIN)
                .privacySensitive()
                .accessibilityLabel("finance.lock.pin.placeholder".localized)

            Button(action: unlockWithPIN) {
                Text("finance.lock.action.unlock".localized)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!FinanceLockManager.isValidPIN(pin))
        }
        .frame(maxWidth: 280)
        .onAppear { isPINFocused = true }
    }

    private var biometricControls: some View {
        Button {
            Task { await lockManager.unlockWithDeviceAuthentication() }
        } label: {
            Label(
                "finance.lock.action.unlockWith".localized(lockManager.biometry.title),
                systemImage: lockManager.biometry.systemImage
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(lockManager.isAuthenticating)
        .frame(maxWidth: 280)
    }

    private func unlockWithPIN() {
        guard FinanceLockManager.isValidPIN(pin) else { return }
        if !lockManager.unlock(withPIN: pin) {
            isPINFocused = true
        }
    }
}

