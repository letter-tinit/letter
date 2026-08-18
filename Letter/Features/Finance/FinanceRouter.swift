import Observation

enum FinanceRoute: Hashable {
    case budget(Budget)
    case yearNetworth(NetWorthYear)
}

@Observable
final class FinanceRouter: AppRouter<FinanceRoute> {}
