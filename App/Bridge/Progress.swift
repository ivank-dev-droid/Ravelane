import Foundation
import Observation
import RavelinCore

@MainActor
@Observable
final class ProgressStore {
    static let shared = ProgressStore()

    private(set) var stars: [String: Int]
    private(set) var attempts: [String: Int]
    private(set) var bestPieces: [String: Int]

    private let store = UserDefaults.standard
    private enum Keys {
        static let stars = "ravelin.stars"
        static let attempts = "ravelin.attempts"
        static let bestPieces = "ravelin.bestPieces"
    }

    private init() {
        stars = store.dictionary(forKey: Keys.stars) as? [String: Int] ?? [:]
        attempts = store.dictionary(forKey: Keys.attempts) as? [String: Int] ?? [:]
        bestPieces = store.dictionary(forKey: Keys.bestPieces) as? [String: Int] ?? [:]
    }

    func stars(for id: LevelID) -> Int { stars[id.rawValue] ?? 0 }
    func attempts(for id: LevelID) -> Int { attempts[id.rawValue] ?? 0 }
    func bestPieces(for id: LevelID) -> Int? { bestPieces[id.rawValue] }

    func recordAttempt(_ id: LevelID) {
        attempts[id.rawValue, default: 0] += 1
        store.set(attempts, forKey: Keys.attempts)
    }

    func record(result: LevelResult, for level: Level) {
        let earned = result.stars(for: level)
        let key = level.id.rawValue
        if earned > (stars[key] ?? 0) {
            stars[key] = earned
            store.set(stars, forKey: Keys.stars)
        }
        if result.completed {
            let previous = bestPieces[key] ?? Int.max
            if result.piecesUsed < previous {
                bestPieces[key] = result.piecesUsed
                store.set(bestPieces, forKey: Keys.bestPieces)
            }
        }
    }

    var totalStars: Int { stars.values.reduce(0, +) }
    var clearedCount: Int { stars.values.filter { $0 > 0 }.count }

    func stars(in world: WorldID) -> Int {
        LevelCatalog.summaries(in: world).reduce(0) { $0 + stars(for: $1.id) }
    }

    func cleared(in world: WorldID) -> Int {
        LevelCatalog.summaries(in: world).filter { stars(for: $0.id) > 0 }.count
    }

    func isUnlocked(_ summary: LevelSummary) -> Bool {
        guard summary.number > 1 else { return true }
        let previous = LevelCatalog.summaries(in: summary.world)
            .first { $0.number == summary.number - 1 }
        guard let previous else { return true }
        return stars(for: previous.id) > 0
    }

    func reset() {
        stars = [:]
        attempts = [:]
        bestPieces = [:]
        store.removeObject(forKey: Keys.stars)
        store.removeObject(forKey: Keys.attempts)
        store.removeObject(forKey: Keys.bestPieces)
    }
}

@MainActor
@Observable
final class DeckStore {
    static let shared = DeckStore()

    private(set) var custom: [String: [String: Int]]
    private let store = UserDefaults.standard
    private let key = "ravelin.decks"

    private init() {
        custom = store.dictionary(forKey: key) as? [String: [String: Int]] ?? [:]
    }

    func deck(for world: WorldID, palette: [PieceID]) -> Deck {
        if let saved = custom[world.rawValue], !saved.isEmpty {
            let entries = saved
                .sorted { $0.key < $1.key }
                .map { DeckEntry(piece: PieceID($0.key), count: $0.value) }
            if !entries.isEmpty { return Deck(entries: entries) }
        }
        return Archetype.runway.deck(from: palette)
    }

    func save(_ deck: Deck, for world: WorldID) {
        var table: [String: Int] = [:]
        for entry in deck.entries { table[entry.piece.rawValue] = entry.count }
        custom[world.rawValue] = table
        store.set(custom, forKey: key)
    }

    func clear(_ world: WorldID) {
        custom[world.rawValue] = nil
        store.set(custom, forKey: key)
    }
}
