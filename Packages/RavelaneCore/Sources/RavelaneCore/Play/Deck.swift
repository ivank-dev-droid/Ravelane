public struct DeckEntry: Sendable, Hashable, Codable {
    public var piece: PieceID
    public var count: Int

    public init(piece: PieceID, count: Int) {
        self.piece = piece
        self.count = count
    }
}

public struct Deck: Sendable, Hashable, Codable {
    public static let slotLimit = 12
    public static let countLimit = 5

    public var entries: [DeckEntry]

    public init(entries: [DeckEntry]) {
        self.entries = entries
    }

    public init(_ pieces: [(String, Int)]) {
        self.entries = pieces.map { DeckEntry(piece: PieceID($0.0), count: $0.1) }
    }

    public var totalPieces: Int { entries.reduce(0) { $0 + $1.count } }

    public var pieceTypes: [PieceID] { entries.map(\.piece) }

    public func contains(_ id: PieceID) -> Bool { entries.contains { $0.piece == id } }

    public enum Problem: Sendable, Hashable {
        case tooManySlots(Int)
        case emptyDeck
        case countOutOfRange(PieceID, Int)
        case duplicateEntry(PieceID)
        case unknownPiece(PieceID)
        case missingCore([PieceID])
    }

    public func missingCore(from palette: [PieceID], catalog: PieceCatalogCache) -> [PieceID] {
        let required = Archetype.core(from: palette, catalog: catalog)
        let held = Set(pieceTypes)
        return required.filter { !held.contains($0) }
    }

    public func completed(against palette: [PieceID], catalog: PieceCatalogCache = PieceCatalog.cache) -> Deck {
        let missing = missingCore(from: palette, catalog: catalog)
        guard !missing.isEmpty else { return self }

        var kept = entries
        for id in missing {
            if kept.count >= Deck.slotLimit {
                let index = kept.lastIndex { !Archetype.core(from: palette, catalog: catalog).contains($0.piece) }
                if let index { kept.remove(at: index) } else { break }
            }
            kept.append(DeckEntry(piece: id, count: 2))
        }
        return Deck(entries: kept)
    }

    public func problems(against catalog: PieceCatalogCache) -> [Problem] {
        var found: [Problem] = []
        if entries.count > Deck.slotLimit { found.append(.tooManySlots(entries.count)) }
        if entries.isEmpty { found.append(.emptyDeck) }
        var seen = Set<PieceID>()
        for entry in entries {
            if entry.count < 1 || entry.count > Deck.countLimit {
                found.append(.countOutOfRange(entry.piece, entry.count))
            }
            if !seen.insert(entry.piece).inserted {
                found.append(.duplicateEntry(entry.piece))
            }
            if catalog.piece(entry.piece) == nil {
                found.append(.unknownPiece(entry.piece))
            }
        }
        return found
    }

    public func problems(against catalog: PieceCatalogCache, palette: [PieceID]) -> [Problem] {
        var found = problems(against: catalog)
        let missing = missingCore(from: palette, catalog: catalog)
        if !missing.isEmpty { found.append(.missingCore(missing)) }
        return found
    }

    public func draw(
        using rng: inout SplitMix64,
        preferringAbsent absent: Set<PieceID> = [],
        sorter: Bool = false
    ) -> PieceID? {
        guard !entries.isEmpty else { return nil }

        var weights: [Int] = []
        weights.reserveCapacity(entries.count)
        var total = 0
        for entry in entries {
            var weight = entry.count
            if sorter && !absent.contains(entry.piece) { weight *= 3 }
            weights.append(weight)
            total += weight
        }
        guard total > 0 else { return nil }

        var roll = Int(rng.next(upperBound: UInt64(total)))
        for (index, weight) in weights.enumerated() {
            roll -= weight
            if roll < 0 { return entries[index].piece }
        }
        return entries.last?.piece
    }
}

public enum DeckPresets {
    public static let runway = Deck([
        ("long_run", 5), ("straight", 4), ("stub", 2), ("adjustable_curve", 3),
        ("gentle_curve_l", 2), ("gentle_curve_r", 2), ("rise_shallow", 2),
        ("drop_shallow", 2), ("wide_plate", 2), ("bank_l", 1), ("bank_r", 1),
        ("crest", 1)
    ])

    public static let scalpel = Deck([
        ("sharp_curve_l", 4), ("sharp_curve_r", 4), ("hairpin_l", 2), ("hairpin_r", 2),
        ("stub", 5), ("chicane_lr", 3), ("straight", 2), ("rise_steep", 2),
        ("drop_steep", 2), ("bank_l", 2), ("bank_r", 2), ("narrow_bridge", 2)
    ])

    public static let bank = Deck([
        ("bank_l", 4), ("bank_r", 4), ("banked_curve_l", 4), ("banked_curve_r", 4),
        ("straight", 3), ("long_run", 2), ("sharp_curve_l", 2), ("sharp_curve_r", 2),
        ("wide_plate", 2), ("booster_strip", 2), ("drop_shallow", 2), ("stub", 2)
    ])

    public static let air = Deck([
        ("kicker", 3), ("long_gap", 2), ("landing_pad", 4), ("launch_rail", 2),
        ("crest", 3), ("straight", 4), ("long_run", 3), ("wide_plate", 2),
        ("booster_strip", 3), ("drop_shallow", 2), ("gentle_curve_l", 2),
        ("gentle_curve_r", 2)
    ])

    public static let all: [(name: String, deck: Deck)] = [
        ("Runway", runway), ("Scalpel", scalpel), ("Bank", bank), ("Air", air)
    ]
}
