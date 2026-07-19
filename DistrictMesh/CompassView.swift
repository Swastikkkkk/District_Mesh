import SwiftUI
import CoreLocation

/// Points a big arrow toward a buddy and shows the distance — for finding your
/// crew in a crowd. Uses the location pings already coming over the mesh plus
/// the device compass heading.
struct CompassView: View {
    let mesh: MeshConnectivityManager
    @State private var selected: String?

    private var buddies: [BuddyLocation] {
        mesh.buddyLocations.values
            .filter { $0.name != mesh.myName }
            .sorted { $0.name < $1.name }
    }

    private var target: BuddyLocation? {
        if let selected, let b = mesh.buddyLocations[selected] { return b }
        return buddies.first
    }

    var body: some View {
        VStack(spacing: 22) {
            if buddies.count > 1 { picker }

            if mesh.isLocationDenied {
                message("location.slash", "Location is off",
                        "Turn on Location in Settings to use the compass.")
            } else if let target, let me = mesh.myCoordinate {
                compass(to: target, from: me)
            } else if target == nil {
                message("mappin.slash", "No buddy locations yet",
                        "Ask your crew to tap Share live location.")
            } else {
                message("location.circle", "Getting your location\u{2026}",
                        "Hold on while we find your position.")
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .districtBackground()
        .navigationTitle("Find a buddy")
        .onAppear {
            mesh.startCompass()
            if selected == nil { selected = buddies.first?.name }
        }
        .onDisappear { mesh.stopCompass() }
    }

    private var picker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(buddies) { b in
                    let on = (target?.name == b.name)
                    Button { selected = b.name } label: {
                        Text(b.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(on ? .white : .white.opacity(0.7))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(on ? AnyShapeStyle(DistrictTheme.brandGradient)
                                           : AnyShapeStyle(.white.opacity(0.1)), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func compass(to target: BuddyLocation, from me: CLLocationCoordinate2D) -> some View {
        let bearing = MeshConnectivityManager.bearing(from: me, to: target.coordinate)
        let arrowAngle = bearing - mesh.deviceHeading
        let meters = CLLocation(latitude: me.latitude, longitude: me.longitude)
            .distance(from: CLLocation(latitude: target.coordinate.latitude, longitude: target.coordinate.longitude))
        // GPS bearing is meaningless within ~25 m (it's just noise), so don't
        // show a spinning arrow — say they're basically together.
        let tooClose = meters < 25
        let stale = Date().timeIntervalSince(target.date) > 120

        return VStack(spacing: 18) {
            Text(target.name).font(.title.bold()).foregroundStyle(.white)

            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 2).frame(width: 270, height: 270)
                Circle().stroke(.white.opacity(0.06), lineWidth: 1).frame(width: 200, height: 200)
                if tooClose {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 90, weight: .bold))
                        .foregroundStyle(DistrictTheme.accent)
                } else {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 130, weight: .bold))
                        .foregroundStyle(stale ? .white.opacity(0.4) : DistrictTheme.accent)
                        .rotationEffect(.degrees(arrowAngle))
                        .animation(.easeOut(duration: 0.25), value: arrowAngle)
                }
            }
            .padding(.vertical, 8)

            if tooClose {
                Text("You're together")
                    .font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("~\(Int(meters.rounded())) m apart")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
            } else {
                Text(distanceText(meters))
                    .font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }

            Text(stale ? "Last seen \(target.date, style: .relative) \u{2014} may be off"
                       : "Updated \(target.date, style: .relative)")
                .font(.caption).foregroundStyle(stale ? DistrictTheme.alert.opacity(0.9) : .white.opacity(0.5))

            if !mesh.headingActive && !tooClose {
                Label("Move the phone in a figure-8 to calibrate the compass", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func distanceText(_ meters: Double) -> String {
        meters < 1000 ? "\(Int(meters.rounded())) m"
                      : String(format: "%.1f km", meters / 1000)
    }

    private func message(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 46)).foregroundStyle(.white.opacity(0.5))
            Text(title).font(.headline).foregroundStyle(.white)
            Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }
}
