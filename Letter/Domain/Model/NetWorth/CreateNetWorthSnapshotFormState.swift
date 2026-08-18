//
//  CreateNetWorthSnapshotFormState.swift
//  Letter
//

import Foundation

struct CreateNetWorthSnapshotFormState {
    var month: Date

    init(month: Date) {
        self.month = month
    }

    func validatedMonth(
        existingSnapshots: [NetWorthSnapshot],
        calendar: Calendar = .current
    ) throws -> Date {
        let monthStart = calendar.startOfMonth(for: month)
        guard !existingSnapshots.contains(where: {
            calendar.isDate($0.asOfDate, equalTo: monthStart, toGranularity: .month)
        }) else {
            throw CreateNetWorthSnapshotFormValidationError.duplicateMonth
        }

        return monthStart
    }
}

enum CreateNetWorthSnapshotFormValidationError: Error {
    case duplicateMonth
}
