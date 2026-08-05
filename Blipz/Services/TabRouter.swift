import Observation

enum AppTab {
    case today
    case ranks
    case you
}

/// Lets a screen switch tabs programmatically (e.g. Today's "Today's board ›" row
/// jumping to Ranks) without threading a selection binding through every view.
@Observable
final class TabRouter {
    static let shared = TabRouter()
    var selected: AppTab = .today
    private init() {}
}
