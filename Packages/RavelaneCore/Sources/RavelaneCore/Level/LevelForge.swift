public enum LevelForge {
    public static let levelsPerWorld = 15

    static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    public static func palette(for world: WorldID) -> [PieceID] {
        let ids: [String]
        switch world {
        case .foundry:
            ids = ["straight", "long_run", "stub", "gentle_curve_l", "gentle_curve_r",
                   "sharp_curve_l", "sharp_curve_r", "rise_shallow", "drop_shallow",
                   "wide_plate", "bank_l", "bank_r",
                   "crest", "dip", "chicane_lr", "booster_strip", "brake_strip", "adjustable_curve"]
        case .updraft:
            ids = ["straight", "long_run", "stub", "gentle_curve_l", "gentle_curve_r",
                   "rise_shallow", "sharp_curve_l", "sharp_curve_r", "drop_shallow",
                   "banked_curve_l", "banked_curve_r", "brake_strip",
                   "kicker", "landing_pad", "crest", "wide_plate", "bank_l", "bank_r"]
        case .magnetite:
            ids = ["straight", "stub", "gentle_curve_l", "gentle_curve_r",
                   "sharp_curve_l", "sharp_curve_r", "rise_steep", "drop_steep",
                   "spiral_up", "spiral_down", "bank_l", "bank_r",
                   "wide_plate", "banked_curve_l", "banked_curve_r", "chicane_lr", "long_run", "brake_strip"]
        case .haze:
            ids = ["straight", "long_run", "stub", "gentle_curve_l", "gentle_curve_r",
                   "sharp_curve_l", "sharp_curve_r", "chicane_lr", "rise_shallow",
                   "drop_shallow", "wide_plate", "adjustable_curve",
                   "bank_l", "bank_r", "banked_curve_l", "banked_curve_r", "crest", "brake_strip"]
        case .rundown:
            ids = ["straight", "long_run", "stub", "gentle_curve_l", "gentle_curve_r",
                   "sharp_curve_l", "sharp_curve_r", "drop_shallow", "drop_steep",
                   "booster_strip", "wide_plate", "narrow_bridge",
                   "bank_l", "bank_r", "banked_curve_l", "banked_curve_r", "chicane_lr", "stub"]
        case .overdrive:
            ids = ["straight", "long_run", "stub", "bank_l", "bank_r",
                   "banked_curve_l", "banked_curve_r", "gentle_curve_l", "gentle_curve_r",
                   "brake_strip", "rise_shallow", "wide_plate",
                   "long_run", "sharp_curve_l", "sharp_curve_r", "chicane_lr", "crest", "booster_strip"]
        }
        return ids.map { PieceID($0) }
    }

    public static func generate(world: WorldID, index: Int, seed: UInt64 = 0x5241_5645_4C49_4E10) -> Level {
        forge(world: world, index: index, seed: seed).level
    }

    public struct Forged: Sendable {
        public var level: Level
        public var route: [PieceID]
    }

    public static func summary(world: WorldID, index: Int) -> LevelSummary {
        let id = LevelID("\(world.rawValue)_\(twoDigits(index + 1))")
        let solution = LevelSolutions.table[id.rawValue]?.count ?? 0
        let checkpointCount = index < 2 ? 0 : (index < 7 ? 1 : (index < 12 ? 2 : 3))
        let routeLength = 12 + index * 2 + checkpointCount * 5
        return LevelSummary(
            id: id,
            name: "\(world.displayName) \(index + 1)",
            world: world,
            parPieces: Swift.max(16 + index * 2 + checkpointCount * 6, solution + 3),
            coreCount: 3 + index / 3,
            checkpointCount: checkpointCount,
            routeLength: routeLength,
            isSolved: solution > 0
        )
    }

    public static func rebuild(world: WorldID, index: Int) -> Level? {
        let id = LevelID("\(world.rawValue)_\(twoDigits(index + 1))")
        guard let stored = LevelSolutions.table[id.rawValue], !stored.isEmpty else { return nil }
        return assemble(world: world, index: index, route: stored.map { PieceID($0) })
    }

    public static func forge(world: WorldID, index: Int, seed: UInt64 = 0x5241_5645_4C49_4E10) -> Forged {
        let rules = world.rules
        let ids = palette(for: world)
        let plinth = [PieceID("long_run"), PieceID("stub")]
        let checkpointCount = index < 2 ? 0 : (index < 7 ? 1 : (index < 12 ? 2 : 3))
        let routeLength = 12 + index * 2 + checkpointCount * 5
        let walker = RouteWalker(palette: Archetype.core(from: ids), rules: rules)

        var walk: RouteWalker.Walk?
        var attempt: UInt64 = 0
        while walk == nil && attempt < 40 {
            var rng = derivedStream(
                seed: seed,
                purpose: .levelGeneration,
                index: UInt64(WorldID.allCases.firstIndex(of: world)! * 1000 + index * 50) + attempt
            )
            walk = walker.walk(
                from: plinth,
                pieces: routeLength,
                rng: &rng,
                turnAppetite: Fixed(35, over: 100) + Fixed(index, over: 40)
            )
            attempt += 1
        }

        guard let route = walk else {
            return Forged(
                level: Level(
                    id: LevelID("\(world.rawValue)_\(twoDigits(index + 1))"),
                    name: "\(world.displayName) \(index + 1)",
                    world: world,
                    allowedPieces: ids,
                    goal: Gate(position: Vec3(.zero, .zero, Fixed(120)), radius: Fixed(16))
                ),
                route: []
            )
        }

        let assembled = assemble(world: world, index: index, route: route.pieces)
        return Forged(level: assembled, route: route.pieces)
    }

    public static func assemble(world: WorldID, index: Int, route: [PieceID]) -> Level {
        let ids = palette(for: world)
        let plinth = [PieceID("long_run"), PieceID("stub")]
        let checkpointCount = index < 2 ? 0 : (index < 7 ? 1 : (index < 12 ? 2 : 3))

        var chain = TrackChain(catalog: PieceCatalog.cache)
        chain.appendAll(plinth)
        chain.appendAll(route)

        var decorRng = derivedStream(
            seed: 0x5241_5645_4C49_4E10 &+ 977,
            purpose: .levelGeneration,
            index: UInt64(index)
        )

        let total = chain.totalLength
        let plinthEnd = chain.placed[plinth.count - 1].endArcLength

        func point(at fraction: Fixed) -> RibbonSample? {
            chain.sample(atArcLength: plinthEnd + (total - plinthEnd) * fraction)
        }

        var checkpoints: [Gate] = []
        for step in 1...(checkpointCount + 1) {
            let fraction = Fixed(step, over: checkpointCount + 1)
            guard let sample = point(at: fraction) else { continue }
            checkpoints.append(Gate(position: sample.position, normal: sample.tangent, radius: Fixed(24)))
        }
        let goal = checkpoints.isEmpty
            ? Gate(position: chain.headFrame.position, normal: chain.headFrame.forward, radius: Fixed(24))
            : checkpoints.removeLast()

        var cores: [Core] = []
        let coreCount = 3 + index / 3
        for slot in 0..<coreCount {
            let fraction = Fixed(slot + 1, over: coreCount + 1)
            guard let sample = point(at: fraction) else { continue }
            let lateral = Fixed(decorRng.nextInt(in: -3...3))
            cores.append(Core(position: sample.position + sample.lateral * lateral))
        }

        var routeCapsules: [Capsule] = []
        for pieceIndex in 0..<chain.placed.count {
            routeCapsules.append(contentsOf: ClearanceBuilder.capsules(for: chain, pieceIndex: pieceIndex))
        }

        func clearsRoute(_ volume: Volume) -> Bool {
            for capsule in routeCapsules where volume.intersects(capsule) { return false }
            return true
        }

        var forbidden: [Volume] = []
        let blockCount = index >= 2 ? 1 + index / 3 : 0
        for slot in 0..<blockCount {
            let fraction = Fixed(slot + 1, over: blockCount + 1)
            guard let sample = point(at: fraction) else { continue }
            let sideways = decorRng.nextBool(chanceOutOf: 2) ? Fixed(1) : Fixed(-1)
            let radius = Fixed(14 + decorRng.nextInt(in: 0...8))
            var pushed = radius + Fixed(16)
            var placed: Volume?
            for _ in 0..<8 {
                let candidate = Volume.sphere(
                    center: sample.position + sample.lateral * sideways * pushed,
                    radius: radius
                )
                if clearsRoute(candidate) { placed = candidate; break }
                pushed += Fixed(10)
            }
            if let placed { forbidden.append(placed) }
        }

        let routeLength = 12 + index * 2 + checkpointCount * 5
        return Level(
            id: LevelID("\(world.rawValue)_\(twoDigits(index + 1))"),
            name: "\(world.displayName) \(index + 1)",
            world: world,
            plinth: plinth,
            startingMaterial: 260 + routeLength * 22,
            allowedPieces: ids,
            goal: goal,
            checkpoints: checkpoints,
            cores: cores,
            forbidden: forbidden,
            parPieces: Swift.max(16 + index * 2 + checkpointCount * 6, route.count + 3),
            targetTime: Fixed(20 + routeLength * 2),
            solution: route
        )
    }

    public static func generateAll(seed: UInt64 = 0x5241_5645_4C49_4E10) -> [Level] {
        var result: [Level] = []
        for world in WorldID.allCases {
            for index in 0..<levelsPerWorld {
                result.append(generate(world: world, index: index, seed: seed))
            }
        }
        return result
    }
}

