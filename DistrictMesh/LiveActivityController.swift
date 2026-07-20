import Foundation
import ActivityKit

/// Result of trying to start a Live Activity, so the UI can tell the user
/// exactly why nothing appeared instead of failing silently.
enum LiveActivityStart {
    case started
    case disabled          // user turned Live Activities off for the app
    case failed(String)    // ActivityKit threw — carries the error text
}

/// Starts, updates, and ends the mesh-session Live Activity (Dynamic Island +
/// lock screen). It reflects two things: how many buddies are connected, and
/// whether we're sharing our live location. No-ops gracefully if Live
/// Activities are disabled or the widget extension isn't installed yet.
@MainActor
final class LiveActivityController {
    private var activity: Activity<DistrictWidgetsAttributes>?

    var isRunning: Bool { activity != nil }

    /// Reflects the current mesh state into the Live Activity: shows one while
    /// buddies are connected OR we're sharing location, updates it, and ends it
    /// when neither is true.
    func update(connectedPeers: [String], group: String, sharingLocation: Bool) {
        let count = connectedPeers.count
        guard count > 0 || sharingLocation else { end(); return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = DistrictWidgetsAttributes.ContentState(
            connectedCount: count,
            headline: headline(for: connectedPeers, sharingLocation: sharingLocation),
            isSharingLocation: sharingLocation
        )
        try? request(state: state, group: group) // silent: off / extension missing
    }

    func end() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
    }

    /// Starts a stand-in "sharing location" Live Activity so the Dynamic Island
    /// can be previewed on a single device (no second buddy required). Reports
    /// precisely why it didn't appear so the user isn't left guessing.
    func startDemo() -> LiveActivityStart {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return .disabled }
        let state = DistrictWidgetsAttributes.ContentState(
            connectedCount: 1,
            headline: "with Suryansh",
            isSharingLocation: true
        )
        do {
            try request(state: state, group: "District")
            return .started
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: Private

    /// Requests a new activity, or updates the running one. Throws if
    /// `Activity.request` fails so callers that care can report the reason.
    private func request(state: DistrictWidgetsAttributes.ContentState, group: String) throws {
        if let activity {
            Task { await activity.update(.init(state: state, staleDate: nil)) }
            return
        }
        activity = try Activity.request(
            attributes: DistrictWidgetsAttributes(group: group.isEmpty ? "open mesh" : group),
            content: .init(state: state, staleDate: nil)
        )
    }

    private func headline(for peers: [String], sharingLocation: Bool) -> String {
        if sharingLocation {
            switch peers.count {
            case 0: return "Broadcasting to your crew"
            case 1: return "with \(peers[0])"
            default: return "with \(peers[0]) + \(peers.count - 1)"
            }
        }
        switch peers.count {
        case 0: return "No one nearby"
        case 1: return "\(peers[0]) nearby"
        case 2: return "\(peers[0]) + 1 nearby"
        default: return "\(peers[0]) + \(peers.count - 1) nearby"
        }
    }
}
