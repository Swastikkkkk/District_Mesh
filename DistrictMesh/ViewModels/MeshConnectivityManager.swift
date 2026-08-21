import Foundation
import Observation
import MultipeerConnectivity
import CoreLocation
import UIKit
import ActivityKit
import os

@MainActor
@Observable
final class MeshConnectivityManager: NSObject {

    // MARK: State

    private(set) var connectedPeers: [String] = []
    private(set) var receivedMessages: [MeshMessage] = []
    private(set) var buddyLocations: [String: BuddyLocation] = [:]
    private(set) var isHosting = false
    private(set) var isBrowsing = false
    var isLive: Bool { isHosting || isBrowsing }
    private(set) var emergencyBuddies: Set<String> = []
    private(set) var isPanicBroadcasting = false
    private(set) var deviceHeading: Double = 0
    private(set) var headingActive = false
    var myCoordinate: CLLocationCoordinate2D? { lastKnownCoordinate }

    let voice = MeshVoiceCallManager()
    @ObservationIgnored private let liveActivity = LiveActivityController()

    private(set) var statusLog: [String] = []
    private(set) var toast: String?
    private(set) var meshStartError: String?
    private(set) var myName: String
    private(set) var groupCode: String

    // MARK: MPC internals

    private static let serviceType = "district-mesh"
    static let nameKey = "district.displayName"
    static let groupKey = "district.groupCode"

    private var myPeerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    private let myToken: String

    @ObservationIgnored private var seen = SeenPacketCache()
    @ObservationIgnored private let log = Logger(subsystem: "com.swastik.districtmesh", category: "mesh")
    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private var lastKnownCoordinate: CLLocationCoordinate2D?
    @ObservationIgnored private var panicTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var outbox: [(packet: MeshRelayPacket, messageID: UUID)] = []
    @ObservationIgnored private var peerIDsByName: [String: MCPeerID] = [:]
    @ObservationIgnored private var compassActive = false
    @ObservationIgnored private var compassBroadcastTask: Task<Void, Never>?

    // MARK: Init

