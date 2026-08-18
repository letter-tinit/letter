//
//  FinanceProfileScreen.swift
//  Personal Finance
//

import SwiftUI
import UniformTypeIdentifiers

struct FinanceProfileScreen: View {
    @Environment(FinanceProfileRouter.self) private var router
    @State private var title: String = "profile.tab.title".localized
    @State private var backupViewModel: ProfileBackupViewModel
    @AppStorage(AppLanguage.preferenceKey) private var languageCode = AppLanguage.system.rawValue
    @State private var isImporting = false

    init(factory: AppViewModelFactory) {
        _backupViewModel = State(initialValue: factory.makeProfileBackupViewModel())
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }
    
    var body: some View {
        BaseScreen($title) {
            List {
                profileHeader
                
                Section("profile.preferences".localized) {
                    Picker("settings.language".localized, selection: $languageCode) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.localizationKey.localized)
                                .tag(language.rawValue)
                        }
                    }
                }
                
                Section {
                    Button {
                        backupViewModel.prepareExport()
                    } label: {
                        Label("profile.backup.export".localized, systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        isImporting = true
                    } label: {
                        Label("profile.backup.import".localized, systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("profile.backup".localized)
                } footer: {
                    Text("profile.backup.description".localized)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .fileExporter(
                isPresented: Binding(
                    get: { backupViewModel.exportDocument != nil },
                    set: { presented in
                        if !presented {
                            backupViewModel.clearExport()
                        }
                    }
                ),
                document: backupViewModel.exportDocument,
                contentType: .json,
                defaultFilename: "PersonalFinanceBackup"
            ) { result in
                if case .failure = result {
                    backupViewModel.makeToastError("profile.backup.error.save".localized)
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
                    guard let url = urls.first else { return }
                    backupViewModel.importBackup(from: url)
                case .failure:
                    backupViewModel.makeToastError("profile.backup.error.invalidFile".localized)
                }
            }
            .toast(message: backupViewModel.toastMessage)
        }
    }
}

private extension FinanceProfileScreen {
    var profileHeader: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 58))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("profile.header.title".localized)
                .customSubTitle()

            Text("profile.header.description".localized)
                .customSubText()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

#Preview {
    FinanceProfileScreen(factory: AppContainer(inMemory: true))
}
