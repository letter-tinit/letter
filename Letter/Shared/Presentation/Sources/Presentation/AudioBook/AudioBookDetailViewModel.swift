import Foundation
import Observation

@Observable
@MainActor
public final class AudioBookDetailViewModel {
    public var expandedGroupIDs: Set<UUID> = []

    public init() {}

    public func setGroup(_ id: UUID, isExpanded: Bool) {
        if isExpanded {
            expandedGroupIDs.insert(id)
        } else {
            expandedGroupIDs.remove(id)
        }
    }
}
