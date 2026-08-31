//
//  CreateNetWorthSnapshotFormState.swift
//  Letter
//

import Foundation
import Utility

public struct CreateNetWorthSnapshotFormState {
    public var month: Date

    public init(month: Date) {
        self.month = month
    }

    public func validatedMonth(
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

public enum CreateNetWorthSnapshotFormValidationError: Error {
    case duplicateMonth
}
