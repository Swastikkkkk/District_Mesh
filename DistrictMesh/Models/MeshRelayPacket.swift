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

    enum Kind: String, Codable, Sendable {
        case message
        case location
    }

    let id: UUID
    var ttl: Int
    let kind: Kind
    let senderName: String
    let timestamp: Date

    var text: String?
    var latitude: Double?
    var longitude: Double?
    var isEmergency: Bool?

    static let defaultTTL = 10

    init(
        kind: Kind,
        senderName: String,
        ttl: Int = MeshRelayPacket.defaultTTL,
        text: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isEmergency: Bool? = nil,
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
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data) -> MeshRelayPacket? {
        try? JSONDecoder().decode(MeshRelayPacket.self, from: data)
    }
}

/// Tracks recently seen packet ids so a packet circulating the mesh is only
/// delivered/relayed once. Bounded so memory stays flat during long sessions.
struct SeenPacketCache {
    private var ids: Set<UUID> = []
    private var order: [UUID] = []
    private let limit: Int

    init(limit: Int = 500) {
        self.limit = limit
    }

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
