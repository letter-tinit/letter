import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct UnifiedProfileScreen: View {
    @Environment(HabitProfileRouter.self) private var router
    @Environment(HabitViewModel.self) private var habitViewModel

    @State private var backupViewModel: AppBackupViewModel
    @State private var isImporting = false
    @State private var title = "profile.tab.title".localized
    @AppStorage(AppLanguage.preferenceKey) private var languageCode = AppLanguage.system.rawValue

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
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.push(.editProfile) } label: { avatarView }
            }
            .sharedBackgroundVisibility(.hidden)
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
            if case .failure(let error) = result {
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
        .confirmationDialog(
            "Restore Letter backup?",
            isPresented: Binding(
                get: { backupViewModel.pendingImport != nil },
                set: { if !$0 { backupViewModel.cancelImport() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Replace All Current Data", role: .destructive) {
                backupViewModel.confirmImport(habitViewModel: habitViewModel)
            }
            Button("Cancel", role: .cancel) { backupViewModel.cancelImport() }
        } message: {
            Text(backupViewModel.pendingImport?.summary.message ?? "")
        }
        .toast(message: backupViewModel.toastMessage)
    }

    private var profileHeader: some View {
        VStack(spacing: 10) {
            avatarView.frame(width: 72, height: 72)
            Text(habitViewModel.userProfile?.displayName ?? "You")
                .customSubTitle()
            Text("Your profile and preferences apply across Letter.")
                .customSubText()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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

            Toggle("Start week on Monday", isOn: Binding(
                get: { habitViewModel.weekStartsOnMonday },
                set: { habitViewModel.updateWeekStartsOnMonday($0) }
            ))

            Picker("Appearance", selection: Binding(
                get: { habitViewModel.colorScheme },
                set: { habitViewModel.updateColorScheme($0) }
            )) {
                ForEach(AppColorScheme.allCases) { scheme in
                    Text(scheme.title).tag(scheme)
                }
            }
        }
    }

    private var backupSection: some View {
        Section {
            Button {
                backupViewModel.prepareExport()
            } label: {
                Label("Export Letter Backup", systemImage: "square.and.arrow.up")
            }

            Button { isImporting = true } label: {
                Label("Import Letter Backup", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("One JSON file contains your profile, habits, balances, budgets, and net worth.")
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
        .accessibilityLabel("Edit profile")
    }
}

#Preview {
    let container = AppContainer(inMemory: true)
    UnifiedProfileScreen(factory: container)
        .modelContainer(container.modelContainer)
        .environment(container.makeHabitViewModel())
        .environment(HabitProfileRouter())
}
