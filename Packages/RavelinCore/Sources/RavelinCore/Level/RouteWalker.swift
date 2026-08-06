public struct RouteWalker {
    public struct Walk: Sendable {
        public var pieces: [PieceID]
        public var chain: TrackChain
        public var speeds: [Fixed]
    }

    public let catalog: PieceCatalogCache
    public let palette: [PieceID]
    public let spec: CarSpec
    public let rules: WorldRules
    public let gripMargin: Fixed
    public let maximumGrade: Fixed

    public init(
        catalog: PieceCatalogCache = PieceCatalog.cache,
        palette: [PieceID],
        spec: CarSpec = CarCatalog.starting,
        rules: WorldRules,
        gripMargin: Fixed = Fixed(22),
        maximumGrade: Fixed = Fixed(5, over: 10)
    ) {
        self.catalog = catalog
        self.palette = palette
        self.spec = spec
        self.rules = rules
        self.gripMargin = gripMargin
        self.maximumGrade = maximumGrade
    }

    public func walk(
        from plinth: [PieceID],
        pieces targetCount: Int,
        rng: inout SplitMix64,
        turnAppetite: Fixed = Fixed(1, over: 2)
    ) -> Walk? {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll(plinth)

        var capsules: [[Capsule]] = []
        var bounds: [(centre: Vec3, radius: Fixed)] = []
        for index in 0..<chain.placed.count {
            let built = ClearanceBuilder.capsules(for: chain, pieceIndex: index)
            capsules.append(built)
            bounds.append(Solver.bound(built))
        }

        var speed = rules.startSpeed
        var chosen: [PieceID] = []
        var speeds: [Fixed] = [speed]

        while chosen.count < targetCount {
            var options: [(id: PieceID, samples: [RibbonSample], capsules: [Capsule], exit: Fixed, turn: Fixed)] = []

            for id in palette {
                guard let piece = catalog.piece(id), let geometry = catalog.geometry(id) else { continue }
                let samples = geometry.samples(from: chain.headFrame)
                let candidate = ClearanceBuilder.capsules(samples: samples, width: piece.width)

                let start = chain.totalLength
                let end = start + piece.length
                if intersects(candidate, capsules: capsules, bounds: bounds, chain: chain, start: start, end: end) {
                    continue
                }

                let travel = SpeedEstimator.traverse(
                    samples: samples,
                    entrySpeed: speed,
                    spec: spec,
                    world: rules,
                    surface: piece.surface
                )
                if travel.worstExcess > -gripMargin || travel.unloaded { continue }
                if travel.stalled || travel.steepestGrade > maximumGrade { continue }
                if travel.exitSpeed > spec.absoluteTopSpeed * Fixed(9, over: 10) &&
                    piece.tags.contains(.speedGain) { continue }

                options.append((id, samples, candidate, travel.exitSpeed,
                                piece.totalYaw.magnitude + piece.totalPitch.magnitude))
            }

            guard !options.isEmpty else { return nil }

            let wantTurn = rng.nextUnitFixed() < turnAppetite
            let turning = options.filter { $0.turn.raw > 0 }
            let straightish = options.filter { $0.turn.raw == 0 }
            let pool = wantTurn && !turning.isEmpty ? turning
                : (!straightish.isEmpty ? straightish : options)

            let pick = pool[Int(rng.next(upperBound: UInt64(pool.count)))]
            chain.append(pick.id, precomputed: pick.samples)
            capsules.append(pick.capsules)
            bounds.append(Solver.bound(pick.capsules))
            chosen.append(pick.id)
            speed = pick.exit
            speeds.append(speed)
        }

        return Walk(pieces: chosen, chain: chain, speeds: speeds)
    }

    private func intersects(
        _ candidate: [Capsule],
        capsules: [[Capsule]],
        bounds: [(centre: Vec3, radius: Fixed)],
        chain: TrackChain,
        start: Fixed,
        end: Fixed
    ) -> Bool {
        let window = ClearanceBuilder.selfContactWindow
        let candidateBound = Solver.bound(candidate)
        for index in 0..<chain.placed.count {
            guard index < capsules.count else { continue }
            let record = chain.placed[index]
            if record.endArcLength > start - window && record.startArcLength < end + window { continue }
            let existing = bounds[index]
            if existing.centre.distance(to: candidateBound.centre) > existing.radius + candidateBound.radius {
                continue
            }
            for a in capsules[index] {
                for b in candidate {
                    let combined = a.radius + b.radius
                    if SegmentDistance.closestSquared(a.start, a.end, b.start, b.end) < combined * combined {
                        return true
                    }
                }
            }
        }
        return false
    }
}
