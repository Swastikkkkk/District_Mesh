//
//  DistrictWidgets.swift
//  DistrictWidgets
//
//  Created by Swastik on 19/07/26.
//

import WidgetKit
import SwiftUI

// MARK: - Shared data

/// Small home-screen widget showing how many buddies are currently on the mesh.
/// Reads the App Group store the app writes to (see `SharedStore` in the app
/// target). The decode is duplicated here so the widget compiles even if
/// `SharedStore.swift` isn't a member of this extension target.
private enum WidgetData {
    static let suiteName = "group.com.swastik.districtmesh"
    static let buddiesKey = "buddyLocations"

    struct Buddy: Codable { let name: String; let date: Date }

    static func buddies() -> [Buddy] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: buddiesKey),
              let buddies = try? JSONDecoder().decode([Buddy].self, from: data) else { return [] }
        return buddies.sorted { $0.name < $1.name }
    }
}

// MARK: - Timeline

struct MeshEntry: TimelineEntry {
    let date: Date
    let names: [String]
    var count: Int { names.count }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MeshEntry {
        MeshEntry(date: Date(), names: ["Alex", "Sam"])
    }

    func getSnapshot(in context: Context, completion: @escaping (MeshEntry) -> Void) {
        completion(MeshEntry(date: Date(), names: WidgetData.buddies().map(\.name)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeshEntry>) -> Void) {
        let entry = MeshEntry(date: Date(), names: WidgetData.buddies().map(\.name))
        // Refresh periodically; the app also nudges reloads as buddies change.
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - View

struct DistrictWidgetsEntryView: View {
    var entry: MeshEntry
    private let accent = Color(red: 0.45, green: 0.30, blue: 0.95)

    private var subtitle: String {
        switch entry.count {
        case 0: return "No one nearby"
        case 1: return entry.names[0]
        case 2: return "\(entry.names[0]) + 1"
        default: return "\(entry.names[0]) + \(entry.count - 1)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.headline)
                    .foregroundStyle(entry.count > 0 ? accent : .secondary)
                Text("Mesh")
                    .font(.headline)
                Spacer()
            }

            Spacer(minLength: 0)

            Text("\(entry.count)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(entry.count > 0 ? .primary : .secondary)
            Text(entry.count == 1 ? "buddy nearby" : "buddies nearby")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(subtitle)
                .font(.caption2.weight(.medium))
                .foregroundStyle(entry.count > 0 ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct DistrictWidgets: Widget {
    let kind: String = "DistrictWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DistrictWidgetsEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Mesh status")
        .description("Shows how many buddies are on your mesh right now.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    DistrictWidgets()
} timeline: {
    MeshEntry(date: .now, names: [])
    MeshEntry(date: .now, names: ["Alex"])
    MeshEntry(date: .now, names: ["Alex", "Sam", "Jordan"])
}
