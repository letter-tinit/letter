//
//  CreateHabitView.swift
//  Letter
//
//  Created by TiniT on 15/5/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct CreateHabitScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateHabitViewModel
    
    private let onStartNewVersion: (() -> Void)?
    private let onHabitSaved: ((UUID) -> Void)?
    
    @State private var showSymbolPicker = false
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var showsVersionConfirmation = false
    
    public init(
        viewModel: CreateHabitViewModel,
        onStartNewVersion: (() -> Void)? = nil,
        onHabitSaved: ((UUID) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onStartNewVersion = onStartNewVersion
        self.onHabitSaved = onHabitSaved
    }
    
    public var body: some View {
        BaseScreen($viewModel.screenTitle) {
            AppScrollView {
                CreateHabitFormView(
                    viewModel: viewModel,
                    showSymbolPicker: $showSymbolPicker,
                    showStartDatePicker: $showStartDatePicker,
                    showEndDatePicker: $showEndDatePicker,
                    onStartNewVersion: onStartNewVersion
                )
            }
        }
        // MARK: - ToolBar
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if viewModel.isCreatingVersion {
                        showsVersionConfirmation = true
                    } else {
                        saveHabit()
                    }
                } label: {
                    Text((viewModel.isCreatingVersion ? "common.create" : "common.save").localized)
                        .fontWeight(viewModel.canSave ? .bold : .regular)
                }
                .disabled(!viewModel.canSave)
            }
        }
        .animation(.snappy, value: viewModel.goalType)
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerSheetView(
                selectedSymbol: $viewModel.icon,
                symbols: AppConstant.habitSymbolOptions,
                title: "habit.symbol.choose".localized
            )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStartDatePicker) {
            CalendarPickerSheetView(
                title: "habit.duration.startDate".localized,
                selectedDate: $viewModel.startDate,
                minimumDate: viewModel.minimumStartDate
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showEndDatePicker) {
            CalendarPickerSheetView(
                title: "habit.duration.endDate".localized,
                selectedDate: $viewModel.endDate,
                minimumDate: viewModel.startDate,
                clearTitle: viewModel.hasEndDate ? "habit.common.reset".localized : nil
            ) {
                viewModel.hasEndDate = true
            } onClear: {
                viewModel.hasEndDate = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .commonConfirmationDialog(
            isPresented: $showsVersionConfirmation,
            title: "habit.version.create.confirmation".localized(viewModel.targetVersionNumber),
            message: "habit.version.create.warning".localized(viewModel.targetVersionNumber),
            actions: [
                ConfirmationDialogAction("habit.version.create.action".localized(viewModel.targetVersionNumber)) {
                    saveHabit()
                },
                ConfirmationDialogAction("common.cancel".localized, role: .cancel) {}
            ]
        )
    }
    
    private func saveHabit() {
        guard let habitID = viewModel.save() else { return }
        onHabitSaved?(habitID)
        dismiss()
    }
}
