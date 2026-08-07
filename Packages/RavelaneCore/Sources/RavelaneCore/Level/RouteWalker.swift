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

    public func route(
        from plinth: [PieceID],
        gates: [Gate],
        rng: inout SplitMix64,
        maxPieces: Int = 90,
        forbidden: [Volume] = []
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
        var gateIndex = 0

        while chosen.count < maxPieces {
            if gateIndex >= gates.count {
                return Walk(pieces: chosen, chain: chain, speeds: speeds)
            }
            let target = gates[gateIndex]

            var scored: [(id: PieceID, samples: [RibbonSample], capsules: [Capsule],
                          exit: Fixed, cost: Fixed, crossings: Int)] = []

            for id in palette {
                guard let piece = catalog.piece(id), let geometry = catalog.geometry(id) else { continue }
                let samples = geometry.samples(from: chain.headFrame)
                let candidate = ClearanceBuilder.capsules(samples: samples, width: piece.width)

                var blocked = false
                for volume in forbidden {
                    for capsule in candidate where volume.intersects(capsule) { blocked = true; break }
                    if blocked { break }
                }
                if blocked { continue }

                let start = chain.totalLength
                let end = start + piece.length
                if intersects(candidate, capsules: capsules, bounds: bounds,
                              chain: chain, start: start, end: end) { continue }

                let travel = SpeedEstimator.traverse(
                    samples: samples, entrySpeed: speed, spec: spec,
                    world: rules, surface: piece.surface
                )
                if travel.worstExcess > -gripMargin || travel.unloaded { continue }
                if travel.stalled || travel.steepestGrade > maximumGrade { continue }

                var crossings = 0
                var cursor = gateIndex
                var sampleIndex = 1
                while sampleIndex < samples.count && cursor < gates.count {
                    if gates[cursor].isCrossed(from: samples[sampleIndex - 1].position,
                                               to: samples[sampleIndex].position) {
                        cursor += 1
                        crossings += 1
                        sampleIndex = 1
                    } else {
                        sampleIndex += 1
                    }
                }

                let head = samples[samples.count - 1].frame
                let remaining = cursor < gates.count ? gates[cursor] : target
                let toTarget = remaining.position - head.position
                let distance = toTarget.length
                let heading = distance.raw == 0 ? Fixed.one : toTarget.normalized.dot(head.forward)
                let cost = distance + (.one - heading) * Fixed(40) - Fixed(crossings) * Fixed(400)
                scored.append((id, samples, candidate, travel.exitSpeed, cost, crossings))
            }

            guard !scored.isEmpty else { return nil }
            scored.sort { $0.cost < $1.cost }

            let width = Swift.min(3, scored.count)
            let pick = scored[Int(rng.next(upperBound: UInt64(width)))]

            chain.append(pick.id, precomputed: pick.samples)
            capsules.append(pick.capsules)
            bounds.append(Solver.bound(pick.capsules))
            chosen.append(pick.id)
            speed = pick.exit
            speeds.append(speed)
            gateIndex += pick.crossings
        }

        return gateIndex >= gates.count ? Walk(pieces: chosen, chain: chain, speeds: speeds) : nil
    }

    public static func solve(
        level: Level,
        catalog: PieceCatalogCache = PieceCatalog.cache,
        spec: CarSpec = CarCatalog.starting,
        attempts: Int = 26,
        seed: UInt64 = 0x5241_5645_4C49_4E20
    ) -> [PieceID]? {
        let walker = RouteWalker(catalog: catalog, palette: level.allowedPieces,
                                 spec: spec, rules: level.rules)
        var best: [PieceID]?
        for attempt in 0..<attempts {
            var rng = derivedStream(seed: seed, purpose: .levelGeneration, index: UInt64(attempt))
            guard let walk = walker.route(
                from: level.plinth,
                gates: level.objectiveOrder,
                rng: &rng,
                forbidden: level.forbidden
            ) else { continue }
            if best == nil || walk.pieces.count < best!.count { best = walk.pieces }
        }
        return best
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
