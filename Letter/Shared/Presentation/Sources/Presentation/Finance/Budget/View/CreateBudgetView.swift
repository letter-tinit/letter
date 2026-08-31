//
//  CreateBudgetView.swift
//  Letter
//
//  Created by TiniT on 15/7/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct CreateBudgetView: View {
    @Environment(BudgetViewModel.self) private var budgetViewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss

    public let existingBudgets: [Budget]
    public let templateBudget: Budget?

    @State private var formState: CreateBudgetFormState
    @State private var toastMessage: ToastMessage?
    @State private var showPicker = false

    public init(
        existingBudgets: [Budget],
        templateBudget: Budget?,
        initialPeriodStart: Date? = nil
    ) {
        self.existingBudgets = existingBudgets
        self.templateBudget = templateBudget
        _formState = State(
            initialValue: CreateBudgetFormState(
                templateBudget: templateBudget,
                initialPeriodStart: initialPeriodStart
            )
        )
    }

    public var body: some View {
        ZStack {
            Color.Common.background.ignoresSafeArea()

            AppScrollView {
                VStack {
                    StandaloneSection(
                        rows: "budget.create.section.setup".localized,
                        alignment: .leading,
                        footer: existingBudgets.isEmpty
                        ? nil
                        : "budget.create.reuseValues.description".localized
                    ) {
                        Button {
                            showPicker = true
                        } label: {
                            Text(formState.periodStart.toString(withFormat: .monthAndYear))
                                .customFont(.headline, weight: .semibold)
                        }

                        AmountField(
                            "budget.create.income".localized,
                            text: $formState.incomeText
                        )
                        .onChange(of: formState.incomeText) {
                            formState.rebalanceAllocationAmounts()
                        }

                        AppPicker(
                            "budget.create.method".localized,
                            selection: $formState.method,
                            layout: .labeledRow
                        ) {
                            ForEach(BudgetMethod.allCases, id: \.self) { method in
                                Text(method.localizationKey.localized)
                                    .tag(method)
                            }
                        }
                        .onChange(of: formState.method) {
                            formState.resetAllocationRatios()
                        }
                    }

                    if canReuseFixedExpensePlans {
                        StandaloneSection(
                            rows: nil,
                            alignment: .leading,
                            footer: "budget.create.reuseFixedPlans.description".localized
                        ) {
                            Toggle(
                                "budget.create.reuseFixedPlans".localized,
                                isOn: $formState.reusesFixedExpensePlans
                            )
                        }
                    }

                    StandaloneSection(
                        rows: "budget.create.section.preview".localized,
                        alignment: .leading,
                        footer: allocationTotalDescription,
                        footerColor: isAllocationTotalValid ? .secondary : .red
                    ) {
                        AppPicker(
                            "budget.create.inputMode".localized,
                            selection: Binding(
                                get: { formState.allocationInputMode },
                                set: { formState.changeAllocationInputMode(to: $0) }
                            ),
                            layout: .control
                        ) {
                            ForEach(BudgetAllocationInputMode.allCases) { mode in
                                Text(mode.localizationKey.localized).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        ForEach($formState.allocationRatios) { $allocation in
                            VStack(spacing: 10) {
                                HStack {
                                    Label(
                                        allocation.kind.localizationKey.localized,
                                        systemImage: allocation.kind.systemImageName
                                    )

                                    Spacer()

                                    if formState.allocationInputMode == .ratio {
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(displayedRatio(for: allocation))
                                                .foregroundStyle(.primary)
                                            Text(allocationSubtitle(
                                                value: previewAmount(for: allocation).formattedVND,
                                                kind: allocation.kind
                                            ))
                                            .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(allocation.amountText.isEmpty ? "0 ₫" : "\(allocation.amountText) ₫")
                                                .foregroundStyle(.primary)
                                            Text(allocationSubtitle(
                                                value: ratioText(for: allocation),
                                                kind: allocation.kind
                                            ))
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .customFont(.caption)

                                if formState.allocationInputMode == .ratio {
                                    Slider(
                                        value: ratioSliderBinding(for: allocation.kind),
                                        in: 0...100,
                                        step: 0.01
                                    )
                                } else {
                                    Slider(
                                        value: amountSliderBinding(for: allocation.kind),
                                        in: 0...max(previewIncome.doubleValue, 1),
                                        step: amountSliderStep
                                    )
                                    .disabled(previewIncome <= 0)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.bottom)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("budget.create.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            let currentYear = Calendar.current.component(.year, from: .now)
            let yearRange = (currentYear - 100)...(currentYear + 100)
            MonthYearPickerSheet(selectedDate: $formState.periodStart, yearRange: yearRange)
                .presentationDetents([.medium])
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel".localized) {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("budget.create.action".localized) {
                    createBudget()
                }
            }
        }
        .toast(message: toastMessage)
        .keyboardDoneButton()
    }
}

private extension CreateBudgetView {
    enum Field: Hashable {
        case income
    }

    public var previewIncome: Decimal {
        let normalizedAmount = formState.incomeText.filter(\.isNumber)
        return Decimal(string: normalizedAmount) ?? .zero
    }

    public var canReuseFixedExpensePlans: Bool {
        templateBudget?.fixedExpensePlans.isEmpty == false
    }

    public var totalRatioText: String {
        var total = formState.allocationRatios.reduce(Decimal.zero) { result, item in
            result + item.ratio * 100
        }
        var roundedTotal = Decimal.zero
        NSDecimalRound(&roundedTotal, &total, 2, .plain)
        return NSDecimalNumber(decimal: roundedTotal).stringValue
    }

    public var totalAllocationAmount: Decimal {
        formState.allocationRatios.reduce(Decimal.zero) { result, item in
            result + (Decimal(string: item.amountText.filter(\.isNumber)) ?? .zero)
        }
    }

    public var allocationTotalDescription: String {
        switch formState.allocationInputMode {
        case .ratio:
            String(format: "budget.create.ratioTotal".localized, totalRatioText)
        case .amount:
            String(
                format: "budget.create.amountTotal".localized,
                totalAllocationAmount.formattedVND,
                previewIncome.formattedVND
            )
        }
    }

    public var isAllocationTotalValid: Bool {
        switch formState.allocationInputMode {
        case .ratio: totalRatioText == "100"
        case .amount: previewIncome > 0 && totalAllocationAmount == previewIncome
        }
    }

    public var amountSliderStep: Double {
        min(100_000, max(previewIncome.doubleValue, 1))
    }

    public func previewAmount(for allocation: BudgetRatioFormItem) -> Decimal {
        previewIncome * allocation.ratio
    }

    public func ratioText(for allocation: BudgetRatioFormItem) -> String {
        let amount = Decimal(string: allocation.amountText.filter(\.isNumber)) ?? .zero
        guard previewIncome > 0 else { return "0%" }
        var percent = amount / previewIncome * 100
        var roundedPercent = Decimal.zero
        NSDecimalRound(&roundedPercent, &percent, 2, .plain)
        return "\(NSDecimalNumber(decimal: roundedPercent).stringValue)%"
    }

    public func displayedRatio(for allocation: BudgetRatioFormItem) -> String {
        var percent = allocation.ratio * 100
        var roundedPercent = Decimal.zero
        NSDecimalRound(&roundedPercent, &percent, 2, .plain)
        return "\(NSDecimalNumber(decimal: roundedPercent).stringValue)%"
    }

    public func allocationSubtitle(value: String, kind: BudgetBucketKind) -> String {
        guard formState.isAutoBalanced(kind) else { return value }
        return "\(value) · \("budget.create.autoBalanced".localized)"
    }

    public func ratioSliderBinding(for kind: BudgetBucketKind) -> Binding<Double> {
        Binding(
            get: {
                (formState.allocationRatios.first(where: { $0.kind == kind })?.ratio.doubleValue ?? 0) * 100
            },
            set: { value in
                var percent = Decimal(value)
                var roundedPercent = Decimal.zero
                NSDecimalRound(&roundedPercent, &percent, 2, .plain)
                formState.updateRatio(
                    NSDecimalNumber(decimal: roundedPercent).stringValue,
                    for: kind
                )
            }
        )
    }

    public func amountSliderBinding(for kind: BudgetBucketKind) -> Binding<Double> {
        Binding(
            get: {
                let amountText = formState.allocationRatios
                    .first(where: { $0.kind == kind })?
                    .amountText ?? ""
                return (Decimal(string: amountText.filter(\.isNumber)) ?? .zero).doubleValue
            },
            set: { value in
                let roundedValue = (value / amountSliderStep).rounded() * amountSliderStep
                let amount = Decimal(Int64(roundedValue.rounded()))
                formState.updateAmount(amount.toAmountString, for: kind)
            }
        )
    }

    public func createBudget() {
        do {
            let input = try formState.validatedInput(
                existingBudgets: existingBudgets
            )
            budgetViewModel.createBudget(input, template: templateBudget)
            dismiss()
        } catch let error as CreateBudgetFormValidationError {
            showError(error.localizationKey.localized)
        } catch {
            showError("budget.create.error.save".localized)
        }
    }
    
    public func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}

