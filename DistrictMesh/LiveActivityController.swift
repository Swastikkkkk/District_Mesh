import Foundation
import ActivityKit

/// Starts, updates, and ends the mesh-session Live Activity (Dynamic Island +
/// lock screen) based on how many buddies are connected. No-ops gracefully if
/// Live Activities are disabled or the widget extension isn't installed yet.
@MainActor
final class LiveActivityController {
    private var activity: Activity<DistrictWidgetsAttributes>?

    /// Reflects the current connected-buddy state into the Live Activity:
    /// starts one when the first buddy connects, updates the count/headline,
    /// and ends it when everyone disconnects.
    func sync(connectedPeers: [String], group: String) {
        let count = connectedPeers.count

        guard count > 0 else { end(); return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = DistrictWidgetsAttributes.ContentState(
            connectedCount: count,
            headline: headline(for: connectedPeers)
        )

        if let activity {
            Task { await activity.update(.init(state: state, staleDate: nil)) }
        } else {
            do {
                activity = try Activity.request(
                    attributes: DistrictWidgetsAttributes(group: group.isEmpty ? "open mesh" : group),
                    content: .init(state: state, staleDate: nil)
                )
            } catch {
                // Live Activities off, or widget extension not installed yet.
            }
        }
    }

    func end() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
    }

    private func headline(for peers: [String]) -> String {
        switch peers.count {
        case 0: return "No one nearby"
        case 1: return "\(peers[0]) nearby"
        case 2: return "\(peers[0]) + 1 nearby"
        default: return "\(peers[0]) + \(peers.count - 1) nearby"
        }
    }
}
