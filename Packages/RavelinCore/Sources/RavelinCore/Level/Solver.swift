public enum SpeedEstimator {
    public struct Outcome: Sendable {
        public var exitSpeed: Fixed
        public var worstExcess: Fixed
        public var unloaded: Bool
        public var stalled: Bool
        public var steepestGrade: Fixed
    }

    public static let stallSpeed = Fixed(4)

    public static func traverse(
        samples: [RibbonSample],
        entrySpeed: Fixed,
        spec: CarSpec,
        world: WorldRules,
        surface: TrackSurface
    ) -> Outcome {
        var speed = entrySpeed
        var worstExcess = Fixed(-100000)
        var unloaded = false
        var stalled = false
        var steepestGrade = Fixed.zero

        for index in 1..<Swift.max(2, samples.count) {
            guard index < samples.count else { break }
            let sample = samples[index]
            let span = sample.arcLength - samples[index - 1].arcLength
            guard span.raw > 0, speed.raw > 0 else { continue }
            let dt = span / speed

            let grade = sample.tangent.y
            let fraction = speed / spec.absoluteTopSpeed
            let throttle = Swift.max(.zero, .one - fraction * fraction)
            let engine = spec.absoluteAcceleration * throttle
            let gravityAlong = -world.gravity * grade
            speed = Swift.max(
                Fixed(1, over: 10),
                speed + (engine + gravityAlong - Physics.rollingResistance
                         + surface.speedDeltaPerSecond) * dt
            )
            if speed < SpeedEstimator.stallSpeed { stalled = true }
            if grade.magnitude > steepestGrade { steepestGrade = grade.magnitude }

            let cosGrade = (Swift.max(.zero, .one - grade * grade)).squareRoot
            let speedSquared = speed * speed
            let normalLoad = world.gravity * cosGrade + speedSquared * sample.verticalCurvature
            if normalLoad <= .zero { unloaded = true; continue }

            let demand = (speedSquared * sample.lateralCurvature).magnitude
            let bankAssist = Physics.bankContribution(
                bank: sample.bank,
                lateralCurvature: sample.lateralCurvature,
                gravity: world.gravity
            )
            let grip = Physics.corneringGrip
                * (spec.grip * world.gripScale * surface.gripMultiplier * normalLoad + bankAssist)
            let excess = demand - grip
            if excess > worstExcess { worstExcess = excess }
        }

        return Outcome(
            exitSpeed: speed, worstExcess: worstExcess, unloaded: unloaded,
            stalled: stalled, steepestGrade: steepestGrade
        )
    }
}

public struct Solver {
    public struct Options: Sendable {
        public var beamWidth: Int
        public var maxPieces: Int
        public var slideTolerance: Fixed
        public var arrivalRadius: Fixed
        public var maximumGrade: Fixed

        public init(
            beamWidth: Int = 44,
            maxPieces: Int = 80,
            slideTolerance: Fixed = Fixed(-6),
            arrivalRadius: Fixed = Fixed(13),
            maximumGrade: Fixed = Fixed(55, over: 100)
        ) {
            self.beamWidth = beamWidth
            self.maxPieces = maxPieces
            self.slideTolerance = slideTolerance
            self.arrivalRadius = arrivalRadius
            self.maximumGrade = maximumGrade
        }
    }

    struct Node {
        var chain: TrackChain
        var pieces: [PieceID]
        var capsules: [[Capsule]]
        var bounds: [(centre: Vec3, radius: Fixed)]
        var speed: Fixed
        var objectiveIndex: Int
        var cost: Fixed
    }

    static func bound(_ capsules: [Capsule]) -> (centre: Vec3, radius: Fixed) {
        guard !capsules.isEmpty else { return (.zero, .zero) }
        var sum = Vec3.zero
        var count = 0
        for capsule in capsules {
            sum += capsule.start
            sum += capsule.end
            count += 2
        }
        let centre = sum / Fixed(count)
        var radius = Fixed.zero
        for capsule in capsules {
            radius = Swift.max(radius, centre.distance(to: capsule.start) + capsule.radius)
            radius = Swift.max(radius, centre.distance(to: capsule.end) + capsule.radius)
        }
        return (centre, radius)
    }

    public let level: Level
    public let catalog: PieceCatalogCache
    public let spec: CarSpec
    public let options: Options

    public init(
        level: Level,
        catalog: PieceCatalogCache = PieceCatalog.cache,
        spec: CarSpec = CarCatalog.starting,
        options: Options = Options()
    ) {
        self.level = level
        self.catalog = catalog
        self.spec = spec
        self.options = options
    }

