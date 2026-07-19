import Foundation

/// Tiny App Group–backed store the app writes and the home-screen widget reads.
/// Add this file to the widget extension target's membership too, and give both
/// targets the App Group "group.com.swastik.districtmesh".
enum SharedStore {
    static let suiteName = "group.com.swastik.districtmesh"
    private static let buddiesKey = "buddyLocations"

    struct BuddySnapshot: Codable, Identifiable {
        var id: String { name }
        let name: String
        let lat: Double
        let lon: Double
        let date: Date
    }

    static func saveBuddies(_ buddies: [BuddySnapshot]) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(buddies) else { return }
        defaults.set(data, forKey: buddiesKey)
    }

    static func loadBuddies() -> [BuddySnapshot] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: buddiesKey),
              let buddies = try? JSONDecoder().decode([BuddySnapshot].self, from: data) else { return [] }
        return buddies
    }
}
