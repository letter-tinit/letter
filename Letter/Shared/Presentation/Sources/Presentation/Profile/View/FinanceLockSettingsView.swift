import SwiftUI
import Domain
import Utility
import Styleguide

public struct FinanceLockSettingsView: View {
    @Environment(FinanceLockManager.self) private var lockManager
    @Environment(\.dismiss) private var dismiss

    @State private var pinRequest: PINRequest?
    @State private var completedPINAction: VerifiedAction?

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.Common.background.ignoresSafeArea()

                AppScrollView {
                    VStack {
                        StandaloneSection {
                            currentMethodRow
                        }

                        StandaloneSection(
                            rows: "finance.lock.chooseMethod".localized,
                            alignment: .leading,
                            footer: "finance.lock.security.description".localized
                        ) {
                            methodButton(
                                method: .none,
                                title: "finance.lock.method.none".localized,
                                description: "finance.lock.method.none.description".localized,
                                systemImage: "lock.open"
                            ) {
                                chooseNoProtection()
                            }

                            methodButton(
                                method: .pin,
                                title: "finance.lock.method.pin".localized,
                                description: "finance.lock.method.pin.description".localized,
                                systemImage: "number.square"
                            ) {
                                choosePIN()
                            }

                            methodButton(
                                method: .biometrics,
                                title: lockManager.biometry.title,
                                description: biometricDescription,
                                systemImage: lockManager.biometry.systemImage,
                                isEnabled: lockManager.canUseBiometrics || lockManager.method == .biometrics
                            ) {
                                chooseBiometrics()
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("finance.lock.settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) { dismiss() }
                }
            }
            .disabled(lockManager.isAuthenticating)
            .overlay {
                if lockManager.isAuthenticating {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 14))
                }
            }
        }
        .onAppear { lockManager.refreshBiometryAvailability() }
        .sheet(item: $pinRequest, onDismiss: performCompletedPINAction) { request in
            FinancePINSheet(mode: request.mode) {
                completedPINAction = request.actionAfterVerification
            }
            .environment(lockManager)
        }
        .alert(
            "common.error".localized,
            isPresented: Binding(
                get: { lockManager.errorMessage != nil },
                set: { if !$0 { lockManager.clearError() } }
            )
        ) {
            Button("common.ok".localized, role: .cancel) {
                lockManager.clearError()
            }
        } message: {
            Text(lockManager.errorMessage ?? "")
        }
    }

    private var currentMethodTitle: String {
        switch lockManager.method {
        case .none:
            "finance.lock.method.none".localized
        case .pin:
            "finance.lock.method.pin".localized
        case .biometrics:
            lockManager.biometry.title
        }
    }

    private var currentMethodImage: String {
        switch lockManager.method {
        case .none: "lock.open"
        case .pin: "number.square"
        case .biometrics: lockManager.biometry.systemImage
        }
    }

    private var biometricDescription: String {
        lockManager.canUseBiometrics
        ? "finance.lock.method.biometrics.description".localized
        : "finance.lock.biometric.notEnrolled".localized
    }

    private var currentMethodRow: some View {
        HStack(spacing: 12) {
            Image(systemName: currentMethodImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text("finance.lock.current".localized)
                    .foregroundStyle(.secondary)
                Text(currentMethodTitle)
                    .fontWeight(.semibold)
            }

            Spacer()
        }
    }

    private func methodButton(
        method: FinanceLockMethod,
        title: String,
        description: String,
        systemImage: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if lockManager.method == method {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("finance.lock.current".localized)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func chooseNoProtection() {
        switch lockManager.method {
        case .none:
            return
        case .pin:
            pinRequest = PINRequest(mode: .verify, actionAfterVerification: .disable)
        case .biometrics:
            Task {
                guard await lockManager.authorizeCurrentMethod() else { return }
                lockManager.disableProtection()
            }
        }
    }

    private func choosePIN() {
        switch lockManager.method {
        case .none:
            pinRequest = PINRequest(mode: .create)
        case .pin:
            pinRequest = PINRequest(mode: .change)
        case .biometrics:
            Task {
                guard await lockManager.authorizeCurrentMethod() else { return }
                pinRequest = PINRequest(mode: .create)
            }
        }
    }

    private func chooseBiometrics() {
        guard lockManager.method != .biometrics else { return }
        guard lockManager.canUseBiometrics else {
            lockManager.refreshBiometryAvailability()
            return
        }

        switch lockManager.method {
        case .none:
            Task { await lockManager.enableBiometricProtection() }
        case .pin:
            pinRequest = PINRequest(mode: .verify, actionAfterVerification: .enableBiometrics)
        case .biometrics:
            break
        }
    }

    private func performCompletedPINAction() {
        guard let action = completedPINAction else { return }
        completedPINAction = nil

        switch action {
        case .disable:
            lockManager.disableProtection()
        case .enableBiometrics:
            Task { await lockManager.enableBiometricProtection() }
        }
    }
}

private extension FinanceLockSettingsView {
    enum VerifiedAction {
        case disable
        case enableBiometrics
    }

    struct PINRequest: Identifiable {
        let id = UUID()
        let mode: FinancePINSheet.Mode
        var actionAfterVerification: VerifiedAction?

        init(mode: FinancePINSheet.Mode, actionAfterVerification: VerifiedAction? = nil) {
            self.mode = mode
            self.actionAfterVerification = actionAfterVerification
        }
    }
}

private struct FinancePINSheet: View {
    enum Mode {
        case verify
        case create
        case change
    }

    @Environment(FinanceLockManager.self) private var lockManager
    @Environment(\.dismiss) private var dismiss

    public let mode: Mode
    public let onSuccess: () -> Void

    @State private var currentPIN = ""
    @State private var newPIN = ""
    @State private var confirmationPIN = ""
    @State private var validationMessage: String?
    @FocusState private var focusedField: Field?

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.Common.background.ignoresSafeArea()

                AppScrollView {
                    VStack {
                        StandaloneSection(
                            rows: nil,
                            alignment: .leading,
                            footer: "finance.lock.pin.help".localized
                        ) {
                            if mode == .verify || mode == .change {
                                pinField(
                                    "finance.lock.pin.current".localized,
                                    text: $currentPIN,
                                    field: .current
                                )
                            }

                            if mode == .create || mode == .change {
                                pinField(
                                    "finance.lock.pin.new".localized,
                                    text: $newPIN,
                                    field: .new
                                )
                                pinField(
                                    "finance.lock.pin.confirm".localized,
                                    text: $confirmationPIN,
                                    field: .confirmation
                                )
                            }
                        }

                        if let validationMessage {
                            StandaloneSection {
                                Text(validationMessage)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        StandaloneSection {
                            Button(action: submit) {
                                Text(actionTitle)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canSubmit)
                        }
                    }
                    .padding(.bottom)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { dismiss() }
                }
            }
        }
        .onAppear {
            focusedField = mode == .create ? .new : .current
        }
        .onChange(of: currentPIN) { _, value in
            currentPIN = sanitizedPIN(value)
            validationMessage = nil
        }
        .onChange(of: newPIN) { _, value in
            newPIN = sanitizedPIN(value)
            validationMessage = nil
        }
        .onChange(of: confirmationPIN) { _, value in
            confirmationPIN = sanitizedPIN(value)
            validationMessage = nil
        }
    }

    private var title: String {
        switch mode {
        case .verify: "finance.lock.pin.verifyTitle".localized
        case .create: "finance.lock.pin.createTitle".localized
        case .change: "finance.lock.pin.changeTitle".localized
        }
    }

    private var actionTitle: String {
        switch mode {
        case .verify: "common.confirm".localized
        case .create, .change: "common.save".localized
        }
    }

    private var canSubmit: Bool {
        switch mode {
        case .verify:
            FinanceLockManager.isValidPIN(currentPIN)
        case .create:
            FinanceLockManager.isValidPIN(newPIN)
            && FinanceLockManager.isValidPIN(confirmationPIN)
        case .change:
            FinanceLockManager.isValidPIN(currentPIN)
            && FinanceLockManager.isValidPIN(newPIN)
            && FinanceLockManager.isValidPIN(confirmationPIN)
        }
    }

    private func pinField(_ title: String, text: Binding<String>, field: Field) -> some View {
        SecureField(title, text: text)
            .keyboardType(.numberPad)
            .textContentType(.password)
            .focused($focusedField, equals: field)
            .privacySensitive()
    }

    private func sanitizedPIN(_ value: String) -> String {
        let digits = value.filter { character in
            character.unicodeScalars.allSatisfy { (48...57).contains(Int($0.value)) }
        }
        return String(digits.prefix(6))
    }

    private func submit() {
        validationMessage = nil

        switch mode {
        case .verify:
            guard lockManager.unlock(withPIN: currentPIN) else {
                showManagerError()
                focusedField = .current
                return
            }
        case .create:
            guard validateNewPIN() else { return }
            guard lockManager.configurePIN(newPIN) else {
                showManagerError()
                return
            }
        case .change:
            guard validateNewPIN() else { return }
            guard lockManager.unlock(withPIN: currentPIN) else {
                showManagerError()
                focusedField = .current
                return
            }
            guard lockManager.configurePIN(newPIN) else {
                showManagerError()
                return
            }
        }

        onSuccess()
        dismiss()
    }

    private func validateNewPIN() -> Bool {
        guard FinanceLockManager.isValidPIN(newPIN) else {
            validationMessage = "finance.lock.pin.invalid".localized
            return false
        }
        guard newPIN == confirmationPIN else {
            validationMessage = "finance.lock.pin.mismatch".localized
            return false
        }
        return true
    }

    private func showManagerError() {
        validationMessage = lockManager.errorMessage ?? "finance.lock.error.unavailable".localized
        lockManager.clearError()
    }

    private enum Field {
        case current
        case new
        case confirmation
    }
}

