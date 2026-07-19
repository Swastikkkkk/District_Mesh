import SwiftUI

/// Solo matchmaking: announce you're looking to team up for an activity and see
/// other solo players nearby doing the same, all over the mesh (no backend).
struct MatchmakeView: View {
    let mesh: MeshConnectivityManager
    @State private var activity = Activity.football

    enum Activity: String, CaseIterable, Identifiable {
        case football = "Football", cricket = "Cricket", badminton = "Badminton"
        case basketball = "Basketball", tennis = "Tennis", running = "Running"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .football: return "soccerball"
            case .cricket: return "figure.cricket"
            case .badminton: return "figure.badminton"
            case .basketball: return "basketball.fill"
            case .tennis: return "tennis.racket"
            case .running: return "figure.run"
            }
        }
    }

    private var isLooking: Bool { mesh.myLFGActivity != nil }
    private var players: [LFGPlayer] { mesh.activeLFGPlayers }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                intro
                activityPicker
                lookButton
                playersSection
            }
            .padding()
        }
        .districtBackground()
        .navigationTitle("Find players")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Solo? Team up.", systemImage: "person.3.sequence.fill")
                .font(.headline).foregroundStyle(.white)
            Text("Announce that you're looking to play, and match with other solo players around you.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(DistrictTheme.brandGradient, in: RoundedRectangle(cornerRadius: 20))
    }

    private var activityPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Activity.allCases) { a in
                    let on = (a == activity)
                    Button {
                        activity = a
                        if isLooking { mesh.startLookingForGame(a.rawValue) } // switch activity live
                    } label: {
                        Label(a.rawValue, systemImage: a.icon)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(on ? .white : .white.opacity(0.7))
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(on ? AnyShapeStyle(DistrictTheme.brandGradient)
                                           : AnyShapeStyle(.white.opacity(0.08)), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var lookButton: some View {
        Button {
            MeshConnectivityManager.haptic()
            if isLooking { mesh.stopLookingForGame() } else { mesh.startLookingForGame(activity.rawValue) }
        } label: {
            Label(isLooking ? "Stop looking" : "Look for \(activity.rawValue) players",
                  systemImage: isLooking ? "stop.circle.fill" : "magnifyingglass")
        }
        .buttonStyle(DistrictButtonStyle(
            tint: isLooking ? LinearGradient(colors: [.white.opacity(0.12)], startPoint: .top, endPoint: .bottom)
                            : DistrictTheme.brandGradient
        ))
    }

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isLooking ? "Players nearby" : "Start looking to see players")
                .font(.headline).foregroundStyle(.white)

            if players.isEmpty {
                Text(isLooking ? "Waiting for other solo players to appear\u{2026}"
                               : "Tap the button above to announce you're up for a game.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(players) { player in
                    PlayerRow(mesh: mesh, player: player, myActivity: mesh.myLFGActivity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

private struct PlayerRow: View {
    let mesh: MeshConnectivityManager
    let player: LFGPlayer
    let myActivity: String?

    private var isMatch: Bool { myActivity == player.activity }

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: player.name, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(player.activity).font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            if isMatch {
                Text("Match")
                    .font(.caption2.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.green, in: Capsule())
            }
            Button {
                MeshConnectivityManager.haptic(.light)
                mesh.sendMessage("Hey \(player.name), let's team up for \(player.activity)!")
                mesh.flashToast("Invite sent to chat")
            } label: {
                Text("Invite").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(DistrictTheme.brandGradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
