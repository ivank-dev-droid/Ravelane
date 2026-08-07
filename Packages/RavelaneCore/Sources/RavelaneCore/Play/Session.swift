public struct HandSlot: Sendable, Hashable, Codable {
    public var piece: PieceID?
    public var refillRemaining: Fixed
    public var reserved: Bool

    public init(piece: PieceID? = nil, refillRemaining: Fixed = .zero, reserved: Bool = false) {
        self.piece = piece
        self.refillRemaining = refillRemaining
        self.reserved = reserved
    }

    public var isFilled: Bool { piece != nil }
}

public enum PlacementRejection: Sendable, Hashable {
    case slotOutOfRange
    case slotEmpty
    case unknownPiece
    case notEnoughMaterial(needed: Int, have: Int)
    case wouldIntersect(pieceIndex: Int)
    case blockedByLevel
    case runOver
}

public enum DiscardRejection: Sendable, Hashable {
    case slotOutOfRange
    case slotEmpty
    case onCooldown(remaining: Fixed)
    case slotReserved
    case runOver
}

public enum PlayEvent: Sendable, Hashable {
    case placed(PieceID, cost: Int)
    case discarded(PieceID, refund: Int)
    case drew(PieceID, slot: Int)
    case materialEarned(Int, reason: MaterialReason)
    case handEmpty
    case runwayCritical(seconds: Fixed)
}

public enum MaterialReason: String, Sendable, Hashable, Codable {
    case cleanLanding
    case distance
    case checkpoint
    case core
}

public struct Session: Sendable {
    public static let baseDrawDelay = Fixed(14, over: 10)
    public static let baseDiscardCooldown = Fixed(3)
    public static let baseHandSize = 3
    public static let startingMaterial = 120
    public static let cleanLandingBonus = 12
    public static let materialPerMetre = Fixed(1, over: 6)
    public static let runwayWarning = Fixed(3)
    public static let checkpointBonus = 45

    public let catalog: PieceCatalogCache
    public let world: WorldRules
    public let deck: Deck
    public let effects: PartEffects
    public let baseSpec: CarSpec
    public let spec: CarSpec
    public let level: Level?

    public private(set) var chain: TrackChain
    public private(set) var car: CarState
    public private(set) var clearance: ClearanceIndex
    public private(set) var hand: [HandSlot]
    public private(set) var material: Int
    public private(set) var discardCooldown: Fixed
    public private(set) var placedCount: Int
    public private(set) var discardCount: Int
    public private(set) var log: [PlayEvent]
    public private(set) var simEvents: [SimEvent]
    public private(set) var objectives: ObjectiveState

    private var rng: SplitMix64
    private var distanceCredited: Fixed
    private var lastPosition: Vec3

    public init(
        catalog: PieceCatalogCache = PieceCatalog.cache,
        deck: Deck,
        spec: CarSpec = CarCatalog.starting,
        parts: [PartID] = [],
        world: WorldRules = .foundry,
        seed: UInt64 = 0x5241_5645_4C49_4E01,
        plinth: [PieceID] = [PieceID("long_run"), PieceID("stub")],
        material: Int = Session.startingMaterial,
        level: Level? = nil,
        extraHandSlots: Int = 0,
        drawDelayScale: Fixed = .one
    ) {
        var aggregated = PartCatalog.effects(parts)
        aggregated.extraHandSlots += extraHandSlots
        aggregated.drawDelayScale *= drawDelayScale
        self.catalog = catalog
        self.deck = deck
        self.world = level?.rules ?? world
        self.level = level
        self.effects = aggregated
        self.baseSpec = spec
        self.spec = aggregated.applied(to: spec)

        var built = TrackChain(catalog: catalog)
        built.appendAll(level?.plinth ?? plinth)
        self.chain = built
        self.clearance = ClearanceBuilder.index(for: built)

        let rules = level?.rules ?? world
        var startingCar = CarState.starting(spec: aggregated.applied(to: spec), world: rules)
        if let level { startingCar.speed = level.startSpeed }
        self.car = startingCar
        self.objectives = ObjectiveState(
            checkpointCount: level?.checkpoints.count ?? 0,
            coreCount: level?.cores.count ?? 0
        )
        self.lastPosition = built.sample(atArcLength: .zero)?.position ?? .zero
        self.material = level?.startingMaterial ?? material
        self.discardCooldown = .zero
        self.placedCount = 0
        self.discardCount = 0
        self.log = []
        self.simEvents = []
        self.distanceCredited = .zero
        self.rng = derivedStream(seed: seed, purpose: .draw, index: 0)

        let size = Session.baseHandSize + aggregated.extraHandSlots
        let reserveLast = aggregated.reserveSlot
        var slots: [HandSlot] = []
        slots.reserveCapacity(size)
        for index in 0..<size {
            slots.append(HandSlot(reserved: reserveLast && index == size - 1))
        }
        self.hand = slots
        fillHandCompletely()
    }

