import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct ProfileScreen: View {
    @AppStorage(AppLanguage.preferenceKey)
    private var languageCode = AppLanguage.vietnamese.rawValue
    @AppStorage(FinanceSettings.earliestMonthKey)
    private var earliestMonthTimestamp = FinanceMonth(.now).startDate.timeIntervalSinceReferenceDate
    
    @Environment(ProfileRouter.self) private var router
    @Environment(HabitViewModel.self) private var habitViewModel
    @Environment(FinanceLockManager.self) private var financeLockManager
    
    @State private var backupViewModel: AppBackupViewModel
    @State private var isImporting = false
    @State private var title = "profile.tab.title".localized
    @State private var isEarliestMonthPickerPresented = false
    @State private var isFinanceLockSettingsPresented = false
    
    init(factory: AppViewModelFactory) {
        _backupViewModel = State(initialValue: factory.makeAppBackupViewModel())
    }
    
    var body: some View {
        @Bindable var habitViewModel = habitViewModel
        
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
            habitViewModel.fetchUserProfile()
            title = habitViewModel.profileTitle
        }
        .fileExporter(
            isPresented: Binding(
                get: { backupViewModel.exportDocument != nil },
                set: { if !$0 { backupViewModel.clearExport() } }
            ),
            document: backupViewModel.exportDocument,
            contentType: .json,
            defaultFilename: "LetterBackup-\(Date().toString(withFormat: .custom("yyyy-MM-dd")))"
        ) { result in
            switch result {
            case .success:
                backupViewModel.toastMessage = ToastMessage(
                    text: "app.backup.export.success".localized,
                    type: .success
                )
            case .failure(let error):
                backupViewModel.toastMessage = ToastMessage(
                    text: error.localizedDescription,
                    type: .failure
                )
            }
            backupViewModel.clearExport()
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { backupViewModel.prepareImport(from: url) }
            case .failure(let error):
                backupViewModel.toastMessage = ToastMessage(
                    text: error.localizedDescription,
                    type: .failure
                )
            }
        }
        .commonConfirmationDialog(
            isPresented: Binding(
                get: { backupViewModel.pendingImport != nil },
                set: { if !$0 { backupViewModel.cancelImport() } }
            ),
            title: "habit.backup.restore.title".localized,
            message: backupViewModel.pendingImport?.summary.message ?? "",
            actions: [
                ConfirmationDialogAction("habit.backup.restore.action".localized, role: .destructive) {
                    backupViewModel.confirmImport(habitViewModel: habitViewModel)
                },
                ConfirmationDialogAction("common.cancel".localized, role: .cancel) {
                    backupViewModel.cancelImport()
                }
            ]
        )
        .toast(message: backupViewModel.toastMessage)
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
        StandaloneSection("profile.preferences".localized) {
            VStack(alignment: .leading, spacing: 12) {
                CommonRowView(.init(title: "habit.profile.appearance".localized)) {
                    AppSelector(
                        style: .iconToggle,
                        icon: .system(habitViewModel.colorScheme == .light
                                      ? "sun.max"
                                      : "moon"),
                        isLeadingIcon: habitViewModel.colorScheme == .light,
                        trackColor: habitViewModel.colorScheme == .light
                        ? Color(red: 1.0, green: 0.70, blue: 0.02)
                        : Color(red: 0.08, green: 0.29, blue: 0.40),
                        iconColor: habitViewModel.colorScheme == .light
                        ? .white
                        : Color(red: 1.0, green: 0.70, blue: 0.02)
                    ) {
                        habitViewModel.updateColorScheme(
                            habitViewModel.colorScheme == .light ? .dark : .light
                        )
                    }
                }
                
                Divider()
                
                CommonRowView(.init(title: "habit.profile.startDay".localized)) {
                    AppSelector(
                        style: .labelToggle,
                        label: habitViewModel.weekStartsOnMonday ? "MO" : "SU",
                        isOn: habitViewModel.weekStartsOnMonday,
                        trackColor: Color.primary.opacity(0.12)
                    ) {
                        habitViewModel.updateWeekStartsOnMonday(
                            !habitViewModel.weekStartsOnMonday
                        )
                    }
                }
                
                Divider()
                
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
        StandaloneSection("profile.backup".localized) {
            VStack(alignment: .leading) {
                CommonRowView(.init(title: "habit.backup.export".localized)) {
                    Button {
                        backupViewModel.prepareExport()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.glass)
                }
                
                Divider()
                
                CommonRowView(.init(title: "habit.backup.import".localized)) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
    
    private var deleteSection: some View {
        StandaloneSection {
            Button(role: .destructive) {
                backupViewModel.isClearDataConfirmationPresented = true
            } label: {
                Label("profile.backup.clear".localized, systemImage: "trash")
            }
        }
        .commonConfirmationDialog(
            isPresented: $backupViewModel.isClearDataConfirmationPresented,
            title: "profile.backup.clear".localized,
            message: "common.delete.warning".localized,
            actions: [
                ConfirmationDialogAction("profile.backup.clear".localized, role: .destructive) {
                    backupViewModel.clearAllData()
                    habitViewModel.reloadAfterBackupImport()
                },
                ConfirmationDialogAction("common.cancel".localized, role: .cancel) {}
            ]
        )
        .padding(.bottom)
    }
    
    private var avatarView: some View {
        Group {
            if let data = habitViewModel.userProfile?.avatarData,
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
        guard let name = habitViewModel.userProfile?.displayName,
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

#Preview {
    let container = AppContainer(inMemory: true)
    ProfileScreen(factory: container)
        .modelContainer(container.modelContainer)
        .environment(container.makeHabitViewModel())
        .environment(ProfileRouter())
        .environment(FinanceLockManager())
}
