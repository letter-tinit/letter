//
//  CreateBudgetFormState.swift
//  Letter
//
//  Created by TiniT on 15/7/26.
//

import Foundation
import Domain
import Utility
import Styleguide

public enum CreateBudgetFormValidationError: Error, Equatable {
    case invalidIncome
    case invalidAllocationRatio
    case invalidAllocationTotal
    case invalidAllocationAmount
    case invalidAllocationAmountTotal
    case duplicatePeriod
}

public enum BudgetAllocationInputMode: String, CaseIterable, Identifiable {
    case ratio
    case amount

    public var id: Self { self }

    public var localizationKey: String {
        switch self {
        case .ratio: "budget.create.inputMode.ratio"
        case .amount: "budget.create.inputMode.amount"
        }
    }
}

public struct BudgetRatioFormItem: Identifiable, Equatable {
    public var id: BudgetBucketKind { kind }
    public let kind: BudgetBucketKind
    public var ratio: Decimal
    public var ratioText: String
    public var amountText: String
    public var isManuallyEdited: Bool
    public var lastEditedOrder: Int?
}

public struct CreateBudgetFormState: Equatable {
    public var periodStart: Date
    public var incomeText: String
    public var method: BudgetMethod
    public var allocationInputMode: BudgetAllocationInputMode
    public var allocationRatios: [BudgetRatioFormItem]
    public var reusesFixedExpensePlans: Bool
    private var editSequence: Int

    public init(
        templateBudget: Budget?,
        calendar: Calendar = .current,
        today: Date = .now,
        initialPeriodStart: Date? = nil
    ) {
        if let templateBudget {
            periodStart = calendar.nextMonth(after: templateBudget.periodStart)
            incomeText = templateBudget.income.toAmountString
            method = templateBudget.method
            allocationInputMode = .ratio
            let templateRatios = templateBudget.allocations
                .sortedByMethod(templateBudget.method)
                .map {
                    BudgetRatioFormItem(
                        kind: $0.kind,
                        ratio: $0.ratio,
                        ratioText: Self.percentText(for: $0.ratio),
                        amountText: $0.targetAmount.toAmountString,
                        isManuallyEdited: false,
                        lastEditedOrder: nil
                    )
                }
            allocationRatios = templateRatios.isEmpty
                ? Self.defaultRatios(for: templateBudget.method)
                : templateRatios
            reusesFixedExpensePlans = !templateBudget.fixedExpensePlans.isEmpty
            editSequence = 0
        } else {
            periodStart = calendar.startOfMonth(for: today)
            incomeText = ""
            method = .fiftyThirtyTwenty
            allocationInputMode = .ratio
            allocationRatios = Self.defaultRatios(for: .fiftyThirtyTwenty)
            reusesFixedExpensePlans = false
            editSequence = 0
        }

        if let initialPeriodStart {
            periodStart = calendar.startOfMonth(for: initialPeriodStart)
        }
    }

    mutating func resetAllocationRatios() {
        allocationRatios = Self.defaultRatios(for: method)
        if allocationInputMode == .amount {
            let income = parsedIncome ?? .zero
            allocationRatios = allocationRatios.map { item in
                var updatedItem = item
                updatedItem.amountText = (income * item.ratio).toAmountString
                return updatedItem
            }
        }
    }

    mutating func changeAllocationInputMode(to newMode: BudgetAllocationInputMode) {
        guard allocationInputMode != newMode else { return }
        let income = parsedIncome ?? .zero

        switch newMode {
        case .amount:
            allocationRatios = allocationRatios.map { item in
                var updatedItem = item
                updatedItem.amountText = (income * item.ratio).toAmountString
                return updatedItem
            }
        case .ratio:
            allocationRatios = allocationRatios.map { item in
                var updatedItem = item
                let amount = Self.parseAmount(item.amountText) ?? .zero
                let ratio = income > 0 ? amount / income : .zero
                updatedItem.ratio = ratio
                updatedItem.ratioText = Self.percentText(for: ratio)
                return updatedItem
            }
        }

        allocationInputMode = newMode
    }

    mutating func updateRatio(_ text: String, for kind: BudgetBucketKind) {
        guard let editedIndex = allocationRatios.firstIndex(where: { $0.kind == kind }) else { return }
        allocationRatios[editedIndex].ratioText = text

        guard let inputPercent = Self.parseDecimal(text) else { return }
        activateManualEdit(at: editedIndex)
        let otherManualTotal = allocationRatios.indices.reduce(Decimal.zero) { result, index in
            guard index != editedIndex, allocationRatios[index].isManuallyEdited else { return result }
            return result + allocationRatios[index].ratio * 100
        }
        let maximumPercent = max(100 - otherManualTotal, .zero)
        let editedPercent = min(max(inputPercent, .zero), maximumPercent)
        if editedPercent != inputPercent {
            allocationRatios[editedIndex].ratioText = NSDecimalNumber(
                decimal: editedPercent
            ).stringValue
        }
        allocationRatios[editedIndex].ratio = editedPercent / 100
        markAsMostRecentlyEdited(editedIndex)

        let values = allocationRatios.map { $0.ratio * 100 }
        let automaticIndices = allocationRatios.indices.filter {
            !allocationRatios[$0].isManuallyEdited
        }
        let redistributedValues = Self.distribute(
            total: max(100 - otherManualTotal - editedPercent, .zero),
            indices: automaticIndices,
            scale: nil,
            values: values
        )
        for index in automaticIndices {
            let ratio = redistributedValues[index] / 100
            allocationRatios[index].ratio = ratio
            allocationRatios[index].ratioText = Self.percentText(for: ratio)
        }
    }

