public enum LevelRunner {
    public static let placementThreshold = Fixed(5)
    public static let placementDistance = Fixed(140)

    public static func play(
        level: Level,
        solution: [PieceID]? = nil,
        spec: CarSpec = CarCatalog.starting,
        parts: [PartID] = [],
        catalog: PieceCatalogCache = PieceCatalog.cache,
        maxSteps: Int = 120000
    ) -> (result: LevelResult, session: Session) {
        let script = solution ?? level.solution
        var deck = level.deck()
        if deck.entries.isEmpty {
            var counts: [PieceID: Int] = [:]
            for id in script { counts[id, default: 0] += 1 }
            deck = Deck(entries: counts.map { DeckEntry(piece: $0.key, count: Swift.min(Deck.countLimit, $0.value)) })
        }

        var session = Session(
            catalog: catalog,
            deck: deck,
            spec: spec,
            parts: parts,
            seed: 1,
            level: level
        )

        var cursor = 0
        var steps = 0
        while session.isRunning && steps < maxSteps {
            let clocks = session.clocks
            let needsTrack = clocks.runwaySeconds < placementThreshold
                || clocks.runway < placementDistance
            if cursor < script.count && needsTrack {
                let id = script[cursor]
                if let slot = session.hand.firstIndex(where: { $0.piece == id }) {
                    if session.place(slot: slot) == nil { cursor += 1 }
                } else if session.forcePlace(id) == nil {
                    cursor += 1
                }
            }
            session.step()
            steps += 1
        }

        let result = session.outcome ?? LevelResult(
            completed: session.objectives.reachedGoal,
            piecesUsed: session.placedCount,
            elapsed: session.car.elapsed,
            coresCollected: session.objectives.collectedCount,
            coreTotal: level.cores.count,
            crashReason: session.car.crashReason
        )
        return (result, session)
    }

    public static func verify(level: Level, catalog: PieceCatalogCache = PieceCatalog.cache) -> LevelProblem? {
        if level.solution.isEmpty { return .noSolution }
        let played = play(level: level, catalog: catalog)
        if !played.result.completed { return .solutionDoesNotFinish(played.result.crashReason) }
        if played.result.piecesUsed > level.parPieces { return .solutionExceedsPar(played.result.piecesUsed, level.parPieces) }
        if level.targetTime > .zero && played.result.elapsed > level.targetTime * Fixed(2) {
            return .targetTimeUnreachable(played.result.elapsed)
        }
        return nil
    }
}

public enum LevelProblem: Sendable, Hashable {
    case noSolution
    case solutionDoesNotFinish(CrashReason?)
    case solutionExceedsPar(Int, Int)
    case targetTimeUnreachable(Fixed)
    case unknownPiece(PieceID)
}
