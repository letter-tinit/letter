import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Domain
import Utility
import Styleguide

public struct ProfileScreen: View {
    @AppStorage(AppLanguage.preferenceKey)
    private var languageCode = AppLanguage.vietnamese.rawValue
    @AppStorage(FinanceSettings.earliestMonthKey)
    private var earliestMonthTimestamp = FinanceMonth(.now).startDate.timeIntervalSinceReferenceDate
    
    @Environment(ProfileRouter.self) private var router
    @Environment(ProfileViewModel.self) private var profileViewModel
    @Environment(FinanceLockManager.self) private var financeLockManager
    
    @State private var isImporting = false
    @State private var title = "profile.tab.title".localized
    @State private var isEarliestMonthPickerPresented = false
    @State private var isFinanceLockSettingsPresented = false
    @State private var isSpeechProviderSettingsPresented = false
    @State private var isClearDataConfirmationPresented = false
    private let onDataChanged: () -> Void
    
    public init(
        onDataChanged: @escaping () -> Void = {}
    ) {
        self.onDataChanged = onDataChanged
    }
    
    public var body: some View {
        @Bindable var profileViewModel = profileViewModel
        
        BaseScreen($title) {
            AppScrollView {
                VStack {
                    profileHeader
                    preferencesSection
                    financeSecuritySection
                    backupSection
                    deleteSection
                    
                    Spacer()
                }
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            if AppLanguage(rawValue: languageCode) == nil {
                languageCode = AppLanguage.vietnamese.rawValue
            }
            profileViewModel.reload()
            title = profileViewModel.profileTitle
        }
        .onChange(of: languageCode) { _, _ in
            profileViewModel.refreshLocalizedText()
            title = profileViewModel.profileTitle
        }
        .fileExporter(
            isPresented: Binding(
                get: { profileViewModel.exportDocument != nil },
                set: { if !$0 { profileViewModel.clearExport() } }
            ),
            document: profileViewModel.exportDocument,
            contentType: .json,
            defaultFilename: Date().toString(withFormat: .custom("dd-MM-yyyy"))
        ) { result in
            switch result {
            case .success:
                profileViewModel.toastMessage = ToastMessage(
                    text: "app.backup.export.success".localized,
                    type: .success
                )
            case .failure(let error):
                profileViewModel.toastMessage = ToastMessage(
                    text: error.localizedDescription,
                    type: .failure
                )
            }
            profileViewModel.clearExport()
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { profileViewModel.prepareImport(from: url) }
            case .failure(let error):
                profileViewModel.toastMessage = ToastMessage(
                    text: error.localizedDescription,
                    type: .failure
                )
            }
        }
        .commonConfirmationDialog(
            isPresented: Binding(
                get: { profileViewModel.pendingImport != nil },
                set: { if !$0 { profileViewModel.cancelImport() } }
            ),
            title: "habit.backup.restore.title".localized,
            message: profileViewModel.pendingImport?.summary.message ?? "",
            actions: [
                ConfirmationDialogAction("habit.backup.restore.action".localized, role: .destructive) {
                    Task {
                        await profileViewModel.confirmImport {
                            profileViewModel.reload()
                            onDataChanged()
                        }
                    }
                },
                ConfirmationDialogAction("common.cancel".localized, role: .cancel) {
                    profileViewModel.cancelImport()
                }
            ]
        )
        .toast(message: profileViewModel.toastMessage)
        .sheet(isPresented: $isEarliestMonthPickerPresented) {
            MonthYearPickerSheet(
                selectedDate: earliestMonthBinding,
                yearRange: 2000...Calendar.current.component(.year, from: .now)
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(
            isPresented: $isFinanceLockSettingsPresented,
            onDismiss: { financeLockManager.lock() }
        ) {
            FinanceLockSettingsView()
        }
        .sheet(isPresented: $isSpeechProviderSettingsPresented) {
            ProfileVoiceSettingsSheet {
                profileViewModel.toastMessage = ToastMessage(
                    text: "audioBook.speechSettings.saved".localized,
                    type: .success
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AppSelector(
                    style: .labelIcon,
                    label: selectedLanguage.shortCode,
                    icon: .asset(selectedLanguage == .english ? "ic_en" : "ic_vi"),
                    iconPosition: selectedLanguage == .english ? .left : .right,
                    action: {
                        languageCode = selectedLanguage == .vietnamese
                        ? AppLanguage.english.rawValue
                        : AppLanguage.vietnamese.rawValue
                    }
                )
            }
        }
    }
    
    private var profileHeader: some View {
        StandaloneSection {
            VStack(spacing: 10) {
                Button {
                    router.push(.editProfile)
                } label: {
                    avatarView
                        .frame(width: 72, height: 72)
                }
                
                Text(localizedDisplayName)
                    .customFont(size: 20, weight: .bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
    
    private var preferencesSection: some View {
        StandaloneSection(
            rows: "profile.preferences".localized,
            alignment: .leading,
            spacing: 12
        ) {
            CommonRowView(.init(title: "habit.profile.appearance".localized)) {
                AppSelector(
                    style: .iconToggle,
                    icon: .system(profileViewModel.colorScheme == .light
                                  ? "sun.max"
                                  : "moon"),
                    isLeadingIcon: profileViewModel.colorScheme == .light,
                    trackColor: profileViewModel.colorScheme == .light
                    ? Color(red: 1.0, green: 0.70, blue: 0.02)
                    : Color(red: 0.08, green: 0.29, blue: 0.40),
                    iconColor: profileViewModel.colorScheme == .light
                    ? .white
                    : Color(red: 1.0, green: 0.70, blue: 0.02)
                ) {
                    profileViewModel.updateColorScheme(
                        profileViewModel.colorScheme == .light ? .dark : .light
                    )
                }
            }

            CommonRowView(.init(title: "habit.profile.startDay".localized)) {
                AppSelector(
                    style: .labelToggle,
                    label: profileViewModel.weekStartsOnMonday ? "MO" : "SU",
                    isOn: profileViewModel.weekStartsOnMonday,
                    trackColor: Color.primary.opacity(0.12)
                ) {
                    let enabled = !profileViewModel.weekStartsOnMonday
                    profileViewModel.updateWeekStartsOnMonday(enabled)
                }
            }

            CommonRowView(.init(title: "settings.finance.earliestMonth".localized)) {
                Button {
                    isEarliestMonthPickerPresented = true
                } label: {
                    Text(earliestFinanceMonth.title)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .appGlassEffect(
                            .regular.interactive()
                        )
                }
            }

            CommonRowView(.init(title: "audioBook.speechSettings.title".localized)) {
                Button { isSpeechProviderSettingsPresented = true } label: {
                    Image(systemName: "waveform")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var selectedLanguage: AppLanguage {
        languageCode == AppLanguage.english.rawValue ? .english : .vietnamese
    }

    private var financeSecuritySection: some View {
        StandaloneSection("finance.lock.profile.section".localized) {
            CommonRowView(.init(title: "finance.lock.profile.row".localized)) {
                Button {
                    isFinanceLockSettingsPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: financeLockSystemImage)
                        Text(financeLockMethodTitle)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var financeLockMethodTitle: String {
        switch financeLockManager.method {
        case .none:
            "finance.lock.method.none".localized
        case .pin:
            "finance.lock.method.pin".localized
        case .biometrics:
            financeLockManager.biometry.title
        }
    }

    private var financeLockSystemImage: String {
        switch financeLockManager.method {
        case .none: "lock.open"
        case .pin: "number.square"
        case .biometrics: financeLockManager.biometry.systemImage
        }
    }
    
    private var backupSection: some View {
        HStack(spacing: 16) {
            CircularActionButtonStyle(
                imageName: "square.and.arrow.down",
                title: "profile.backup.import".localized,
                color: .Common.failure
            ) {
                isImporting = true
            }
            
            CircularActionButtonStyle(
                imageName: "square.and.arrow.up",
                title: "profile.backup.export".localized,
                color: .Common.success
            ) {
                profileViewModel.prepareExport()
            }
        }
        .padding(.vertical)
    }
    
    private var deleteSection: some View {
        StandaloneSection {
            Button(role: .destructive) {
                isClearDataConfirmationPresented = true
            } label: {
                Label("profile.backup.clear".localized, systemImage: "trash")
            }
        }
        .commonConfirmationDialog(
            isPresented: $isClearDataConfirmationPresented,
            title: "profile.backup.clear".localized,
            message: "common.delete.warning".localized,
            actions: [
                ConfirmationDialogAction("profile.backup.clear".localized, role: .destructive) {
                    profileViewModel.clearAllData {
                        profileViewModel.reload()
                        onDataChanged()
                    }
                },
                ConfirmationDialogAction("common.cancel".localized, role: .cancel) {}
            ]
        )
        .padding(.bottom)
    }
    
    private var avatarView: some View {
        Group {
            if let data = profileViewModel.userProfile?.avatarData,
               let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(Circle())
        .accessibilityLabel("habit.profile.edit".localized)
    }
    
    private var localizedDisplayName: String {
        guard let name = profileViewModel.userProfile?.displayName,
              name != "You" else {
            return "habit.profile.defaultName".localized
        }
        return name
    }
    
    private var earliestFinanceMonth: FinanceMonth {
        FinanceMonth(Date(timeIntervalSinceReferenceDate: earliestMonthTimestamp))
    }
    
    private var earliestMonthBinding: Binding<Date> {
        Binding(
            get: { earliestFinanceMonth.startDate },
            set: { earliestMonthTimestamp = FinanceMonth($0).startDate.timeIntervalSinceReferenceDate }
        )
    }
}