    mutating func updateAmount(_ text: String, for kind: BudgetBucketKind) {
        guard let editedIndex = allocationRatios.firstIndex(where: { $0.kind == kind }) else { return }
        allocationRatios[editedIndex].amountText = text

        guard let income = parsedIncome,
              income > 0,
              let inputAmount = Self.parseAmount(text) else { return }
        activateManualEdit(at: editedIndex)
        let otherManualTotal = allocationRatios.indices.reduce(Decimal.zero) { result, index in
            guard index != editedIndex, allocationRatios[index].isManuallyEdited else { return result }
            return result + (Self.parseAmount(allocationRatios[index].amountText) ?? .zero)
        }
        let availableAmount = max(income - otherManualTotal, .zero)
        let amountStep: Decimal = income >= 100_000 ? 100_000 : income
        let maximumAmount = Self.roundDown(availableAmount, step: amountStep)
        let editedAmount = min(max(inputAmount, .zero), maximumAmount)
        if editedAmount != inputAmount {
            allocationRatios[editedIndex].amountText = editedAmount.toAmountString
        }
        markAsMostRecentlyEdited(editedIndex)

        let values = allocationRatios.map { Self.parseAmount($0.amountText) ?? .zero }
        let automaticIndices = allocationRatios.indices.filter {
            !allocationRatios[$0].isManuallyEdited
        }
        let redistributedValues = Self.distribute(
            total: max(income - otherManualTotal - editedAmount, .zero),
            indices: automaticIndices,
            scale: 0,
            values: values
        )
        for index in automaticIndices {
            allocationRatios[index].amountText = redistributedValues[index].toAmountString
        }
    }

    public func isAutoBalanced(_ kind: BudgetBucketKind) -> Bool {
        guard let item = allocationRatios.first(where: { $0.kind == kind }) else { return false }
        let manualCount = allocationRatios.count(where: \.isManuallyEdited)
        return !item.isManuallyEdited && manualCount == allocationRatios.count - 1
    }

    mutating func rebalanceAllocationAmounts() {
        guard allocationInputMode == .amount,
              let income = parsedIncome,
              income > 0,
              !allocationRatios.isEmpty else { return }

        let manualTotal = allocationRatios.reduce(Decimal.zero) { result, item in
            guard item.isManuallyEdited else { return result }
            return result + (Self.parseAmount(item.amountText) ?? .zero)
        }
        let automaticIndices = allocationRatios.indices.filter {
            !allocationRatios[$0].isManuallyEdited
        }
        let values = allocationRatios.map { Self.parseAmount($0.amountText) ?? .zero }
        let redistributedValues = Self.distribute(
            total: max(income - manualTotal, .zero),
            indices: automaticIndices,
            scale: 0,
            values: values
        )
        for index in automaticIndices {
            allocationRatios[index].amountText = redistributedValues[index].toAmountString
        }
    }

    public func validatedInput(
        existingBudgets: [Budget],
        calendar: Calendar = .current
    ) throws -> ValidatedBudgetInput {
        guard let income = parsedIncome, income > 0 else {
            throw CreateBudgetFormValidationError.invalidIncome
        }

        let buckets: [BudgetBucket]
        switch allocationInputMode {
        case .ratio:
            let ratios = try allocationRatios.map { item -> (BudgetBucketKind, Decimal) in
                let hasValidManualInput = !item.isManuallyEdited || Self.parseDecimal(item.ratioText) != nil
                guard hasValidManualInput,
                      item.ratio >= 0,
                      item.ratio <= 1 else {
                    throw CreateBudgetFormValidationError.invalidAllocationRatio
                }
                return (item.kind, item.ratio)
            }
            guard ratios.reduce(Decimal.zero, { $0 + $1.1 }) == 1 else {
                throw CreateBudgetFormValidationError.invalidAllocationTotal
            }
            buckets = ratios.map { kind, ratio in
                BudgetBucket(kind: kind, ratio: ratio, amount: income * ratio)
            }
        case .amount:
            let amounts = try allocationRatios.map { item -> (BudgetBucketKind, Decimal) in
                guard let amount = Self.parseAmount(item.amountText), amount >= 0 else {
                    throw CreateBudgetFormValidationError.invalidAllocationAmount
                }
                return (item.kind, amount)
            }
            guard amounts.reduce(Decimal.zero, { $0 + $1.1 }) == income else {
                throw CreateBudgetFormValidationError.invalidAllocationAmountTotal
            }
            buckets = amounts.map { kind, amount in
                BudgetBucket(kind: kind, ratio: amount / income, amount: amount)
            }
        }

        let monthStart = calendar.startOfMonth(for: periodStart)
        guard !existingBudgets.contains(where: {
            calendar.isDate($0.periodStart, equalTo: monthStart, toGranularity: .month)
        }) else {
            throw CreateBudgetFormValidationError.duplicatePeriod
        }

        return ValidatedBudgetInput(
            periodStart: monthStart,
            income: income,
            method: method,
            buckets: buckets,
            reusesFixedExpensePlans: reusesFixedExpensePlans
        )
    }

