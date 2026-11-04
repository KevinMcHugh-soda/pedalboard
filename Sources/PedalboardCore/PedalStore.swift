import Foundation

/// What a device was set to before Pedalboard silenced it, so releasing puts
/// it back exactly.
public enum SavedState: Codable, Equatable, Sendable {
    case muteSwitch(wasMuted: Bool)
    case volume(Float)
}

/// Where `Pedal` keeps what must outlive the process. If the app dies while
/// engaged, the next launch finds the pedal still down and every original
/// setting still known, so nothing is left silenced or unmuted by surprise.
@MainActor
public protocol PedalStore: AnyObject {
    var isEngaged: Bool { get set }
    /// By device UID.
    var savedStates: [String: SavedState] { get set }
    /// By device UID. A device with no entry is live if it is built in.
    var liveOverrides: [String: Bool] { get set }
    /// Whether making a mic live makes every other mic not live.
    var isOneLiveMic: Bool { get set }
}

/// `PedalStore` in the variant's UserDefaults domain, which the app and the
/// CLI share.
@MainActor
public final class DefaultsStore: PedalStore {
    private let defaults: UserDefaults

    public init(variant: AppVariant = .current) {
        defaults = UserDefaults(suiteName: variant.bundleIdentifier) ?? .standard
    }

    public var isEngaged: Bool {
        get { defaults.bool(forKey: "engaged") }
        set { defaults.set(newValue, forKey: "engaged") }
    }

    public var savedStates: [String: SavedState] {
        get {
            guard let data = defaults.data(forKey: "savedStates") else { return [:] }
            return (try? JSONDecoder().decode([String: SavedState].self, from: data)) ?? [:]
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "savedStates") }
    }

    public var liveOverrides: [String: Bool] {
        get { defaults.dictionary(forKey: "liveOverrides") as? [String: Bool] ?? [:] }
        set { defaults.set(newValue, forKey: "liveOverrides") }
    }

    public var isOneLiveMic: Bool {
        get { defaults.bool(forKey: "oneLiveMic") }
        set { defaults.set(newValue, forKey: "oneLiveMic") }
    }
}

/// `PedalStore` that forgets everything on exit.
@MainActor
public final class MemoryStore: PedalStore {
    public var isEngaged = false
    public var savedStates: [String: SavedState] = [:]
    public var liveOverrides: [String: Bool] = [:]
    public var isOneLiveMic = false

    public init() {}
}
