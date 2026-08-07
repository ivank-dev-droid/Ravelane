public enum Archetype: String, Sendable, Hashable, Codable, CaseIterable {
    case runway
    case scalpel
    case bank
    case air

    public var displayName: String {
        switch self {
        case .runway: return "Runway"
        case .scalpel: return "Scalpel"
        case .bank: return "Bank"
        case .air: return "Air"
        }
    }

    public var summary: String {
        switch self {
        case .runway: return "Buy thinking time. Long straights, navigate with the least turning you can."
        case .scalpel: return "Shortest possible line. Sharp, cheap, always two seconds from the end."
        case .bank: return "Lay the camber before the corner and carry speed nothing else can."
        case .air: return "Skip the ground. Launch, fly, land, repeat."
        }
    }

    public static let minimumTurners = 5
    public static let minimumStraights = 2
    public static let minimumSlowers = 1

    public func affinity(for piece: Piece) -> Int {
        var score = 10

        switch self {
        case .runway:
            if piece.tags.contains(.runwayBuy) { score += 40 }
            if piece.pieceClass == .straight { score += 24 }
            if piece.tags.contains(.forgiving) { score += 10 }
            if piece.tags.contains(.speedLoss) { score -= 6 }
        case .scalpel:
            if piece.pieceClass == .turn { score += 34 }
            if piece.tags.contains(.navigation) { score += 18 }
            if piece.length < Fixed(16) { score += 16 }
            if piece.tags.contains(.runwayBuy) { score -= 10 }
        case .bank:
            if piece.totalRoll.magnitude > .zero { score += 44 }
            if piece.tags.contains(.forgiving) { score += 16 }
            if piece.pieceClass == .turn { score += 18 }
        case .air:
            if piece.isGap { score += 46 }
            if piece.pieceClass == .air { score += 30 }
            if piece.tags.contains(.speedGain) { score += 18 }
            if piece.pieceClass == .vertical { score += 12 }
        }

        if piece.pieceClass == .straight { score += 8 }
        if piece.tags.contains(.utility) { score += 4 }
        return Swift.max(1, score)
    }

    public static let coreSlots = 8

    public static func core(
        from palette: [PieceID],
        catalog: PieceCatalogCache = PieceCatalog.cache
    ) -> [PieceID] {
        let pieces = palette.compactMap { catalog.piece($0) }
        func pick(_ candidates: [Piece], _ count: Int) -> [Piece] {
            var sorted = candidates
            sorted.sort { (left: Piece, right: Piece) -> Bool in
                if left.cost == right.cost { return left.id.rawValue < right.id.rawValue }
                return left.cost < right.cost
            }
            return Array(sorted.prefix(count))
        }

        var chosen: [Piece] = []
        var used = Set<PieceID>()
        func add(_ list: [Piece]) {
            for piece in list where !used.contains(piece.id) {
                chosen.append(piece)
                used.insert(piece.id)
            }
        }

        add(pick(pieces.filter { $0.totalYaw < .zero }, 2))
        add(pick(pieces.filter { $0.totalYaw > .zero }, 2))
        add(pick(pieces.filter { $0.pieceClass == .straight }, 2))
        add(pick(pieces.filter { $0.totalPitch != .zero }, 1))
        add(pick(pieces.filter { $0.tags.contains(.speedLoss) || $0.surface == .brake }, 1))
        add(pick(pieces, coreSlots))

        return Array(chosen.prefix(coreSlots)).map(\.id)
    }

    public func deck(
        from palette: [PieceID],
        catalog: PieceCatalogCache = PieceCatalog.cache,
        slots: Int = Deck.slotLimit
    ) -> Deck {
        let core = Archetype.core(from: palette, catalog: catalog)
        var used = Set(core)
        var chosen = core.compactMap { catalog.piece($0) }

        let available: [Piece] = palette.compactMap { catalog.piece($0) }
        var remaining: [Piece] = []
        for piece in available where !used.contains(piece.id) {
            remaining.append(piece)
        }
        remaining.sort { (left: Piece, right: Piece) -> Bool in
            let leftScore = affinity(for: left)
            let rightScore = affinity(for: right)
            if leftScore == rightScore { return left.id.rawValue < right.id.rawValue }
            return leftScore > rightScore
        }

        for piece in remaining where chosen.count < slots {
            chosen.append(piece)
            used.insert(piece.id)
        }

        var entries: [DeckEntry] = []
        for piece in chosen.prefix(slots) {
            let score = affinity(for: piece)
            let share = (score * Deck.countLimit) / 60
            let count = Swift.max(1, Swift.min(Deck.countLimit, share))
            entries.append(DeckEntry(piece: piece.id, count: count))
        }
        return Deck(entries: entries)
    }

    public func palette(
        from worldPalette: [PieceID],
        catalog: PieceCatalogCache = PieceCatalog.cache,
        slots: Int = Deck.slotLimit
    ) -> [PieceID] {
        deck(from: worldPalette, catalog: catalog, slots: slots).pieceTypes
    }
}
