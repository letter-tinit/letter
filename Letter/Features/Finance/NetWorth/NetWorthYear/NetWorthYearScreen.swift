//
//  NetWorthYearScreen.swift
//  Personal Finance
//
//  Created by TiniT on 20/7/26.
//

import SwiftUI

struct NetWorthYearScreen: View {
    let data: NetWorthYear
    
    init(data: NetWorthYear) {
        self.data = data
    }
    
    var body: some View {
        @Bindable var data = data
        if let snapshot = data.snapshots.first(where: { $0.asOfDate.isInCurrentMonth }) {
            NetWorthView(
                year: data,
                snapshot: snapshot,
                statusMessage: nil,
                onDeleteItem: deleteItem
            )
        } else if let snapshot = data.snapshots.first(where: { $0.asOfDate.isMonth(1) }) {
            NetWorthView(
                year: data,
                snapshot: snapshot,
                statusMessage: nil,
                onDeleteItem: deleteItem
            )
        } else {
            CommonEmptyView()
        }
    }

    private var suggestedMonth: Date {
        Calendar.current.nextMonth(after: data.snapshots.max(by: { $0.asOfDate < $1.asOfDate })?.asOfDate
            ?? Calendar.current.startOfMonth(for: Date()))
    }

    private func deleteItem(id: UUID) throws {
        try data.removeItem(id: id)
    }
}
