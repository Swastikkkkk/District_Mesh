import SwiftUI
import MapKit

/// The whole mesh experience on ONE screen: status, Go Live, Guardian (safety /
/// anti-theft), the people around you (call / video), a live map preview, and
/// chat. Full Chat and Map open as sheets. Composed of small subviews so a
/// single state change only redraws its own card.
struct MeshTestView: View {

    let mesh: MeshConnectivityManager

    @State private var showSettings = false
    @State private var showTour = false
    @State private var showChat = false
    @State private var showMap = false
    @AppStorage("district.tourSeen") private var tourSeen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HeaderCard(mesh: mesh)
                    PermissionsBanner(mesh: mesh)
                    GoLiveButton(mesh: mesh)
                    GuardianCard(mesh: mesh)
                    MatchmakeCard(mesh: mesh)
                    PeopleCard(mesh: mesh)
                    MapPreviewCard(mesh: mesh, showMap: $showMap)
                    ChatCard(mesh: mesh, showChat: $showChat)
                }
                .padding()
            }
            .districtBackground()
            .overlay(alignment: .bottom) { ToastView(message: mesh.toast) }
            .animation(.spring(duration: 0.3), value: mesh.toast)
            .navigationTitle("District")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { showTour = true } label: { Image(systemName: "questionmark.circle") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }
                }
            }
        }
        .tint(DistrictTheme.accent)
        .sheet(isPresented: Binding(
            get: { mesh.voice.isInCall },
            set: { if !$0 { mesh.endCall() } }
        )) { CallView(voice: mesh.voice) }
        .sheet(isPresented: $showSettings) { SettingsView(mesh: mesh) }
        .sheet(isPresented: $showChat) { ChatSheet(mesh: mesh) }
        .sheet(isPresented: $showMap) { MapSheet(mesh: mesh) }
        .sheet(isPresented: $showTour, onDismiss: { tourSeen = true }) {
            WalkthroughView { showTour = false }
        }
        .onAppear { if !tourSeen { showTour = true } }
        // Siri "find my buddy" flips this flag; open the map, then reset it.
        .onChange(of: mesh.wantsBuddyMap) { _, want in
            if want {
                showMap = true
                mesh.wantsBuddyMap = false
            }
        }
    }
}

// MARK: - Header

private struct HeaderCard: View {
    let mesh: MeshConnectivityManager

