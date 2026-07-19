import Foundation
import Observation
import MultipeerConnectivity
import CoreLocation
import WidgetKit
import os

#if canImport(UIKit)
import UIKit
#endif

// MARK: - UI-facing models

/// A chat message surfaced to the UI (either received from a peer or sent locally).
struct MeshMessage: Identifiable, Hashable {
    let id = UUID()
    let sender: String
    let text: String
    let date: Date
    /// True while queued in the outbox (sent before any buddy was connected).
    var pending: Bool = false
}

/// The latest known location for a buddy, keyed by their display name.
struct BuddyLocation: Identifiable {
    var id: String { name }
    let name: String
    let coordinate: CLLocationCoordinate2D
    let date: Date
}

/// A nearby solo player looking to team up for an activity (matchmaking).
struct LFGPlayer: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let activity: String
    let date: Date
}

// MARK: - Mesh manager

/// Drives peer discovery, connection, and multi-hop packet relay over
/// `MultipeerConnectivity` (which runs on Wi-Fi + Bluetooth with no internet).
///
/// Every device both advertises (hosts) and browses. To avoid two devices
/// inviting each other at the same instant, invitations are broken with a
/// per-launch token: only the peer with the smaller token initiates.
///
/// Data moves as `MeshRelayPacket`s. On receipt a packet is de-duplicated,
/// delivered locally, then (if it still has TTL) re-broadcast to every other
/// connected peer — giving range beyond a single direct hop.
@MainActor
@Observable
final class MeshConnectivityManager: NSObject {

    // MARK: Observable state (drives the SwiftUI views)

    /// Display names of currently connected peers.
    private(set) var connectedPeers: [String] = []

    /// Messages shown in the test screen, oldest first.
    private(set) var receivedMessages: [MeshMessage] = []

    /// Latest location per buddy (including ourselves once we share).
    private(set) var buddyLocations: [String: BuddyLocation] = [:] {
        didSet { persistBuddiesForWidget() }
    }

    private(set) var isHosting = false
    private(set) var isBrowsing = false

    /// Names of buddies flagged urgent (reserved; currently unused).
    private(set) var emergencyBuddies: Set<String> = []

    /// Whether we're continuously sharing our live location with the crew.
    private(set) var isPanicBroadcasting = false

    /// Solo players nearby looking to team up (matchmaking), keyed by name.
    private(set) var lfgPlayers: [String: LFGPlayer] = [:]

    /// The activity we're currently looking to play, or nil if not searching.
    private(set) var myLFGActivity: String?

    /// Device compass heading in degrees (0 = north), for the buddy compass.
    private(set) var deviceHeading: Double = 0

    /// True once real heading updates are arriving (compass calibrated).
    private(set) var headingActive = false

    /// Our own last-known coordinate (nil until we get a fix), for the compass.
    var myCoordinate: CLLocationCoordinate2D? { lastKnownCoordinate }

    /// Handles offline voice calls that ride over the same mesh session.
    let voice = MeshVoiceCallManager()

    /// Drives the Dynamic Island / lock-screen Live Activity while connected.
    @ObservationIgnored private let liveActivity = LiveActivityController()

    /// Rolling on-screen diagnostic log (newest last) so connection issues are
    /// visible on-device without needing the Xcode console.
    private(set) var statusLog: [String] = []

    /// Transient confirmation message shown briefly to the user (toast).
    private(set) var toast: String?

    /// Set when the mesh can't start (e.g. Local Network permission denied), so
    /// the UI can guide the user to fix it. Cleared once we connect.
    private(set) var meshStartError: String?

    /// This device's display name (what buddies see). User-editable so two
    /// phones (both reported as "iPhone" by iOS) can be told apart.
    private(set) var myName: String

    /// The mesh group ("room") code. Only phones sharing the same code connect,
    /// so your crew forms a private mesh in a crowd of strangers.
    private(set) var groupCode: String

