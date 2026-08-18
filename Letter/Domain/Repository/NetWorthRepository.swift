protocol NetWorthRepository {
    func addSnapshot(_ snapshot: NetWorthSnapshot) throws
    func addPlanItem(_ item: NetWorthPlanItem) throws
    func removePlanItem(_ item: NetWorthPlanItem) throws
    func save() throws
}