    public var handSize: Int { hand.count }
    public var isRunning: Bool { car.isRunning }

    public var clocks: Clocks {
        Clocks.measure(car: car, chain: chain, material: material)
    }

    public var carPosition: Vec3 {
        if car.mode == .airborne { return car.airPosition }
        guard let sample = chain.sample(atArcLength: car.arcLength) else { return lastPosition }
        return sample.position + sample.lateral * car.lateralOffset
    }

    public var outcome: LevelResult? {
        guard let level, !car.isRunning || objectives.reachedGoal else { return nil }
        return LevelResult(
            completed: objectives.reachedGoal,
            piecesUsed: placedCount,
            elapsed: car.elapsed,
            coresCollected: objectives.collectedCount,
            coreTotal: level.cores.count,
            crashReason: car.crashReason
        )
    }

    public func stars() -> Int {
        guard let level, let result = outcome else { return 0 }
        return result.stars(for: level)
    }

    private func forbiddenHit(_ capsules: [Capsule]) -> Bool {
        guard let level else { return false }
        for volume in level.forbidden {
            for capsule in capsules where volume.intersects(capsule) { return true }
        }
        for hazard in level.hazards where hazard.isActive(at: car.elapsed) {
            let volume = hazard.volume(at: car.elapsed)
            for capsule in capsules where volume.intersects(capsule) { return true }
        }
        return false
    }

    public func cost(of id: PieceID) -> Int {
        guard let piece = catalog.piece(id) else { return 0 }
        if piece.pieceClass == .straight {
            let scaled = Fixed(piece.cost) * effects.straightCostScale
            return Swift.max(0, scaled.whole)
        }
        return piece.cost
    }

    private mutating func fillHandCompletely() {
        for index in hand.indices where hand[index].piece == nil {
            if let drawn = drawPiece() {
                hand[index].piece = drawn
                hand[index].refillRemaining = .zero
                log.append(.drew(drawn, slot: index))
            }
        }
    }

    private mutating func drawPiece() -> PieceID? {
        let inHand = Set(hand.compactMap(\.piece))
        return deck.draw(using: &rng, preferringAbsent: inHand, sorter: effects.sorter)
    }

    public func canPlace(slot: Int) -> PlacementRejection? {
        guard car.isRunning else { return .runOver }
        guard hand.indices.contains(slot) else { return .slotOutOfRange }
        guard let id = hand[slot].piece else { return .slotEmpty }
        guard let piece = catalog.piece(id) else { return .unknownPiece }

        let price = cost(of: id)
        if price > material { return .notEnoughMaterial(needed: price, have: material) }

        guard let samples = chain.projectedSamples(afterAppending: id) else { return .unknownPiece }
        let candidateStart = chain.totalLength
        let candidateEnd = candidateStart + piece.length
        let candidateCapsules = ClearanceBuilder.capsules(samples: samples, width: piece.width)
        if forbiddenHit(candidateCapsules) { return .blockedByLevel }
        for capsule in candidateCapsules {
            if let hit = clearance.firstConflict(
                with: capsule,
                ignoringArcBetween: candidateStart,
                and: candidateEnd,
                window: ClearanceBuilder.selfContactWindow
            ) {
                return .wouldIntersect(pieceIndex: hit)
            }
        }
        return nil
    }

    @discardableResult
    public mutating func place(slot: Int) -> PlacementRejection? {
        if let rejection = canPlace(slot: slot) { return rejection }
        guard let id = hand[slot].piece else { return .slotEmpty }

        let price = cost(of: id)
        guard let record = chain.append(id) else { return .unknownPiece }

        material -= price
        placedCount += 1
        ClearanceBuilder.insert(chain: chain, pieceIndex: record.index, into: &clearance)

        hand[slot].piece = nil
        hand[slot].refillRemaining = Session.baseDrawDelay * effects.drawDelayScale
        log.append(.placed(id, cost: price))
        return nil
    }