    // MARK: MultipeerConnectivity plumbing

    /// Bonjour service type. Must match the `_district-mesh._tcp` entry in
    /// `NSBonjourServices` in Info.plist. Max 15 chars, lowercase + hyphens.
    static let serviceType = "district-mesh"

    /// UserDefaults key for the persisted display name.
    static let nameKey = "district.displayName"

    /// UserDefaults key for the persisted mesh group code.
    static let groupKey = "district.groupCode"

    private var myPeerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser

    /// Random per-launch token used to deterministically decide which side of a
    /// pair sends the connection invitation (prevents duplicate/colliding invites).
    private let myToken: String

    // MARK: Internals (not observed by the UI)

    @ObservationIgnored private var seen = SeenPacketCache()
    @ObservationIgnored private let log = Logger(subsystem: "com.swastik.districtmesh", category: "mesh")
    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private var pendingLocationSend = false
    @ObservationIgnored private var lastKnownCoordinate: CLLocationCoordinate2D?
    @ObservationIgnored private var panicTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var lfgTask: Task<Void, Never>?

    /// Messages typed before a buddy was connected — delivered on connect.
    @ObservationIgnored private var outbox: [(packet: MeshRelayPacket, messageID: UUID)] = []

    /// Maps peer display names back to their `MCPeerID` so we can target a
    /// specific peer for a voice call.
    @ObservationIgnored private var peerIDsByName: [String: MCPeerID] = [:]

    // MARK: Init

