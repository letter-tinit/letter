//
//  HabitDetailView.swift
//  Letter
//
//  Created by TiniT on 29/4/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct HabitDetailScreen: View {
    private let factory: AppViewModelFactory
    private let onHabitsChanged: () -> Void
    @State private var viewModel: HabitDetailViewModel

    public init(
        viewModel: HabitDetailViewModel,
        factory: AppViewModelFactory,
        onHabitsChanged: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.factory = factory
        self.onHabitsChanged = onHabitsChanged
    }
    
    public var body: some View {
        Group {
            if viewModel.habit != nil {
                HabitDetailContentView(
                    viewModel: viewModel,
                    factory: factory,
                    onHabitsChanged: onHabitsChanged
                )
            } else {
                CommonEmptyView(description: "habit.detail.noneSelected".localized)
            }
        }
        .task { viewModel.load() }
    }
}

public struct HabitDetailContentView: View {
    @Environment(HabitRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: HabitDetailViewModel
    private let factory: AppViewModelFactory
    private let onHabitsChanged: () -> Void
    
    @FocusState private var isFocused: Bool
    public init(
        viewModel: HabitDetailViewModel,
        factory: AppViewModelFactory,
        onHabitsChanged: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.factory = factory
        self.onHabitsChanged = onHabitsChanged
    }
    
    public var body: some View {
        BaseScreen($viewModel.title) {
            VStack {
                header
                content
                if !viewModel.isArchived {
                    startVersionButton
                }
                
                Spacer()
            }
            .padding(.top)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        }
        // MARK: - ToolBar
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Haptic.selection()
                        viewModel.activeSheet = .edit
                    } label: {
                        Label("common.edit".localized, systemImage: "pencil")
                    }

                    Button {
                        Haptic.selection()
                        viewModel.showsArchiveConfirmation = true
                    } label: {
                        Label(
                            viewModel.isArchived ? "common.unarchive".localized : "common.archive".localized,
                            systemImage: viewModel.isArchived
                                ? "tray.and.arrow.up"
                                : "archivebox"
                        )
                    }

                    Divider()

                    Button(role: .destructive) {
                        Haptic.selection()
                        viewModel.showsDeleteConfirmation = true
                    } label: {
                        Label("common.delete".localized, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .commonConfirmationDialog(
            isPresented: $viewModel.showsArchiveConfirmation,
            title: (viewModel.isArchived ? "habit.unarchive.confirmation" : "habit.archive.confirmation").localized,
            message: (viewModel.isArchived ? "habit.unarchive.description" : "habit.archive.description").localized,
            actions: [
                ConfirmationDialogAction(
                    (viewModel.isArchived ? "habit.unarchive.action" : "habit.archive.action").localized,
                    role: viewModel.isArchived ? nil : .destructive,
                    action: archiveHabit
                ),
                ConfirmationDialogAction("common.cancel".localized, role: .cancel) {}
            ]
        )
        .deleteConfirmationDialog(
            isPresented: $viewModel.showsDeleteConfirmation,
            title: viewModel.deleteConfirmationTitle,
            message: viewModel.deleteConfirmationMessage,
            deleteTitle: (viewModel.canDeleteSeries ? "habit.delete.version" : "habit.delete.action").localized,
            deleteAction: deleteHabit,
            additionalDeleteActions: viewModel.canDeleteSeries
            ? [
                ConfirmationDialogAction(
                    "habit.delete.allVersions".localized(viewModel.seriesHabitCount),
                    role: .destructive,
                    action: deleteHabitSeries
                )
            ]
            : []
        )
        .sheet(item: $viewModel.activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .edit:
                    CreateHabitScreen(
                        viewModel: factory.makeCreateHabitViewModel(
                            mode: .edit(viewModel.habitID)
                        ),
                        onStartNewVersion: {
                            viewModel.activeSheet = .newVersion
                        },
                        onHabitSaved: { _ in
                            viewModel.load()
                            onHabitsChanged()
                        }
                    )
                case .newVersion:
                    CreateHabitScreen(
                        viewModel: factory.makeCreateHabitViewModel(
                            mode: .newVersion(viewModel.habitID)
                        ),
                        onHabitSaved: { newHabitID in
                            viewModel.activeSheet = nil
                            onHabitsChanged()
                            router.path = [.habitDetail(newHabitID)]
                        }
                    )
                }
            }
        }
    }
    
