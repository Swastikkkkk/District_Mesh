import AppIntents
import Foundation

/// The sports a solo player can look to team up for. Mirrors the activities in
/// `MatchmakeView`, exposed to App Intents so Siri and Shortcuts can pick one.
enum MatchmakeActivity: String, AppEnum {
    case football = "Football"
    case cricket = "Cricket"
    case badminton = "Badminton"
    case basketball = "Basketball"
    case tennis = "Tennis"
    case running = "Running"

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Activity" }

    static var caseDisplayRepresentations: [MatchmakeActivity: DisplayRepresentation] {
        [
            .football: "Football",
            .cricket: "Cricket",
            .badminton: "Badminton",
            .basketball: "Basketball",
            .tennis: "Tennis",
            .running: "Running",
        ]
    }
}

/// Where the app looks for a Siri/Shortcuts request that arrived while it was
/// backgrounded. The intent writes the requested activity here; the app reads
/// and clears it once it's active (see `MeshConnectivityManager`).
enum PendingMatchmake {
    static let key = "district.pendingLFGActivity"

    static func set(_ activity: String) {
        UserDefaults.standard.set(activity, forKey: key)
    }

    static func take() -> String? {
        let value = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        return value
    }
}

/// Pending in-app navigation requested by Siri/Shortcuts (e.g. open the buddy
/// map). Read and cleared by the app once it's active.
enum PendingRoute {
    static let openMapKey = "district.pendingOpenMap"

    static func requestOpenMap() {
        UserDefaults.standard.set(true, forKey: openMapKey)
    }

    static func takeOpenMap() -> Bool {
        let value = UserDefaults.standard.bool(forKey: openMapKey)
        UserDefaults.standard.removeObject(forKey: openMapKey)
        return value
    }
}

/// Siri / Shortcuts entry point: "Find football players" opens District, goes
/// live on the mesh, and starts looking for players of that sport.
struct FindPlayersIntent: AppIntent {
    static var title: LocalizedStringResource { "Find Players" }
    static var description: IntentDescription {
        IntentDescription("Announce that you're looking to team up for a game and match with solo players nearby.")
    }

    /// Bring the app to the foreground — the mesh only runs while the app is active.
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Activity")
    var activity: MatchmakeActivity

    static var parameterSummary: some ParameterSummary {
        Summary("Find \(\.$activity) players")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        PendingMatchmake.set(activity.rawValue)
        return .result(dialog: "Looking for \(activity.rawValue) players nearby\u{2026}")
    }
}

/// Siri / Shortcuts entry point: "Find my buddy" opens District, goes live on
/// the mesh, and shows the map of where connected buddies are.
struct ShowBuddyMapIntent: AppIntent {
    static var title: LocalizedStringResource { "Find My Buddy" }
    static var description: IntentDescription {
        IntentDescription("Open the map showing where your connected buddies are on the mesh.")
    }

    /// Bring the app to the foreground — the mesh only runs while the app is active.
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        PendingRoute.requestOpenMap()
        return .result(dialog: "Showing where your buddies are\u{2026}")
    }
}

/// Registers the spoken phrases so "Hey Siri, find football players" and
/// "Hey Siri, find my buddy" work without configuring anything in Shortcuts first.
struct DistrictShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindPlayersIntent(),
            phrases: [
                "Find \(\.$activity) players with \(.applicationName)",
                "Find \(\.$activity) players on \(.applicationName)",
                "Find players with \(.applicationName)",
                "\(.applicationName) find me a game",
            ],
            shortTitle: "Find Players",
            systemImageName: "person.3.sequence.fill"
        )
        AppShortcut(
            intent: ShowBuddyMapIntent(),
            phrases: [
                "Find my buddy with \(.applicationName)",
                "Find my buddies with \(.applicationName)",
                "Where are my buddies on \(.applicationName)",
                "Show my buddy map with \(.applicationName)",
                "Locate my crew with \(.applicationName)",
            ],
            shortTitle: "Find My Buddy",
            systemImageName: "map.fill"
        )
    }
}
