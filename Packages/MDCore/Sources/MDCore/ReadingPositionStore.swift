import CryptoKit
import Foundation

/// A string store behind the reading positions, so tests don't touch `UserDefaults.standard`.
public protocol KeyValueStorage: AnyObject {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
}

extension UserDefaults: KeyValueStorage {
    public func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    public func set(_ value: String?, forKey key: String) {
        if let value {
            set(value as Any, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}

/// Where the reader stopped in each file, as a fraction of the scrollable distance (0…1).
///
/// A file is keyed by the SHA-256 hex of its standardized path, so the stored JSON holds no file names. The most recent
/// `capacity` files are kept; a position under `floor` is not worth restoring and is not recorded.
public final class ReadingPositionStore {
    public static let storageKey = "reader.positions"
    public static let capacity = 200
    public static let floor = 0.02

    private struct Entry: Codable, Equatable {
        var key: String
        var fraction: Double
    }

    private let storage: KeyValueStorage

    public init(storage: KeyValueStorage) {
        self.storage = storage
    }

    /// The stable key for a file: SHA-256 hex of its standardized path.
    public static func key(for url: URL) -> String {
        let path = url.standardizedFileURL.path
        return SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    public func position(for url: URL) -> Double? {
        let key = Self.key(for: url)
        return load().first { $0.key == key }?.fraction
    }

    /// Records `fraction` (clamped to 0…1) and makes the file the most recent. Non-finite values and values under the
    /// floor are ignored.
    public func record(_ fraction: Double, for url: URL) {
        guard fraction.isFinite else {
            return
        }
        let clamped = min(max(fraction, 0), 1)
        guard clamped >= Self.floor else {
            return
        }
        let key = Self.key(for: url)
        var entries = load().filter { $0.key != key }
        entries.append(Entry(key: key, fraction: clamped))
        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
        save(entries)
    }

    public var count: Int {
        load().count
    }

    private func load() -> [Entry] {
        guard let text = storage.string(forKey: Self.storageKey),
              let entries = try? JSONDecoder().decode([Entry].self, from: Data(text.utf8))
        else {
            return []
        }
        return entries
    }

    private func save(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries), let text = String(data: data, encoding: .utf8) else {
            return
        }
        storage.set(text, forKey: Self.storageKey)
    }
}