    private var header: some View {
        // MARK: HEADER
        StandaloneSection {
            HStack(spacing: 14) {
                Button {
                    baseAnimation {
                        isFocused = true
                    }
                } label: {
                    let color = Color(hex: viewModel.colorHex)
                    Image(module: viewModel.icon)
                        .padding(16)
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                        .appGlassEffect(
                            .regular.tint(color.opacity(0.2))
                        )
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.name)
                        .customFont(.title3, weight: .semibold)
                    
                    Text(
                        viewModel.habitDescription.isEmpty
                            ? "common.nil.note".localized
                            : viewModel.habitDescription
                    )
                        .customFont(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                
                Spacer(minLength: 0)
            }
        }
    }
    
    // MARK: CONTENT
    private var content: some View {
        StandaloneSection("common.description".localized) {
            VStack(spacing: 0) {
                detailRow(title: "habit.repeat.title".localized, value: viewModel.repeatTitle)
                Divider().opacity(0.28)
                detailRow(title: "habit.reminder.title".localized, value: viewModel.reminderTitle)
                Divider().opacity(0.28)
                detailRow(title: "habit.goal.title".localized, value: viewModel.goalTitle)
                if viewModel.shouldShowVersionInfo {
                    Divider().opacity(0.28)
                    detailRow(
                        title: "habit.version.title".localized,
                        value: "habit.version.number".localized(viewModel.displayVersionNumber)
                    )
                }
                if let previousVersionNumber = viewModel.previousVersionNumber {
                    Divider().opacity(0.28)
                    detailRow(
                        title: "habit.version.continuesFrom".localized,
                        value: "habit.version.number".localized(previousVersionNumber)
                    )
                }
                if let nextVersionNumber = viewModel.nextVersionNumber {
                    Divider().opacity(0.28)
                    detailRow(
                        title: "habit.version.continuedBy".localized,
                        value: "habit.version.number".localized(nextVersionNumber)
                    )
                }
                Divider().opacity(0.28)
                detailRow(title: "habit.statistics.currentStreak".localized, value: "\(viewModel.currentStreak)")
                Divider().opacity(0.28)
                detailRow(title: "habit.statistics.bestStreak".localized, value: "\(viewModel.longestStreak)")
                if let archivedAt = viewModel.archivedAt {
                    Divider().opacity(0.28)
                    detailRow(
                        title: "habit.archive.date".localized,
                        value: archivedAt.toString(withFormat: .custom("MMM d, yyyy"))
                    )
                }
            }
        }
    }
    
    // MARK: START NEW VERSION
    private var startVersionButton: some View {
        StandaloneSection("common.versioning".localized) {
            Button {
                viewModel.activeSheet = .newVersion
            } label: {
                HStack(spacing: 10) {
                    Image(module: "arrow.triangle.2.circlepath")
                        .customFont(.headline, weight: .semibold)
                    
                    Text("habit.version.start".localized(viewModel.displayVersionNumber + 1))
                        .customFont(.subheadline, weight: .semibold)
                    
                    Spacer(minLength: 0)
                    
                    Image(module: "chevron.right")
                        .customFont(.caption, weight: .bold)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func archiveHabit() {
        guard viewModel.toggleArchive() else { return }
        onHabitsChanged()
    }
    
    private func deleteHabit() {
        if viewModel.delete() {
            onHabitsChanged()
            dismiss()
        }
    }
    
    private func deleteHabitSeries() {
        if viewModel.deleteSeries() {
            onHabitsChanged()
            dismiss()
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .customFont(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .customFont(.subheadline, weight: .semibold)
        }
        .frame(minHeight: 48)
    }
}
