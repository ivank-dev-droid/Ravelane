public enum LevelForge {
    public static let levelsPerWorld = 10

    static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    public static func palette(for world: WorldID) -> [PieceID] {
        let ids: [String]
        switch world {
        case .foundry:
            ids = ["straight", "long_run", "stub", "gentle_curve_l", "gentle_curve_r",
                   "sharp_curve_l", "sharp_curve_r", "rise_shallow", "drop_shallow",
                   "wide_plate", "bank_l", "bank_r"]
        case .updraft:
            ids = ["straight", "long_run", "stub", "gentle_curve_l", "gentle_curve_r",
                   "rise_shallow", "sharp_curve_l", "sharp_curve_r", "drop_shallow",
                   "banked_curve_l", "banked_curve_r", "brake_strip"]
        case .magnetite:
            ids = ["straight", "stub", "gentle_curve_l", "gentle_curve_r",
                   "sharp_curve_l", "sharp_curve_r", "rise_steep", "drop_steep",
                   "spiral_up", "spiral_down", "bank_l", "bank_r"]
        case .haze:
            ids = ["straight", "long_run", "stub", "gentle_curve_l", "gentle_curve_r",
                   "sharp_curve_l", "sharp_curve_r", "chicane_lr", "rise_shallow",
                   "drop_shallow", "wide_plate", "adjustable_curve"]
        case .rundown:
            ids = ["straight", "long_run", "stub", "gentle_curve_l", "gentle_curve_r",
                   "sharp_curve_l", "sharp_curve_r", "drop_shallow", "drop_steep",
                   "booster_strip", "wide_plate", "narrow_bridge"]
        case .overdrive:
            ids = ["straight", "long_run", "stub", "bank_l", "bank_r",
                   "banked_curve_l", "banked_curve_r", "gentle_curve_l", "gentle_curve_r",
                   "brake_strip", "rise_shallow", "wide_plate"]
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

    public static func forge(world: WorldID, index: Int, seed: UInt64 = 0x5241_5645_4C49_4E10) -> Forged {
        let rules = world.rules
        let ids = palette(for: world)
        let plinth = [PieceID("long_run"), PieceID("stub")]
        let checkpointCount = index < 2 ? 0 : (index < 6 ? 1 : 2)
        let routeLength = 12 + index * 2 + checkpointCount * 5
        let walker = RouteWalker(palette: ids, rules: rules)

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

        var decorRng = derivedStream(
            seed: seed &+ 977,
            purpose: .levelGeneration,
            index: UInt64(index)
        )

        let chain = route.chain
        let total = chain.totalLength
        let plinthEnd = chain.placed[plinth.count - 1].endArcLength

        func point(at fraction: Fixed) -> RibbonSample? {
            chain.sample(atArcLength: plinthEnd + (total - plinthEnd) * fraction)
        }

        var checkpoints: [Gate] = []
        for step in 1...(checkpointCount + 1) {
            let fraction = Fixed(step, over: checkpointCount + 1)
            guard let sample = point(at: fraction) else { continue }
            checkpoints.append(Gate(position: sample.position, normal: sample.tangent, radius: Fixed(14)))
        }
        let goal = checkpoints.removeLast()

        var cores: [Core] = []
        let coreCount = 3 + index / 3
        for slot in 0..<coreCount {
            let fraction = Fixed(slot + 1, over: coreCount + 1)
            guard let sample = point(at: fraction) else { continue }
            let lateral = Fixed(decorRng.nextInt(in: -3...3))
            cores.append(Core(position: sample.position + sample.lateral * lateral))
        }

        var forbidden: [Volume] = []
        let blockCount = index >= 2 ? 1 + index / 3 : 0
        for slot in 0..<blockCount {
            let fraction = Fixed(slot + 1, over: blockCount + 1)
            guard let sample = point(at: fraction) else { continue }
            let sideways = decorRng.nextBool(chanceOutOf: 2) ? Fixed(1) : Fixed(-1)
            let radius = Fixed(14 + decorRng.nextInt(in: 0...8))
            let distance = radius + Fixed(16)
            forbidden.append(.sphere(
                center: sample.position + sample.lateral * sideways * distance,
                radius: radius
            ))
        }

        let level = Level(
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
            parPieces: route.pieces.count + 4,
            targetTime: Fixed(20 + routeLength * 2),
            solution: route.pieces
        )
        return Forged(level: level, route: route.pieces)
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

public enum LevelCatalog {
    public static let all: [Level] = LevelForge.generateAll().map { level in
        var copy = level
        copy.solution = LevelSolutions.table[level.id.rawValue]?.map { PieceID($0) } ?? []
        return copy
    }

    public static func level(_ id: LevelID) -> Level? { all.first { $0.id == id } }

    public static func levels(in world: WorldID) -> [Level] { all.filter { $0.world == world } }

    public static var solved: [Level] { all.filter { !$0.solution.isEmpty } }
}
