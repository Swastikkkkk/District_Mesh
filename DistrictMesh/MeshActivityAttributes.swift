import Foundation
import ActivityKit

/// Shared Live Activity model for an active mesh session (shown in the Dynamic
/// Island while you're connected). This file MUST be a member of BOTH the app
/// target AND the DistrictWidgets extension target (tick both in File Inspector →
/// Target Membership), because ActivityKit matches by the exact shared type.
struct DistrictWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Number of buddies currently connected.
        var connectedCount: Int
        /// Short status line, e.g. "Alex + 2 nearby" or "with Suryansh".
        var headline: String
        /// True while we're actively sharing our live location with the crew,
        /// which changes the title/icon shown in the Dynamic Island.
        var isSharingLocation: Bool = false
    }

    /// The mesh group name (fixed for the life of the activity).
    var group: String
}