    override init() {
        let saved = UserDefaults.standard.string(forKey: Self.nameKey)
        let name = (saved?.isEmpty == false) ? saved! : Self.defaultDeviceName()
        let group = UserDefaults.standard.string(forKey: Self.groupKey) ?? ""
        let peerID = MCPeerID(displayName: name)
        let token = UUID().uuidString
        self.myName = name
        self.groupCode = group
        self.myPeerID = peerID
        self.myToken = token
        self.session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        self.advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["token": token, "group": group],
            serviceType: Self.serviceType
        )
        self.browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: Self.serviceType
        )
        super.init()

        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // metres — avoids a flood of tiny updates
        voice.attach(session: session)
    }

    /// Records a diagnostic line to both os_log and the on-screen status log.
    private func note(_ message: String) {
        log.info("\(message, privacy: .public)")
        statusLog.append(message)
        if statusLog.count > 40 { statusLog.removeFirst(statusLog.count - 40) }
    }

    // MARK: Feedback & permissions

    /// Whether location permission has been explicitly denied/restricted.
    var isLocationDenied: Bool {
        switch locationManager.authorizationStatus {
        case .denied, .restricted: return true
        default: return false
        }
    }

    /// Shows a brief confirmation toast that auto-dismisses.
    func flashToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.toast = nil
        }
    }

    /// Light haptic feedback for a tap action.
    static func haptic(_ style: HapticStyle = .medium) {
        #if canImport(UIKit)
        let mapped: UIImpactFeedbackGenerator.FeedbackStyle = style == .light ? .light : (style == .heavy ? .heavy : .medium)
        UIImpactFeedbackGenerator(style: mapped).impactOccurred()
        #endif
    }

    enum HapticStyle { case light, medium, heavy }

    /// Mirrors buddy locations to the App Group so the home-screen widget can
    /// show them, and asks the widget to refresh.
    private func persistBuddiesForWidget() {
        let snapshots = buddyLocations.values.map {
            SharedStore.BuddySnapshot(name: $0.name, lat: $0.coordinate.latitude,
                                      lon: $0.coordinate.longitude, date: $0.date)
        }
        SharedStore.saveBuddies(snapshots)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Opens the app's Settings page so the user can grant a denied permission.
    func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private static func defaultDeviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "Device"
        #endif
    }

    // MARK: Identity & group

    /// Sets the display name and/or group code, persists them, and rebuilds the
    /// MultipeerConnectivity stack so buddies see the change. Reconnects if live.
    func configure(name: String? = nil, group: String? = nil) {
        let newName = (name ?? myName).trimmingCharacters(in: .whitespacesAndNewlines)
        let newGroup = (group ?? groupCode).trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = !newName.isEmpty && newName != myName
        let groupChanged = newGroup != groupCode
        guard nameChanged || groupChanged else { return }

        if nameChanged {
            myName = newName
            UserDefaults.standard.set(newName, forKey: Self.nameKey)
        }
        if groupChanged {
            groupCode = newGroup
            UserDefaults.standard.set(newGroup, forKey: Self.groupKey)
        }
        rebuildNetworking()
        note("Identity: \(myName) \u{00B7} group \u{201C}\(groupCode)\u{201D}")
    }

    func setDisplayName(_ newName: String) { configure(name: newName) }
    func setGroup(_ newGroup: String) { configure(group: newGroup) }

    /// Convenience for onboarding: set identity and immediately join the mesh.
    func joinMesh(name: String, group: String) {
        configure(name: name, group: group)
        startHosting()
        startBrowsing()
    }

    func leaveMesh() {
        stopHosting()
        stopBrowsing()
        session.disconnect()
        connectedPeers.removeAll()
        peerIDsByName.removeAll()
        liveActivity.end()
    }

    private func discoveryInfo() -> [String: String] {
        ["token": myToken, "group": groupCode]
    }

    /// Tears down and recreates the peer id / session / advertiser / browser
    /// (needed because MCPeerID and the advertiser's discovery info are immutable).
    private func rebuildNetworking() {
        let wasHosting = isHosting
        let wasBrowsing = isBrowsing
        stopHosting()
        stopBrowsing()
        session.disconnect()

        myPeerID = MCPeerID(displayName: myName)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: discoveryInfo(), serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        voice.attach(session: session)

        connectedPeers.removeAll()
        peerIDsByName.removeAll()
        buddyLocations.removeValue(forKey: myName)

        if wasHosting { startHosting() }
        if wasBrowsing { startBrowsing() }
    }

    // MARK: Start / stop

    func startHosting() {
        guard !isHosting else { return }
        meshStartError = nil // optimistic; the didNotStart delegate sets it on failure
        advertiser.startAdvertisingPeer()
        isHosting = true
        note("Hosting started as \(myName)")
    }

    func stopHosting() {
        guard isHosting else { return }
        advertiser.stopAdvertisingPeer()
        isHosting = false
    }

    func startBrowsing() {
        guard !isBrowsing else { return }
        browser.startBrowsingForPeers()
        isBrowsing = true
        note("Browsing for buddies\u{2026}")
    }

    func stopBrowsing() {
        guard isBrowsing else { return }
        browser.stopBrowsingForPeers()
        isBrowsing = false
    }

    // MARK: Sending

    /// Creates a message packet, shows it locally, and broadcasts it. If no buddy
    /// is connected yet, it's queued and auto-delivered once one connects.
    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let packet = MeshRelayPacket(kind: .message, senderName: myName, text: trimmed)
        _ = seen.insertIfNew(packet.id) // don't re-handle if it echoes back to us

        let queued = connectedPeers.isEmpty
        var message = MeshMessage(sender: myName, text: trimmed, date: packet.timestamp)
        message.pending = queued
        receivedMessages.append(message)

        if queued {
            outbox.append((packet, message.id))
            flashToast("Queued \u{2014} sends when a buddy connects")
        } else {
            broadcast(packet, excluding: nil)
        }
    }

    /// Delivers any queued messages once a buddy connects.
    private func flushOutbox() {
        guard !outbox.isEmpty else { return }
        for item in outbox {
            broadcast(item.packet, excluding: nil)
            if let i = receivedMessages.firstIndex(where: { $0.id == item.messageID }) {
                receivedMessages[i].pending = false
            }
        }
        note("Delivered \(outbox.count) queued message(s)")
        outbox.removeAll()
    }

    /// Requests a one-shot location fix and broadcasts it once available.
    func sendMyLocation() {
        if isLocationDenied {
            flashToast("Turn on Location in Settings to share")
            return
        }
        pendingLocationSend = true
        if isLocationAuthorized {
            locationManager.requestLocation()
            flashToast(connectedPeers.isEmpty ? "Location saved \u{2014} go live to share" : "Sharing your location\u{2026}")
        } else {
            requestLocationAuthorization()
        }
    }

    /// Whether we currently hold a usable "in use" authorization.
    /// The available enum cases differ between iOS and macOS.
    private var isLocationAuthorized: Bool {
        switch locationManager.authorizationStatus {
        #if os(macOS)
        case .authorized, .authorizedAlways: return true
        #else
        case .authorizedWhenInUse, .authorizedAlways: return true
        #endif
        default: return false
        }
    }

    private func requestLocationAuthorization() {
        #if os(macOS)
        locationManager.requestAlwaysAuthorization()
        #else
        locationManager.requestWhenInUseAuthorization()
        #endif
    }

    /// Enables background location so Guardian/SOS keeps broadcasting when the
    /// screen is locked. Requests "Always" so it survives backgrounding.
    private func enableBackgroundLocation() {
        #if os(iOS)
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        #endif
    }

    private func broadcastMyLocation(_ coordinate: CLLocationCoordinate2D, emergency: Bool = false) {
        lastKnownCoordinate = coordinate
        let packet = MeshRelayPacket(
            kind: .location,
            senderName: myName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            isEmergency: emergency
        )
        _ = seen.insertIfNew(packet.id)
        buddyLocations[myName] = BuddyLocation(
            name: myName, coordinate: coordinate, date: packet.timestamp
        )
        broadcast(packet, excluding: nil)
    }

    // MARK: Live location sharing

    /// Toggles continuous live-location sharing so the crew can follow you on the
    /// map and compass, even as you move around the venue.
    func togglePanic() {
        isPanicBroadcasting ? stopPanicMode() : startPanicMode()
    }

    func startPanicMode() {
        guard !isPanicBroadcasting else { return }
        if isLocationDenied {
            flashToast("Turn on Location in Settings to share")
            return
        }
        isPanicBroadcasting = true
        flashToast("Sharing your live location")
        enableBackgroundLocation() // keep sharing when the screen is locked

        if isLocationAuthorized {
            locationManager.startUpdatingLocation()
            if let coord = lastKnownCoordinate { broadcastMyLocation(coord) }
        } else if locationManager.authorizationStatus == .notDetermined {
            requestLocationAuthorization()
        }

        // Heartbeat: re-broadcast our last-known location every few seconds so
        // buddies keep getting pings even when we're standing still.
        panicTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, self.isPanicBroadcasting else { return }
                if let coord = self.lastKnownCoordinate {
                    self.broadcastMyLocation(coord)
                }
            }
        }
    }

    func stopPanicMode() {
        guard isPanicBroadcasting else { return }
        isPanicBroadcasting = false
        flashToast("Stopped sharing location")
        panicTask?.cancel()
        panicTask = nil
        locationManager.stopUpdatingLocation()
        #if os(iOS)
        locationManager.allowsBackgroundLocationUpdates = false
        #endif
    }

    // MARK: Compass (find a buddy)

    /// Starts location + heading updates so the compass can point to a buddy.
    func startCompass() {
        #if os(iOS)
        if isLocationAuthorized { locationManager.startUpdatingLocation() }
        else if locationManager.authorizationStatus == .notDetermined { requestLocationAuthorization() }
        if CLLocationManager.headingAvailable() { locationManager.startUpdatingHeading() }
        #endif
    }

    func stopCompass() {
        #if os(iOS)
        locationManager.stopUpdatingHeading()
        headingActive = false
        if !isPanicBroadcasting { locationManager.stopUpdatingLocation() }
        #endif
    }

    /// Great-circle bearing (degrees from north) from `from` to `to`.
    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180, lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: Matchmaking (solo → find solo players)

    /// Solo players (other than us) still actively looking, freshest first.
    var activeLFGPlayers: [LFGPlayer] {
        let cutoff = Date().addingTimeInterval(-30)
        return lfgPlayers.values
            .filter { $0.name != myName && $0.date > cutoff }
            .sorted { $0.name < $1.name }
    }

    /// Announces that we're a solo player looking to team up for `activity`,
    /// and re-announces periodically so people who arrive later still see us.
    func startLookingForGame(_ activity: String) {
        myLFGActivity = activity
        broadcastLFG()
        flashToast("Looking for \(activity) players")
        lfgTask?.cancel()
        lfgTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                guard let self, self.myLFGActivity != nil else { return }
                self.broadcastLFG()
            }
        }
    }

    func stopLookingForGame() {
        guard myLFGActivity != nil else { return }
        myLFGActivity = nil
        lfgTask?.cancel()
        lfgTask = nil
        let packet = MeshRelayPacket(kind: .lfg, senderName: myName, text: "")
        _ = seen.insertIfNew(packet.id)
        broadcast(packet, excluding: nil)
        flashToast("Stopped looking")
    }

    private func broadcastLFG() {
        guard let activity = myLFGActivity else { return }
        let packet = MeshRelayPacket(kind: .lfg, senderName: myName, text: activity)
        _ = seen.insertIfNew(packet.id)
        broadcast(packet, excluding: nil)
    }

    // MARK: Voice calls

    /// Starts a call with a connected buddy by display name, optionally with video.
    func startCall(with peerName: String, video: Bool = false) {
        guard let peerID = peerIDsByName[peerName] else { return }
        voice.startCall(to: peerID, session: session)
        if video { voice.enableVideo() }
    }

    func endCall() {
        voice.endCall()
    }

    // MARK: Relay core

    /// Sends `packet` to every connected peer except `excluding` (the peer we
    /// received it from, so we never bounce it straight back).
    private func broadcast(_ packet: MeshRelayPacket, excluding: MCPeerID?) {
        guard let data = packet.encoded() else { return }

        let targets: [MCPeerID]
        if let excluding {
            targets = session.connectedPeers.filter { $0 != excluding }
        } else {
            targets = session.connectedPeers
        }
        guard !targets.isEmpty else { return }

        try? session.send(data, toPeers: targets, with: .reliable)
    }

    /// Handles a freshly decoded packet: de-dupes, delivers to the UI, then
    /// relays onward with a decremented TTL.
    private func handleIncoming(_ packet: MeshRelayPacket, from peerID: MCPeerID) {
        // De-duplicate: process each packet id exactly once.
        guard seen.insertIfNew(packet.id) else { return }

        switch packet.kind {
        case .message:
            if let text = packet.text {
                receivedMessages.append(
                    MeshMessage(sender: packet.senderName, text: text, date: packet.timestamp)
                )
            }
        case .location:
            if let lat = packet.latitude, let lng = packet.longitude {
                buddyLocations[packet.senderName] = BuddyLocation(
                    name: packet.senderName,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    date: packet.timestamp
                )
                if packet.isEmergency == true {
                    emergencyBuddies.insert(packet.senderName)
                } else {
                    emergencyBuddies.remove(packet.senderName)
                }
            }
        case .lfg:
            if let activity = packet.text, !activity.isEmpty {
                lfgPlayers[packet.senderName] = LFGPlayer(name: packet.senderName, activity: activity, date: packet.timestamp)
            } else {
                lfgPlayers.removeValue(forKey: packet.senderName)
            }
        }

        // Multi-hop relay: forward to our other neighbours until TTL runs out.
        var forwarded = packet
        forwarded.ttl -= 1
        if forwarded.ttl > 0 {
            broadcast(forwarded, excluding: peerID)
        }
    }
}