    private var isLive: Bool { mesh.isHosting || mesh.isBrowsing }
    private var statusColor: Color {
        if !mesh.connectedPeers.isEmpty { return .green }
        return isLive ? .yellow : .white.opacity(0.5)
    }
    private var statusText: String {
        if !mesh.connectedPeers.isEmpty { return "Connected \u{00B7} \(mesh.connectedPeers.count) nearby" }
        return isLive ? "Looking for your crew\u{2026}" : "Offline \u{2014} tap Go Live"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(mesh.myName).font(.title.bold()).foregroundStyle(.white)
                    Label(mesh.groupCode.isEmpty ? "open mesh" : mesh.groupCode, systemImage: "person.3.fill")
                        .font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "dot.radiowaves.left.and.right").font(.title).foregroundStyle(.white.opacity(0.9))
            }
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 10, height: 10)
                Text(statusText).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.9))
            }
            Label("Off-grid \u{00B7} no internet or towers", systemImage: "wifi.slash")
                .font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.white.opacity(0.15), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(DistrictTheme.brandGradient, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct GoLiveButton: View {
    let mesh: MeshConnectivityManager
    private var isLive: Bool { mesh.isHosting || mesh.isBrowsing }

    var body: some View {
        Button {
            MeshConnectivityManager.haptic()
            if isLive { mesh.leaveMesh() } else { mesh.startHosting(); mesh.startBrowsing() }
        } label: {
            Label(isLive ? "Leave Mesh" : "Go Live",
                  systemImage: isLive ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
        }
        .buttonStyle(DistrictButtonStyle(
            tint: isLive ? LinearGradient(colors: [.white.opacity(0.12)], startPoint: .top, endPoint: .bottom)
                         : DistrictTheme.brandGradient
        ))
    }
}

// MARK: - Location actions (share live + find a buddy)

private struct GuardianCard: View {
    let mesh: MeshConnectivityManager

    var body: some View {
        HStack(spacing: 12) {
            Button {
                MeshConnectivityManager.haptic()
                mesh.togglePanic()
            } label: {
                tile(mesh.isPanicBroadcasting ? "location.fill.viewfinder" : "location.fill",
                     mesh.isPanicBroadcasting ? "Sharing live" : "Share live location",
                     active: mesh.isPanicBroadcasting)
            }
            .buttonStyle(.plain)

            NavigationLink {
                CompassView(mesh: mesh)
            } label: {
                tile("location.north.line.fill", "Find a buddy", active: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func tile(_ icon: String, _ title: String, active: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title3).foregroundStyle(.white)
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(active ? AnyShapeStyle(DistrictTheme.brandGradient) : AnyShapeStyle(.white.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(active ? 0 : 0.12), lineWidth: 1))
    }
}

// MARK: - Matchmaking entry

private struct MatchmakeCard: View {
    let mesh: MeshConnectivityManager

    var body: some View {
        NavigationLink {
            MatchmakeView(mesh: mesh)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.title3).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(DistrictTheme.accentDeep, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Find players").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(mesh.myLFGActivity != nil ? "Looking for \(mesh.myLFGActivity!) players\u{2026}"
                                                    : "Solo? Match with players nearby")
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - People

private struct PeopleCard: View {
    let mesh: MeshConnectivityManager
    private var isLive: Bool { mesh.isHosting || mesh.isBrowsing }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People nearby").font(.headline).foregroundStyle(.white)
            if mesh.connectedPeers.isEmpty {
                Text(isLive ? "Looking for buddies in \u{201C}\(mesh.groupCode.isEmpty ? "open" : mesh.groupCode)\u{201D}\u{2026} keep phones close."
                            : "Tap Go Live, then buddies on the same group code appear here.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(mesh.connectedPeers, id: \.self) { peer in
                    PersonRow(mesh: mesh, name: peer)
                    if peer != mesh.connectedPeers.last { Divider().overlay(.white.opacity(0.1)) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

private struct PersonRow: View {
    let mesh: MeshConnectivityManager
    let name: String

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: name, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    if mesh.emergencyBuddies.contains(name) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(DistrictTheme.alert).font(.caption2)
                    }
                }
                Label("Connected", systemImage: "checkmark.circle.fill").font(.caption2).foregroundStyle(.green)
            }
            Spacer()
            iconButton("phone.fill") { MeshConnectivityManager.haptic(); mesh.startCall(with: name) }
            iconButton("video.fill") { MeshConnectivityManager.haptic(); mesh.startCall(with: name, video: true) }
        }
        .padding(.vertical, 4)
    }

    private func iconButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.callout).foregroundStyle(DistrictTheme.accent)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(mesh.voice.isInCall)
    }
}

// MARK: - Map preview

private struct MapPreviewCard: View {
    let mesh: MeshConnectivityManager
    @Binding var showMap: Bool

    private var buddies: [BuddyLocation] { Array(mesh.buddyLocations.values) }

    var body: some View {
        Button { showMap = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Live map").font(.headline).foregroundStyle(.white)
                    Spacer()
                    Text(buddies.isEmpty ? "no pings" : "\(buddies.count) pin\(buddies.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.4))
                }
                if buddies.isEmpty {
                    Text("Share your location or turn on Guardian to see pins.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
                } else {
                    Map {
                        ForEach(buddies) { b in
                            Marker(b.name, coordinate: b.coordinate)
                                .tint(mesh.emergencyBuddies.contains(b.name) ? DistrictTheme.alert : DistrictTheme.accent)
                        }
                    }
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .allowsHitTesting(false)
                }
            }
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat card (inline recent + composer)

private struct ChatCard: View {
    let mesh: MeshConnectivityManager
    @Binding var showChat: Bool
    @State private var draft = ""

    private var recent: [MeshMessage] { Array(mesh.receivedMessages.suffix(3)) }
    // Allow sending even with no buddy connected — it queues and delivers later.
    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Chat").font(.headline).foregroundStyle(.white)
                Spacer()
                Button("Open") { showChat = true }
                    .font(.subheadline).foregroundStyle(DistrictTheme.accent)
            }
            if recent.isEmpty {
                Text("Say hi to your crew \u{2014} messages hop across the mesh.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(recent) { m in
                    HStack(alignment: .top, spacing: 6) {
                        Text(m.sender == mesh.myName ? "You" : m.sender)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(m.sender == mesh.myName ? DistrictTheme.accent : .white.opacity(0.8))
                        Text(m.text).font(.caption).foregroundStyle(.white.opacity(0.9))
                        Spacer()
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("", text: $draft, prompt: Text("Message").foregroundColor(.white.opacity(0.4)))
                    .textFieldStyle(.plain).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(.white.opacity(0.1), in: Capsule())
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                        .foregroundStyle(canSend ? DistrictTheme.accent : .white.opacity(0.3))
                }
                .disabled(!canSend)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func send() {
        guard canSend else { return }
        mesh.sendMessage(draft)
        draft = ""
    }
}

// MARK: - Full Chat sheet

private struct ChatSheet: View {
    let mesh: MeshConnectivityManager
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(mesh.receivedMessages) { m in
                                MessageBubble(message: m, mine: m.sender == mesh.myName).id(m.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: mesh.receivedMessages.count) {
                        if let last = mesh.receivedMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                composer
            }
            .districtBackground()
            .navigationTitle("Chat")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("", text: $draft, prompt: Text("Message your crew").foregroundColor(.white.opacity(0.4)))
                .textFieldStyle(.plain).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(.white.opacity(0.1), in: Capsule())
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill").font(.largeTitle)
                    .foregroundStyle(canSend ? DistrictTheme.accent : .white.opacity(0.3))
            }
            .disabled(!canSend)
        }
        .padding(12)
        .background(DistrictTheme.screenGradient)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private func send() {
        guard canSend else { return }
        mesh.sendMessage(draft); draft = ""
    }
}

private struct MessageBubble: View {
    let message: MeshMessage
    let mine: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !mine { InitialsAvatar(name: message.sender, size: 30) }
            if mine { Spacer(minLength: 40) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                if !mine { Text(message.sender).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.6)) }
                Text(message.text).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(mine ? AnyShapeStyle(DistrictTheme.brandGradient) : AnyShapeStyle(Color.white.opacity(0.1)),
                               in: RoundedRectangle(cornerRadius: 18))
                HStack(spacing: 4) {
                    if message.pending {
                        Image(systemName: "clock").font(.caption2).foregroundStyle(.white.opacity(0.4))
                        Text("Queued").font(.caption2).foregroundStyle(.white.opacity(0.4))
                    } else {
                        Text(message.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption2).foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            if !mine { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Full Map sheet

private struct MapSheet: View {
    let mesh: MeshConnectivityManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // BuddyMapView already provides its own NavigationStack, so just overlay
        // a close button rather than nesting another stack.
        BuddyMapView(mesh: mesh)
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, .black.opacity(0.4))
                        .padding(12)
                }
            }
    }
}

// MARK: - Permissions banner & toast

/// Prominent, actionable banner shown when the mesh can't start (usually Local
/// Network permission is off). Renders nothing when there's no problem.
private struct PermissionsBanner: View {
    let mesh: MeshConnectivityManager

    var body: some View {
        if let error = mesh.meshStartError {
            HStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark").font(.title3).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Can't find buddies")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(error)
                        .font(.caption).foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button("Settings") { mesh.openSystemSettings() }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.white, in: Capsule())
                    .foregroundStyle(DistrictTheme.alert)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DistrictTheme.alert.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// Bottom toast for transient confirmations. Renders nothing when `message` is nil.
private struct ToastView: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(.black.opacity(0.82), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.12)))
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(message)
        }
    }
}

// MARK: - Shared

/// Circular avatar with the person's initials, tinted from their name.
struct InitialsAvatar: View {
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
    private var tint: Color {
        let palette: [Color] = [.purple, .blue, .teal, .pink, .orange, .indigo, .mint]
        return palette[abs(name.hashValue) % palette.count]
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: Circle())
    }
}

// MARK: - Settings

private struct SettingsView: View {
    let mesh: MeshConnectivityManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("district.onboarded") private var onboarded = false

    @State private var name = ""
    @State private var group = ""
    @State private var showDiagnostics = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    LabeledContent("Name") {
                        TextField("Your name", text: $name).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Mesh group") {
                        TextField("Group code", text: $group).multilineTextAlignment(.trailing).autocorrectionDisabled()
                    }
                    Button("Save changes") { mesh.configure(name: name, group: group) }
                        .disabled((name.trimmingCharacters(in: .whitespaces).isEmpty || name == mesh.myName) && group == mesh.groupCode)
                }
                Section("Share your mesh") {
                    LabeledContent("Group code", value: mesh.groupCode.isEmpty ? "open mesh" : mesh.groupCode)
                    Text("Everyone who enters this code joins the same private mesh.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    DisclosureGroup("Diagnostics", isExpanded: $showDiagnostics) {
                        if mesh.statusLog.isEmpty {
                            Text("No activity yet.").foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(mesh.statusLog.suffix(20).enumerated()), id: \.offset) { _, line in
                                Text(line).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        mesh.leaveMesh(); onboarded = false; dismiss()
                    } label: {
                        Label("Leave mesh & reset", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .districtBackground()
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { name = mesh.myName; group = mesh.groupCode }
        }
    }
}