    @discardableResult
    public mutating func forcePlace(_ id: PieceID) -> PlacementRejection? {
        guard car.isRunning else { return .runOver }
        guard let piece = catalog.piece(id) else { return .unknownPiece }
        let price = cost(of: id)
        if price > material { return .notEnoughMaterial(needed: price, have: material) }
        guard let samples = chain.projectedSamples(afterAppending: id) else { return .unknownPiece }

        let candidateStart = chain.totalLength
        let candidateEnd = candidateStart + piece.length
        let candidateCapsules = ClearanceBuilder.capsules(samples: samples, width: piece.width)
        if forbiddenHit(candidateCapsules) { return .blockedByLevel }
        for capsule in candidateCapsules {
            if let hit = clearance.firstConflict(
                with: capsule,
                ignoringArcBetween: candidateStart,
                and: candidateEnd,
                window: ClearanceBuilder.selfContactWindow
            ) {
                return .wouldIntersect(pieceIndex: hit)
            }
        }

        guard let record = chain.append(id) else { return .unknownPiece }
        material -= price
        placedCount += 1
        ClearanceBuilder.insert(chain: chain, pieceIndex: record.index, into: &clearance)
        log.append(.placed(id, cost: price))
        return nil
    }

    @discardableResult
    public mutating func discard(slot: Int) -> DiscardRejection? {
        guard car.isRunning else { return .runOver }
        guard hand.indices.contains(slot) else { return .slotOutOfRange }
        guard let id = hand[slot].piece else { return .slotEmpty }
        if hand[slot].reserved { return .slotReserved }
        if discardCooldown > .zero { return .onCooldown(remaining: discardCooldown) }

        let refundBase = Fixed(cost(of: id)) * effects.salvageFraction
        let refund = Swift.max(0, refundBase.whole)
        material += refund
        discardCount += 1
        discardCooldown = Session.baseDiscardCooldown * effects.discardCooldownScale

        hand[slot].piece = nil
        hand[slot].refillRemaining = Session.baseDrawDelay * effects.drawDelayScale
        log.append(.discarded(id, refund: refund))
        return nil
    }

    public mutating func step(dt: Fixed = Physics.timeStep) {
        guard car.isRunning else { return }

        let before = car.distanceTravelled
        let previousPosition = carPosition
        let result = Physics.step(car: car, chain: chain, spec: spec, world: world, dt: dt)
        car = result.car
        simEvents.append(contentsOf: result.events)
        let currentPosition = carPosition
        lastPosition = currentPosition
        trackObjectives(from: previousPosition, to: currentPosition)

        for event in result.events {
            if case .landed(_, let quality) = event, quality > Fixed(95, over: 100) {
                material += Session.cleanLandingBonus
                log.append(.materialEarned(Session.cleanLandingBonus, reason: .cleanLanding))
            }
        }

        distanceCredited += car.distanceTravelled - before
        let earned = (distanceCredited * Session.materialPerMetre).whole
        if earned > 0 {
            material += earned
            distanceCredited -= Fixed(earned) / Session.materialPerMetre
            log.append(.materialEarned(earned, reason: .distance))
        }

        if discardCooldown > .zero {
            discardCooldown = Swift.max(.zero, discardCooldown - dt)
        }

        var refilled = 0
        let refillBudget = effects.twinDraw ? 2 : 1
        for index in hand.indices where hand[index].piece == nil {
            if hand[index].refillRemaining > .zero {
                hand[index].refillRemaining = Swift.max(.zero, hand[index].refillRemaining - dt)
            }
            if hand[index].refillRemaining <= .zero && refilled < refillBudget {
                if let drawn = drawPiece() {
                    hand[index].piece = drawn
                    log.append(.drew(drawn, slot: index))
                    refilled += 1
                }
            }
        }

        let seconds = clocks.runwaySeconds
        if seconds < Session.runwayWarning && car.mode == .onTrack {
            log.append(.runwayCritical(seconds: seconds))
        }
        if hand.allSatisfy({ $0.piece == nil }) {
            log.append(.handEmpty)
        }
    }

    private mutating func trackObjectives(from previous: Vec3, to current: Vec3) {
        guard let level else { return }

        for (index, core) in level.cores.enumerated()
        where !objectives.coresCollected[index] && core.isCollected(from: previous, to: current) {
            objectives.coresCollected[index] = true
            material += core.value
            log.append(.materialEarned(core.value, reason: .core))
        }

        if objectives.nextCheckpoint < level.checkpoints.count {
            let gate = level.checkpoints[objectives.nextCheckpoint]
            if gate.isCrossed(from: previous, to: current) {
                objectives.nextCheckpoint += 1
                material += Session.checkpointBonus
                log.append(.materialEarned(Session.checkpointBonus, reason: .checkpoint))
            }
        } else if !objectives.reachedGoal && level.goal.isCrossed(from: previous, to: current) {
            objectives.reachedGoal = true
            car.mode = .finished
        }
    }

    public mutating func run(maxSteps: Int, policy: (inout Session) -> Void) -> Int {
        var steps = 0
        while car.isRunning && steps < maxSteps {
            policy(&self)
            step()
            steps += 1
        }
        return steps
    }

    public var placeableSlots: [Int] {
        hand.indices.filter { canPlace(slot: $0) == nil }
    }
}
