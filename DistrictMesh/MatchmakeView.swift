import SwiftUI
import AppIntents

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
    private var invites: [GameInvite] {
        mesh.incomingInvites.values.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                intro
                // Teaches the "Hey Siri, find football players" phrase in-app.
                SiriTipView(intent: FindPlayersIntent())
                    .tint(DistrictTheme.accent)
                activityPicker
                lookButton
                if !invites.isEmpty { invitesSection }
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

    private var invitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Invites for you", systemImage: "envelope.fill")
                .font(.headline).foregroundStyle(.white)

            ForEach(invites) { invite in
                HStack(spacing: 12) {
                    InitialsAvatar(name: invite.from, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(invite.from).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text("Wants to play \(invite.activity)")
                            .font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Button {
                        MeshConnectivityManager.haptic(.light)
                        mesh.acceptInvite(from: invite.from)
                    } label: {
                        Label("Accept", systemImage: "checkmark")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(.green, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isLooking ? "\(activity.rawValue) players nearby" : "Start looking to see players")
                .font(.headline).foregroundStyle(.white)

            if players.isEmpty {
                Text(isLooking ? "Waiting for other \(activity.rawValue) players to appear\u{2026}"
                               : "Tap the button above to announce you're up for a game.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(players) { player in
                    PlayerRow(mesh: mesh, player: player)
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

    // Every player shown here already shares our activity, so the row's trailing
    // control reflects where we are in the invite → accept handshake.
    private var isTeammate: Bool { mesh.teammates.contains(player.name) }
    private var invitedThem: Bool { mesh.sentInvites.contains(player.name) }
    private var theyInvitedMe: Bool { mesh.incomingInvites[player.name] != nil }

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: player.name, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(player.activity).font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            trailingControl
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var trailingControl: some View {
        if isTeammate {
            Label("Teamed up", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.bold)).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.green, in: Capsule())
        } else if theyInvitedMe {
            Button {
                MeshConnectivityManager.haptic(.light)
                mesh.acceptInvite(from: player.name)
            } label: {
                Text("Accept").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(.green, in: Capsule())
            }
            .buttonStyle(.plain)
        } else if invitedThem {
            Text("Invited\u{2026}")
                .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(.white.opacity(0.08), in: Capsule())
        } else {
            Button {
                MeshConnectivityManager.haptic(.light)
                mesh.inviteToGame(player.name)
            } label: {
                Text("Invite").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(DistrictTheme.brandGradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
