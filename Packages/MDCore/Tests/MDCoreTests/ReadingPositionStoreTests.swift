import Foundation
import Testing
@testable import MDCore

private final class MemoryStorage: KeyValueStorage {
    var values: [String: String] = [:]

    func string(forKey key: String) -> String? {
        values[key]
    }

    func set(_ value: String?, forKey key: String) {
        values[key] = value
    }
}

struct ReadingPositionStoreTests {
    private let storage = MemoryStorage()
    private var store: ReadingPositionStore {
        ReadingPositionStore(storage: storage)
    }

    private func file(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/mdview/\(name).md")
    }

    @Test func `round trip survives a new store on the same storage`() {
        store.record(0.4, for: file("a"))
        #expect(ReadingPositionStore(storage: storage).position(for: file("a")) == 0.4)
        #expect(store.position(for: file("b")) == nil)
    }

    @Test func `values clamp to one and ignore non finite`() {
        store.record(3, for: file("a"))
        #expect(store.position(for: file("a")) == 1)
        store.record(.nan, for: file("b"))
        store.record(-1, for: file("b"))
        #expect(store.position(for: file("b")) == nil)
    }

    @Test func `nothing is recorded below the floor`() {
        store.record(0.019, for: file("a"))
        #expect(store.position(for: file("a")) == nil)
        store.record(0.02, for: file("a"))
        #expect(store.position(for: file("a")) == 0.02)
    }

    @Test func `the 201st file prunes the least recent`() {
        for index in 0 ..< 201 {
            store.record(0.5, for: file("f\(index)"))
        }
        #expect(store.count == 200)
        #expect(store.position(for: file("f0")) == nil)
        #expect(store.position(for: file("f1")) == 0.5)
        #expect(store.position(for: file("f200")) == 0.5)
    }

    @Test func `recording again makes a file most recent`() {
        for index in 0 ..< 200 {
            store.record(0.5, for: file("f\(index)"))
        }
        store.record(0.6, for: file("f0"))
        store.record(0.5, for: file("new"))
        #expect(store.position(for: file("f0")) == 0.6)
        #expect(store.position(for: file("f1")) == nil)
    }

    @Test func `the key is a stable sha256 hex`() {
        // sha256("/tmp/mdview/a.md")
        let key = ReadingPositionStore.key(for: file("a"))
        #expect(key.count == 64)
        #expect(key == ReadingPositionStore.key(for: file("a")))
        #expect(key != ReadingPositionStore.key(for: file("b")))
        #expect(key.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    @Test func `paths are standardized before hashing`() {
        let plain = URL(fileURLWithPath: "/tmp/mdview/a.md")
        let dotted = URL(fileURLWithPath: "/tmp/mdview/sub/../a.md")
        #expect(ReadingPositionStore.key(for: plain) == ReadingPositionStore.key(for: dotted))
        store.record(0.3, for: plain)
        #expect(store.position(for: dotted) == 0.3)
    }

    @Test func `stored json holds no file names`() throws {
        store.record(0.3, for: file("secret-name"))
        let text = try #require(storage.values[ReadingPositionStore.storageKey])
        #expect(!text.contains("secret-name"))
    }

    @Test func `corrupt storage reads as empty`() {
        storage.values[ReadingPositionStore.storageKey] = "not json"
        #expect(store.position(for: file("a")) == nil)
        store.record(0.5, for: file("a"))
        #expect(store.position(for: file("a")) == 0.5)
    }
}
