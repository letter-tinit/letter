import Foundation

protocol NetWorthRepository {
    func fetchData() throws -> NetWorthData
    func saveSnapshot(_ snapshot: NetWorthSnapshot) throws
    func savePlanItem(_ item: NetWorthPlanItem) throws
    func deletePlanItem(id: UUID) throws
    func deleteSnapshot(id: UUID) throws
}