    override init() {
        let token = UUID().uuidString
        let name = UserDefaults.standard.string(forKey: Self.nameKey).flatMap { $0.isEmpty ? nil : $0 } ?? UIDevice.current.name
        let group = UserDefaults.standard.string(forKey: Self.groupKey) ?? ""
        let peerID = MCPeerID(displayName: name)
        self.myName = name
        self.groupCode = group
        self.myToken = token
        self.myPeerID = peerID
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        self.advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["token": token, "group": group],
            serviceType: Self.serviceType
        )
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        voice.attach(session: session)
    }

    private func note(_ message: String) {
        log.info("\(message, privacy: .public)")
        statusLog.append(message)
        if statusLog.count > 40 { statusLog.removeFirst(statusLog.count - 40) }
    }

    // MARK: Utilities

    static func haptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func flashToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.toast = nil
        }
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    var isLocationDenied: Bool {
        locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted
    }

    private var isLocationAuthorized: Bool {
        let s = locationManager.authorizationStatus
        return s == .authorizedWhenInUse || s == .authorizedAlways
    }

    private func syncLiveActivity() {
        let nearest = nearestBuddyWithDistance()
        liveActivity.update(
            connectedPeers: connectedPeers,
            group: groupCode,
            sharingLocation: isPanicBroadcasting,
            nearestPeer: nearest
        )
    }

    private func nearestBuddyWithDistance() -> (name: String, distance: Double)? {
        guard let myLoc = lastKnownCoordinate else { return nil }
        let myLocation = CLLocation(latitude: myLoc.latitude, longitude: myLoc.longitude)
        return buddyLocations
            .compactMap { name, buddy -> (String, Double)? in
                guard name != myName else { return nil }
                let buddyLoc = CLLocation(latitude: buddy.coordinate.latitude, longitude: buddy.coordinate.longitude)
                return (name, myLocation.distance(from: buddyLoc))
            }
            .min(by: { $0.1 < $1.1 })
    }

    func testLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            flashToast("Live Activities disabled — go to Settings \u{2192} DistrictMesh \u{2192} Live Activities")
            return
        }
        syncLiveActivity()
        flashToast("Lock your phone — banner appears at the bottom of the lock screen")
    }

    // MARK: Identity

    func configure(name: String? = nil, group: String? = nil) {
        let newName = (name ?? myName).trimmingCharacters(in: .whitespacesAndNewlines)
        let newGroup = (group ?? groupCode).trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = !newName.isEmpty && newName != myName
        let groupChanged = newGroup != groupCode
        guard nameChanged || groupChanged else { return }
        if nameChanged { myName = newName; UserDefaults.standard.set(newName, forKey: Self.nameKey) }
        if groupChanged { groupCode = newGroup; UserDefaults.standard.set(newGroup, forKey: Self.groupKey) }
        rebuildNetworking()
        note("Identity: \(myName) \u{00B7} group \u{201C}\(groupCode)\u{201D}")
    }

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

    private func rebuildNetworking() {
        let wasHosting = isHosting; let wasBrowsing = isBrowsing
        stopHosting(); stopBrowsing(); session.disconnect()
        myPeerID = MCPeerID(displayName: myName)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["token": myToken, "group": groupCode], serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        session.delegate = self; advertiser.delegate = self; browser.delegate = self
        voice.attach(session: session)
        connectedPeers.removeAll(); peerIDsByName.removeAll()
        buddyLocations.removeValue(forKey: myName)
        if wasHosting { startHosting() }
        if wasBrowsing { startBrowsing() }
    }

    // MARK: Start / stop

    func startHosting() {
        guard !isHosting else { return }
        meshStartError = nil
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
        note("Browsing for buddies…")
    }

    func stopBrowsing() {
        guard isBrowsing else { return }
        browser.stopBrowsingForPeers()
        isBrowsing = false
    }

    // MARK: Messaging

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let packet = MeshRelayPacket(kind: .message, senderName: myName, text: trimmed)
        _ = seen.insertIfNew(packet.id)
        let queued = connectedPeers.isEmpty
        var message = MeshMessage(sender: myName, text: trimmed, date: packet.timestamp)
        message.pending = queued
        receivedMessages.append(message)
        if queued {
            outbox.append((packet, message.id))
            flashToast("Queued — sends when a buddy connects")
        } else {
            broadcast(packet, excluding: nil)
        }
    }

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

    // MARK: Location & panic

    private func broadcastMyLocation(_ coordinate: CLLocationCoordinate2D, emergency: Bool = false) {
        lastKnownCoordinate = coordinate
        let packet = MeshRelayPacket(kind: .location, senderName: myName,
                                     latitude: coordinate.latitude, longitude: coordinate.longitude,
                                     isEmergency: emergency)
        _ = seen.insertIfNew(packet.id)
        buddyLocations[myName] = BuddyLocation(name: myName, coordinate: coordinate, date: packet.timestamp)
        broadcast(packet, excluding: nil)
    }

    func togglePanic() { isPanicBroadcasting ? stopPanicMode() : startPanicMode() }

    func startPanicMode() {
        guard !isPanicBroadcasting else { return }
        if isLocationDenied { flashToast("Turn on Location in Settings to share"); return }
        isPanicBroadcasting = true
        flashToast("Sharing your live location")
        syncLiveActivity()
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        if isLocationAuthorized {
            locationManager.startUpdatingLocation()
            if let coord = lastKnownCoordinate { broadcastMyLocation(coord) }
        } else if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        panicTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, self.isPanicBroadcasting else { return }
                if let coord = self.lastKnownCoordinate { self.broadcastMyLocation(coord) }
            }
        }
    }

    func stopPanicMode() {
        guard isPanicBroadcasting else { return }
        isPanicBroadcasting = false
        flashToast("Stopped sharing location")
        syncLiveActivity()
        panicTask?.cancel(); panicTask = nil
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
    }

    // MARK: Compass

    func startCompass() {
        compassActive = true
        if isLocationAuthorized {
            locationManager.startUpdatingLocation()
            if let coord = lastKnownCoordinate { broadcastMyLocation(coord) }
        } else if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        if CLLocationManager.headingAvailable() { locationManager.startUpdatingHeading() }
        compassBroadcastTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard let self, self.compassActive else { return }
                if let coord = self.lastKnownCoordinate { self.broadcastMyLocation(coord) }
            }
        }
    }

    func stopCompass() {
        compassActive = false
        compassBroadcastTask?.cancel()
        compassBroadcastTask = nil
        locationManager.stopUpdatingHeading()
        headingActive = false
        if !isPanicBroadcasting { locationManager.stopUpdatingLocation() }
    }

    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180, lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: Calls

    func startCall(with peerName: String, video: Bool = false) {
        guard let peerID = peerIDsByName[peerName] else { return }
        voice.startCall(to: peerID, session: session)
        if video { voice.enableVideo() }
    }

    func endCall() { voice.endCall() }

    // MARK: Relay

    private func broadcast(_ packet: MeshRelayPacket, excluding: MCPeerID?) {
        guard let data = packet.encoded() else { return }
        let targets = excluding.map { ex in session.connectedPeers.filter { $0 != ex } } ?? session.connectedPeers
        guard !targets.isEmpty else { return }
        try? session.send(data, toPeers: targets, with: .reliable)
    }

    private func handleIncoming(_ packet: MeshRelayPacket, from peerID: MCPeerID) {
        guard seen.insertIfNew(packet.id) else { return }
        switch packet.kind {
        case .message:
            if let text = packet.text {
                receivedMessages.append(MeshMessage(sender: packet.senderName, text: text, date: packet.timestamp))
            }
        case .location:
            if let lat = packet.latitude, let lng = packet.longitude {
                buddyLocations[packet.senderName] = BuddyLocation(
                    name: packet.senderName,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    date: packet.timestamp
                )
                if packet.isEmergency == true { emergencyBuddies.insert(packet.senderName) }
                else { emergencyBuddies.remove(packet.senderName) }
                SharedStore.saveBuddies(buddyLocations.values.map {
                    SharedStore.BuddySnapshot(name: $0.name, lat: $0.coordinate.latitude, lon: $0.coordinate.longitude, date: $0.date)
                })
            }
        }
        var forwarded = packet; forwarded.ttl -= 1
        if forwarded.ttl > 0 { broadcast(forwarded, excluding: peerID) }
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
                    self.receivedMessages.append(MeshMessage(sender: "", text: "\(peerID.displayName) joined the mesh", date: Date(), isSystem: true))
                    self.flashToast("\(peerID.displayName) joined the mesh")
                    Self.haptic()
                    SharedStore.saveConnectedPeers(self.connectedPeers)
                }
                self.flushOutbox()
                self.note("Connected: \(peerID.displayName)")
                self.syncLiveActivity()
            case .notConnected:
                self.peerIDsByName.removeValue(forKey: peerID.displayName)
                self.connectedPeers.removeAll { $0 == peerID.displayName }
                self.emergencyBuddies.remove(peerID.displayName)
                self.receivedMessages.append(MeshMessage(sender: "", text: "\(peerID.displayName) left the mesh", date: Date(), isSystem: true))
                self.note("Disconnected: \(peerID.displayName)")
                if self.voice.activePeer == peerID.displayName { self.voice.endCall() }
                SharedStore.saveConnectedPeers(self.connectedPeers)
                self.syncLiveActivity()
            case .connecting:
                self.note("Connecting to \(peerID.displayName)…")
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let packet = MeshRelayPacket.decode(from: data) else { return }
        Task { @MainActor in self.handleIncoming(packet, from: peerID) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        Task { @MainActor in self.voice.handleIncomingStream(stream, name: streamName, from: peerID, session: session) }
    }

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MeshConnectivityManager: MCNearbyServiceAdvertiserDelegate {

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            self.note("Invitation from \(peerID.displayName) → accepting")
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        let msg = error.localizedDescription
        Task { @MainActor in
            self.note("Advertise failed: \(msg)")
            self.meshStartError = "Local Network access is off. Enable it in Settings so nearby phones can find you."
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MeshConnectivityManager: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let theirToken = info?["token"]; let theirGroup = info?["group"] ?? ""
        Task { @MainActor in
            guard theirGroup == self.groupCode else { return }
            self.note("Found \(peerID.displayName)")
            if let theirToken, self.myToken >= theirToken {
                self.note("Waiting for \(peerID.displayName) to invite (tie-break)")
                return
            }
            self.note("Inviting \(peerID.displayName)…")
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 30)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in self.note("Lost \(peerID.displayName)") }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        let msg = error.localizedDescription
        Task { @MainActor in
            self.note("Browse failed: \(msg)")
            self.meshStartError = "Local Network access is off. Enable it in Settings so nearby phones can find you."
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension MeshConnectivityManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.isLocationAuthorized else { return }
            if self.isPanicBroadcasting || self.compassActive {
                self.locationManager.startUpdatingLocation()
            }
            if self.compassActive && CLLocationManager.headingAvailable() {
                self.locationManager.startUpdatingHeading()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.lastKnownCoordinate = location.coordinate
            if self.isPanicBroadcasting {
                self.broadcastMyLocation(location.coordinate, emergency: true)
            } else if self.compassActive {
                self.broadcastMyLocation(location.coordinate, emergency: false)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            self.deviceHeading = value
            self.headingActive = true
        }
    }
}