    private var palette: [PieceID] {
        level.allowedPieces.isEmpty ? catalog.pieces.map(\.id) : level.allowedPieces
    }

    private func blocked(_ capsules: [Capsule]) -> Bool {
        for volume in level.forbidden {
            for capsule in capsules where volume.intersects(capsule) { return true }
        }
        return false
    }

    private func selfIntersects(_ node: Node, candidate: [Capsule], start: Fixed, end: Fixed) -> Bool {
        let window = ClearanceBuilder.selfContactWindow
        let candidateBound = Solver.bound(candidate)
        for index in 0..<node.chain.placed.count {
            guard index < node.capsules.count else { continue }
            let record = node.chain.placed[index]
            if record.endArcLength > start - window && record.startArcLength < end + window { continue }
            let existing = node.bounds[index]
            let separation = existing.centre.distance(to: candidateBound.centre)
            if separation > existing.radius + candidateBound.radius { continue }
            for a in node.capsules[index] {
                for b in candidate {
                    let combined = a.radius + b.radius
                    let squared = SegmentDistance.closestSquared(a.start, a.end, b.start, b.end)
                    if squared < combined * combined { return true }
                }
            }
        }
        return false
    }

    private func heuristic(_ node: Node) -> Fixed {
        let targets = level.objectiveOrder
        guard node.objectiveIndex < targets.count else { return .zero }
        let head = node.chain.headFrame
        let target = targets[node.objectiveIndex]
        let toTarget = target.position - head.position
        let distance = toTarget.length
        let heading = toTarget.normalized.dot(head.forward)
        let misalignment = (.one - heading) * Fixed(24)
        let remaining = Fixed(targets.count - node.objectiveIndex - 1) * Fixed(160)
        return distance + misalignment + remaining + Fixed(node.pieces.count) * Fixed(3)
    }

    public func solve() -> [PieceID]? {
        var plinth = TrackChain(catalog: catalog)
        plinth.appendAll(level.plinth)

        var plinthCapsules: [[Capsule]] = []
        var plinthBounds: [(centre: Vec3, radius: Fixed)] = []
        for index in 0..<plinth.placed.count {
            let capsules = ClearanceBuilder.capsules(for: plinth, pieceIndex: index)
            plinthCapsules.append(capsules)
            plinthBounds.append(Solver.bound(capsules))
        }

        var beam: [Node] = [Node(
            chain: plinth,
            pieces: [],
            capsules: plinthCapsules,
            bounds: plinthBounds,
            speed: level.startSpeed,
            objectiveIndex: 0,
            cost: .zero
        )]
        let targets = level.objectiveOrder
        let rules = level.rules

        for _ in 0..<options.maxPieces {
            var next: [Node] = []

            for node in beam {
                guard node.objectiveIndex < targets.count else { return node.pieces }

                for id in palette {
                    guard let piece = catalog.piece(id),
                          let geometry = catalog.geometry(id) else { continue }
                    let samples = geometry.samples(from: node.chain.headFrame)
                    let capsules = ClearanceBuilder.capsules(samples: samples, width: piece.width)
                    if blocked(capsules) { continue }

                    let start = node.chain.totalLength
                    let end = start + piece.length
                    if selfIntersects(node, candidate: capsules, start: start, end: end) { continue }

                    let travel = SpeedEstimator.traverse(
                        samples: samples,
                        entrySpeed: node.speed,
                        spec: spec,
                        world: rules,
                        surface: piece.surface
                    )
                    if travel.worstExcess > options.slideTolerance { continue }
                    if travel.stalled || travel.steepestGrade > options.maximumGrade { continue }

                    var child = node
                    child.chain.append(id, precomputed: samples)
                    child.pieces.append(id)
                    child.capsules.append(capsules)
                    child.bounds.append(Solver.bound(capsules))
                    child.speed = travel.exitSpeed

                    var advanced = child
                    var sampleIndex = 1
                    while sampleIndex < samples.count && advanced.objectiveIndex < targets.count {
                        let gate = targets[advanced.objectiveIndex]
                        if gate.isCrossed(
                            from: samples[sampleIndex - 1].position,
                            to: samples[sampleIndex].position
                        ) {
                            advanced.objectiveIndex += 1
                            sampleIndex = 1
                        } else {
                            sampleIndex += 1
                        }
                    }
                    advanced.cost = heuristic(advanced)
                    next.append(advanced)
                }
            }

            if next.isEmpty { return nil }
            if let done = next.first(where: { $0.objectiveIndex >= targets.count }) {
                return done.pieces
            }

            next.sort { $0.cost < $1.cost }
            beam = Array(next.prefix(options.beamWidth))
        }

        return nil
    }
}