    private static func defaultRatios(for method: BudgetMethod) -> [BudgetRatioFormItem] {
        method.generateBucketByIncome(100).map {
            BudgetRatioFormItem(
                kind: $0.kind,
                ratio: $0.ratio,
                ratioText: percentText(for: $0.ratio),
                amountText: "",
                isManuallyEdited: false,
                lastEditedOrder: nil
            )
        }
    }

    private static func percentText(for ratio: Decimal) -> String {
        var percent = ratio * 100
        var roundedPercent = Decimal.zero
        NSDecimalRound(&roundedPercent, &percent, 2, .plain)
        return NSDecimalNumber(decimal: roundedPercent).stringValue
    }

    private static func parseDecimal(_ text: String) -> Decimal? {
        Decimal(
            string: text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
        )
    }

    private static func parseAmount(_ text: String) -> Decimal? {
        Decimal(string: text.filter(\.isNumber))
    }

    private static func round(_ value: Decimal, scale: Int) -> Decimal {
        var value = value
        var roundedValue = Decimal.zero
        NSDecimalRound(&roundedValue, &value, scale, .plain)
        return roundedValue
    }

    private static func roundDown(_ value: Decimal, step: Decimal) -> Decimal {
        guard step > 0 else { return .zero }
        var quotient = value / step
        var roundedQuotient = Decimal.zero
        NSDecimalRound(&roundedQuotient, &quotient, 0, .down)
        return roundedQuotient * step
    }

    private mutating func activateManualEdit(at editedIndex: Int) {
        guard isAutoBalanced(allocationRatios[editedIndex].kind),
              let previousIndex = allocationRatios.indices
                .filter({ $0 != editedIndex && allocationRatios[$0].isManuallyEdited })
                .max(by: {
                    (allocationRatios[$0].lastEditedOrder ?? 0) <
                        (allocationRatios[$1].lastEditedOrder ?? 0)
                }) else { return }

        allocationRatios[previousIndex].isManuallyEdited = false
        allocationRatios[previousIndex].lastEditedOrder = nil
    }

    private mutating func markAsMostRecentlyEdited(_ index: Int) {
        editSequence += 1
        allocationRatios[index].isManuallyEdited = true
        allocationRatios[index].lastEditedOrder = editSequence
    }

    private static func distribute(
        total: Decimal,
        indices: [Int],
        scale: Int?,
        values: [Decimal]
    ) -> [Decimal] {
        guard !indices.isEmpty else { return values }

        let currentTotal = indices.reduce(Decimal.zero) {
            $0 + max(values[$1], .zero)
        }
        var distributed = Decimal.zero
        var result = values

        for (offset, index) in indices.enumerated() {
            let newValue: Decimal
            if offset == indices.count - 1 {
                newValue = total - distributed
            } else {
                let weight = currentTotal > 0
                    ? max(values[index], .zero) / currentTotal
                    : 1 / Decimal(indices.count)
                let proportionalValue = total * weight
                newValue = scale.map { Self.round(proportionalValue, scale: $0) }
                    ?? proportionalValue
                distributed += newValue
            }
            result[index] = max(newValue, .zero)
        }
        return result
    }

    private var parsedIncome: Decimal? {
        Self.parseAmount(incomeText)
    }
}

extension Array where Element == BudgetAllocation {
    public func sortedByMethod(_ method: BudgetMethod) -> [BudgetAllocation] {
        let order = method.generateBucketByIncome(100).map(\.kind)
        return sorted {
            (order.firstIndex(of: $0.kind) ?? order.endIndex) <
                (order.firstIndex(of: $1.kind) ?? order.endIndex)
        }
    }
}

extension CreateBudgetFormValidationError {
    public var localizationKey: String {
        switch self {
        case .invalidIncome:
            "budget.create.error.income"
        case .invalidAllocationRatio:
            "budget.create.error.ratio"
        case .invalidAllocationTotal:
            "budget.create.error.ratioTotal"
        case .invalidAllocationAmount:
            "budget.create.error.allocationAmount"
        case .invalidAllocationAmountTotal:
            "budget.create.error.allocationAmountTotal"
        case .duplicatePeriod:
            "budget.create.error.duplicatePeriod"
        }
    }
}
