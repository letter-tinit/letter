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
        .deleteConfirmationDialog(
            isPresented: $viewModel.showsDeleteConfirmation,
            title: viewModel.deleteConfirmationTitle,
            message: viewModel.deleteConfirmationMessage,
            deleteTitle: "habit.delete.action".localized,
            deleteAction: deleteHabit
        )
        .sheet(item: $viewModel.activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .edit:
                    CreateHabitScreen(
                        viewModel: factory.makeCreateHabitViewModel(
                            mode: .edit(viewModel.habitID)
                        ),
                        onHabitSaved: { _ in
                            viewModel.load()
                            onHabitsChanged()
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
                Divider().opacity(0.28)
                detailRow(title: "habit.statistics.currentStreak".localized, value: "\(viewModel.currentStreak)")
                Divider().opacity(0.28)
                detailRow(title: "habit.statistics.bestStreak".localized, value: "\(viewModel.longestStreak)")
            }
        }
    }
    
    private func deleteHabit() {
        if viewModel.delete() {
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