// MARK: - MCSessionDelegate

extension MeshConnectivityManager: MCSessionDelegate {

    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.meshStartError = nil
                let isNew = !self.connectedPeers.contains(peerID.displayName)
                self.peerIDsByName[peerID.displayName] = peerID
                if isNew {
                    self.connectedPeers.append(peerID.displayName)
                    self.flashToast("\(peerID.displayName) joined the mesh")
                    Self.haptic(.light)
                }
                self.flushOutbox()
                self.liveActivity.sync(connectedPeers: self.connectedPeers, group: self.groupCode)
                self.note("Connected: \(peerID.displayName)")
            case .notConnected:
                self.peerIDsByName.removeValue(forKey: peerID.displayName)
                self.connectedPeers.removeAll { $0 == peerID.displayName }
                self.emergencyBuddies.remove(peerID.displayName)
                self.liveActivity.sync(connectedPeers: self.connectedPeers, group: self.groupCode)
                self.note("Disconnected: \(peerID.displayName)")
                // If we were on a call with this peer, tear it down.
                if self.voice.activePeer == peerID.displayName {
                    self.voice.endCall()
                }
            case .connecting:
                self.note("Connecting to \(peerID.displayName)\u{2026}")
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let packet = MeshRelayPacket.decode(from: data) else { return }
        Task { @MainActor in
            self.handleIncoming(packet, from: peerID)
        }
    }

    // Voice-call audio arrives as a named stream — hand it to the call manager.
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.voice.handleIncomingStream(stream, name: streamName, from: peerID, session: session)
        }
    }

    // Unused transport channels — required by the protocol.
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MeshConnectivityManager: MCNearbyServiceAdvertiserDelegate {

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept every invitation onto our shared session.
        Task { @MainActor in
            self.note("Invitation from \(peerID.displayName) \u{2192} accepting")
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.note("Advertise failed: \(message)")
            self.meshStartError = "Local Network access is off. Enable it in Settings so nearby phones can find you."
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MeshConnectivityManager: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let theirToken = info?["token"]
        let theirGroup = info?["group"] ?? ""
        Task { @MainActor in
            // Only connect to phones in the same mesh group.
            guard theirGroup == self.groupCode else {
                self.note("Skipped \(peerID.displayName) (other group)")
                return
            }
            self.note("Found \(peerID.displayName)")
            // Tie-break: only the smaller token initiates, so two devices that
            // discover each other simultaneously don't send colliding invites.
            if let theirToken, self.myToken >= theirToken {
                self.note("Waiting for \(peerID.displayName) to invite (tie-break)")
                return
            }
            self.note("Inviting \(peerID.displayName)\u{2026}")
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 30)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in self.note("Lost \(peerID.displayName)") }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.note("Browse failed: \(message)")
            self.meshStartError = "Local Network access is off. Enable it in Settings so nearby phones can find you."
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension MeshConnectivityManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.isLocationAuthorized else { return }
            if self.isPanicBroadcasting {
                self.locationManager.startUpdatingLocation()
            }
            if self.pendingLocationSend {
                self.locationManager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.lastKnownCoordinate = location.coordinate
            if self.isPanicBroadcasting {
                self.broadcastMyLocation(location.coordinate)
            }
            if self.pendingLocationSend {
                self.pendingLocationSend = false
                self.broadcastMyLocation(location.coordinate)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.pendingLocationSend = false
        }
    }

    #if os(iOS)
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Ignore low-accuracy readings (negative accuracy = invalid/uncalibrated).
        guard newHeading.headingAccuracy >= 0 else { return }
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            self.deviceHeading = value
            self.headingActive = true
        }
    }
    #endif
}