public struct LevelSummary: Sendable, Hashable, Codable, Identifiable {
    public var id: LevelID
    public var name: String
    public var world: WorldID
    public var parPieces: Int
    public var coreCount: Int
    public var checkpointCount: Int
    public var routeLength: Int
    public var isSolved: Bool

    public var number: Int {
        Int(id.rawValue.split(separator: "_").last.flatMap { Int($0) } ?? 0)
    }
}

public enum LevelCatalog {
    public static let summaries: [LevelSummary] = {
        var result: [LevelSummary] = []
        for world in WorldID.allCases {
            var floor = 0
            for index in 0..<LevelForge.levelsPerWorld {
                var summary = LevelForge.summary(world: world, index: index)
                floor = Swift.max(floor, summary.parPieces)
                summary.parPieces = floor
                result.append(summary)
            }
        }
        return result
    }()

    public static func summaries(in world: WorldID) -> [LevelSummary] {
        summaries.filter { $0.world == world }
    }

    public static func summary(_ id: LevelID) -> LevelSummary? {
        summaries.first { $0.id == id }
    }

    public static func level(_ id: LevelID) -> Level? {
        guard let summary = summary(id) else { return nil }
        guard var level = LevelForge.rebuild(world: summary.world, index: summary.number - 1) else {
            return nil
        }
        level.parPieces = summary.parPieces
        return level
    }

    public static var all: [Level] {
        summaries.compactMap { level($0.id) }
    }

    public static func levels(in world: WorldID) -> [Level] {
        summaries(in: world).compactMap { level($0.id) }
    }

    public static var solved: [Level] { all.filter { !$0.solution.isEmpty } }
}
