import Foundation

/// A single unit of data that travels across the mesh.
///
/// Packets are relayed peer-to-peer: each device that receives a packet
/// re-broadcasts it to its own neighbours (minus the one it came from) after
/// decrementing `ttl`. This is what lets a message reach a device that is *not*
/// directly connected to the original sender (multi-hop). `id` stays constant
/// across every hop and is used for de-duplication so a packet looping around
/// the mesh is only processed once.
struct MeshRelayPacket: Codable, Identifiable, Sendable {

    /// The kind of payload this packet carries.
    enum Kind: String, Codable, Sendable {
        case message
        case location
        case lfg // "looking for game" matchmaking presence; `text` = activity ("" = stopped)
        case gameInvite // directed team-up invite; `recipient` = target, `text` = activity
        case gameAccept // directed acceptance of an invite; `recipient` = original inviter, `text` = activity
    }

    /// Stable identifier for the packet, assigned by the original sender.
    /// Used as the de-duplication key across all hops.
    let id: UUID

    /// Remaining hops before the packet is dropped. Starts at `defaultTTL`
    /// and is decremented on every relay.
    var ttl: Int

    /// What sort of payload this packet holds.
    let kind: Kind

    /// Display name of the *original* sender (not the last relay).
    let senderName: String

    /// When the original sender created the packet.
    let timestamp: Date

    // MARK: Payloads (only the fields relevant to `kind` are populated)

    /// Text body, present when `kind == .message`.
    var text: String?

    /// Latitude, present when `kind == .location`.
    var latitude: Double?

    /// Longitude, present when `kind == .location`.
    var longitude: Double?

    /// `true` when this location ping is an emergency (panic mode) broadcast.
    /// Optional so packets from older senders decode as non-emergency.
    var isEmergency: Bool?

    /// Display name of the intended recipient for directed packets
    /// (`gameInvite` / `gameAccept`). `nil` for broadcast packets. Directed
    /// packets are still relayed across the mesh so they reach a recipient that
    /// isn't a direct neighbour; only the matching recipient acts on them.
    var recipient: String?

    /// The starting time-to-live (max hop count) for freshly created packets.
    static let defaultTTL = 10

    init(
        kind: Kind,
        senderName: String,
        ttl: Int = MeshRelayPacket.defaultTTL,
        text: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isEmergency: Bool? = nil,
        recipient: String? = nil,
        id: UUID = UUID(),
        timestamp: Date = Date()
    ) {
        self.id = id
        self.ttl = ttl
        self.kind = kind
        self.senderName = senderName
        self.timestamp = timestamp
        self.text = text
        self.latitude = latitude
        self.longitude = longitude
        self.isEmergency = isEmergency
        self.recipient = recipient
    }

    /// Encodes the packet for transmission over an `MCSession`.
    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Decodes a packet received from a peer. Returns `nil` on malformed data.
    static func decode(from data: Data) -> MeshRelayPacket? {
        try? JSONDecoder().decode(MeshRelayPacket.self, from: data)
    }
}

/// Tracks recently seen packet ids so a packet circulating the mesh is only
/// delivered/relayed once. Bounded so memory stays flat during long sessions:
/// the oldest ids are evicted once `limit` is exceeded.
struct SeenPacketCache {
    private var ids: Set<UUID> = []
    private var order: [UUID] = []
    private let limit: Int

    init(limit: Int = 500) {
        self.limit = limit
    }

    /// Records `id` and returns `true` if it had not been seen before.
    /// Returns `false` if the id was already known (i.e. a duplicate).
    mutating func insertIfNew(_ id: UUID) -> Bool {
        guard !ids.contains(id) else { return false }
        ids.insert(id)
        order.append(id)
        if order.count > limit {
            let evicted = order.removeFirst()
            ids.remove(evicted)
        }
        return true
    }
}
