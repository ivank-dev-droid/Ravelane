public struct LevelID: Sendable, Hashable, Codable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

public enum WorldID: String, Sendable, Hashable, Codable, CaseIterable {
    case foundry
    case updraft
    case magnetite
    case haze
    case rundown
    case overdrive

    public var rules: WorldRules {
        switch self {
        case .foundry: return .foundry
        case .updraft: return .updraft
        case .magnetite: return WorldRules(name: "Magnetite", gravity: Fixed(981, over: 100),
                                           gripScale: Fixed(12, over: 10), startSpeed: Fixed(10))
        case .haze: return WorldRules(name: "Haze", gravity: Fixed(981, over: 100),
                                      gripScale: .one, startSpeed: Fixed(9))
        case .rundown: return WorldRules(name: "Rundown", gravity: Fixed(981, over: 100),
                                         gripScale: Fixed(95, over: 100), startSpeed: Fixed(12))
        case .overdrive: return .overdrive
        }
    }

    public var displayName: String {
        switch self {
        case .foundry: return "Foundry"
        case .updraft: return "Updraft"
        case .magnetite: return "Magnetite"
        case .haze: return "Haze"
        case .rundown: return "Rundown"
        case .overdrive: return "Overdrive"
        }
    }
}

public struct Level: Sendable, Hashable, Codable, Identifiable {
    public var id: LevelID
    public var name: String
    public var world: WorldID
    public var plinth: [PieceID]
    public var startSpeed: Fixed
    public var startingMaterial: Int
    public var allowedPieces: [PieceID]
    public var goal: Gate
    public var checkpoints: [Gate]
    public var cores: [Core]
    public var forbidden: [Volume]
    public var hazards: [Hazard]
    public var parPieces: Int
    public var targetTime: Fixed
    public var solution: [PieceID]

    public init(
        id: LevelID,
        name: String,
        world: WorldID,
        plinth: [PieceID] = [PieceID("long_run"), PieceID("stub")],
        startSpeed: Fixed? = nil,
        startingMaterial: Int = 220,
        allowedPieces: [PieceID] = [],
        goal: Gate,
        checkpoints: [Gate] = [],
        cores: [Core] = [],
        forbidden: [Volume] = [],
        hazards: [Hazard] = [],
        parPieces: Int = 0,
        targetTime: Fixed = .zero,
        solution: [PieceID] = []
    ) {
        self.id = id
        self.name = name
        self.world = world
        self.plinth = plinth
        self.startSpeed = startSpeed ?? world.rules.startSpeed
        self.startingMaterial = startingMaterial
        self.allowedPieces = allowedPieces
        self.goal = goal
        self.checkpoints = checkpoints
        self.cores = cores
        self.forbidden = forbidden
        self.hazards = hazards
        self.parPieces = parPieces
        self.targetTime = targetTime
        self.solution = solution
    }

    public var rules: WorldRules { world.rules }

    public var objectiveOrder: [Gate] { checkpoints + [goal] }

    public func deck(countPerType: Int = 4) -> Deck {
        Deck(entries: allowedPieces.prefix(Deck.slotLimit).map {
            DeckEntry(piece: $0, count: countPerType)
        })
    }
}

public struct ObjectiveState: Sendable, Hashable, Codable {
    public var nextCheckpoint: Int
    public var coresCollected: [Bool]
    public var reachedGoal: Bool

    public init(checkpointCount: Int, coreCount: Int) {
        self.nextCheckpoint = 0
        self.coresCollected = Array(repeating: false, count: coreCount)
        self.reachedGoal = false
    }

    public var collectedCount: Int { coresCollected.filter { $0 }.count }
    public var allCoresCollected: Bool { coresCollected.allSatisfy { $0 } }
}

public struct LevelResult: Sendable, Hashable, Codable {
    public var completed: Bool
    public var piecesUsed: Int
    public var elapsed: Fixed
    public var coresCollected: Int
    public var coreTotal: Int
    public var crashReason: CrashReason?

    public func stars(for level: Level) -> Int {
        guard completed else { return 0 }
        var earned = 1
        if piecesUsed <= level.parPieces { earned += 1 }
        if coresCollected == coreTotal && elapsed <= level.targetTime { earned += 1 }
        return earned
    }
}
