//
//  CreateNetWorthSnapshotFormState.swift
//  Personal Finance
//

import Foundation

struct CreateNetWorthSnapshotFormState {
    var month: Date

    init(month: Date) {
        self.month = month
    }

    func validatedMonth(
        existingSnapshots: [NetWorthSnapshot],
        year: Int,
        calendar: Calendar = .current
    ) throws -> Date {
        let monthStart = calendar.startOfMonth(for: month)
        guard calendar.component(.year, from: monthStart) == year else {
            throw CreateNetWorthSnapshotFormValidationError.invalidYear
        }

        guard !existingSnapshots.contains(where: {
            calendar.isDate($0.asOfDate, equalTo: monthStart, toGranularity: .month)
        }) else {
            throw CreateNetWorthSnapshotFormValidationError.duplicateMonth
        }

        return monthStart
    }
}

enum CreateNetWorthSnapshotFormValidationError: Error {
    case invalidYear
    case duplicateMonth
}
