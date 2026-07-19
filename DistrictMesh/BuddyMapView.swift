import SwiftUI
import MapKit

/// Renders buddy location pings on a map. The pings arrive over the mesh (no
/// internet needed for the data), so each buddy's latest reported coordinate is
/// plotted as a labelled pin — red when they're broadcasting an emergency.
/// Pins update as fresh location packets come in.
///
/// NOTE: pins + coordinates work fully offline. The map *tiles* (street imagery)
/// still come from MapKit and need to be cached/online to draw — bundling an
/// offline basemap is a follow-up.
struct BuddyMapView: View {

    let mesh: MeshConnectivityManager

    /// Buddies sorted by name for a stable ordering in the list overlay.
    private var buddies: [BuddyLocation] {
        mesh.buddyLocations.values.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Map {
                ForEach(buddies) { buddy in
                    Marker(buddy.name, coordinate: buddy.coordinate)
                        .tint(mesh.emergencyBuddies.contains(buddy.name) ? DistrictTheme.alert : DistrictTheme.accent)
                }
            }
            .overlay {
                if buddies.isEmpty {
                    ContentUnavailableView(
                        "No pings yet",
                        systemImage: "mappin.slash",
                        description: Text("Tap \u{201C}Find My Buddy\u{201D} or send a location to see buddies here.")
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !buddies.isEmpty {
                    buddyList
                }
            }
            .navigationTitle("Buddy Map")
        }
    }

    private var buddyList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(buddies) { buddy in
                HStack {
                    Circle()
                        .fill(mesh.emergencyBuddies.contains(buddy.name) ? DistrictTheme.alert : DistrictTheme.accent)
                        .frame(width: 9, height: 9)
                    Text(buddy.name)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                    if buddy.name == mesh.myName {
                        Text("(you)").font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.4f, %.4f",
                                    buddy.coordinate.latitude,
                                    buddy.coordinate.longitude))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white)
                        Text(buddy.date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(16)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1)))
        .padding(.horizontal, 12)
    }
}
