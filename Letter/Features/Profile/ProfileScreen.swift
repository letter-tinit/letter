import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct ProfileScreen: View {
    @AppStorage(AppLanguage.preferenceKey)
    private var languageCode = AppLanguage.system.rawValue
    @AppStorage(FinanceSettings.earliestMonthKey)
    private var earliestMonthTimestamp = FinanceMonth(.now).startDate.timeIntervalSinceReferenceDate
    
    @Environment(ProfileRouter.self) private var router
    @Environment(HabitViewModel.self) private var habitViewModel

    @State private var backupViewModel: AppBackupViewModel
    @State private var isImporting = false
    @State private var title = "profile.tab.title".localized
    @State private var isEarliestMonthPickerPresented = false

    init(factory: AppViewModelFactory) {
        _backupViewModel = State(initialValue: factory.makeAppBackupViewModel())
    }

    var body: some View {
        @Bindable var habitViewModel = habitViewModel

        BaseScreen($title) {
            List {
                profileHeader
                preferencesSection
                backupSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        }
        .onAppear {
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
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 10) {
            Button {
                router.push(.editProfile)
            } label: {
                avatarView
                    .frame(width: 72, height: 72)
            }
            
            Text(localizedDisplayName)
                .customSubTitle()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var preferencesSection: some View {
        Section("profile.preferences".localized) {
            Picker("settings.language".localized, selection: $languageCode) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.localizationKey.localized).tag(language.rawValue)
                }
            }

            Button {
                isEarliestMonthPickerPresented = true
            } label: {
                HStack {
                    Text("settings.finance.earliestMonth".localized)
                    Spacer()
                    Text(earliestFinanceMonth.title)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("habit.profile.weekStartsMonday".localized, isOn: Binding(
                get: { habitViewModel.weekStartsOnMonday },
                set: { habitViewModel.updateWeekStartsOnMonday($0) }
            ))

            Picker("habit.profile.appearance".localized, selection: Binding(
                get: { habitViewModel.colorScheme },
                set: { habitViewModel.updateColorScheme($0) }
            )) {
                ForEach(AppColorScheme.allCases) { scheme in
                    Text(scheme.title.localized).tag(scheme)
                }
            }
        }
    }

    private var backupSection: some View {
        Section {
            Button {
                backupViewModel.prepareExport()
            } label: {
                Label("habit.backup.export".localized, systemImage: "square.and.arrow.up")
            }

            Button { isImporting = true } label: {
                Label("habit.backup.import".localized, systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("profile.backup".localized)
        } footer: {
            Text("habit.backup.description".localized)
        }
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
}
