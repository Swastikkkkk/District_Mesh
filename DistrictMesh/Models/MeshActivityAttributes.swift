import Foundation
import ActivityKit

struct DistrictWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var connectedCount: Int
        var headline: String
        var isSharingLocation: Bool
    }
    var group: String
}
