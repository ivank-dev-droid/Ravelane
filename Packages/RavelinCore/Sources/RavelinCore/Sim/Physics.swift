public enum Physics {
    public static let timeStep = Fixed(1, over: 120)
    public static let baseAcceleration = Fixed(6)
    public static let baseTopSpeed = Fixed(62)
    public static let corneringGrip = Fixed(6)
    public static let rollingResistance = Fixed(4, over: 10)
    public static let lateralRecovery = Fixed(4)
    public static let scrapeFraction = Fixed(78, over: 100)
    public static let scrapeCostPerSecond = Fixed(14)
    public static let landingRadius = Fixed(3)
    public static let landingSearchAhead = Fixed(260)
    public static let landingSearchStride = Fixed(2)
    public static let maximumAirTime = Fixed(12)
    public static let fallLimit = Fixed(400)
    public static let badLandingCost = Fixed(35)
    public static let groundedGrace = Fixed(1, over: 2)
    public static let stallTimeout = Fixed(4)
    public static let stallSpeed = Fixed(1, over: 2)

    public struct StepResult: Sendable {
        public var car: CarState
        public var events: [SimEvent]
    }

    public static func step(
        car input: CarState,
        chain: TrackChain,
        spec: CarSpec,
        world: WorldRules,
        dt: Fixed = timeStep
    ) -> StepResult {
        var car = input
        var events: [SimEvent] = []
        guard car.isRunning else { return StepResult(car: car, events: events) }

        car.elapsed += dt

        switch car.mode {
        case .onTrack:
            stepOnTrack(&car, &events, chain: chain, spec: spec, world: world, dt: dt)
        case .airborne:
            stepAirborne(&car, &events, chain: chain, spec: spec, world: world, dt: dt)
        default:
            break
        }

        if car.integrity <= .zero && car.isRunning {
            car.mode = .crashed
            car.crashReason = .brokeUp
            events.append(.crashed(.brokeUp))
        }

        return StepResult(car: car, events: events)
    }

    static func stepOnTrack(
        _ car: inout CarState,
        _ events: inout [SimEvent],
        chain: TrackChain,
        spec: CarSpec,
        world: WorldRules,
        dt: Fixed
    ) {
        guard let sample = chain.sample(atArcLength: car.arcLength) else {
            car.mode = .crashed
            car.crashReason = .ranOutOfTrack
            events.append(.crashed(.ranOutOfTrack))
            return
        }

        let surface = chain.surface(atArcLength: car.arcLength)
        let grade = sample.tangent.y
        let speed = car.speed

        let speedFraction = speed / spec.absoluteTopSpeed
        let throttle = Swift.max(.zero, .one - speedFraction * speedFraction)
        let engine = spec.absoluteAcceleration * throttle
        let gravityAlong = -world.gravity * grade
        let rolling = speed.raw > 0 ? -rollingResistance : .zero
        let surfaceDelta = surface.speedDeltaPerSecond

        car.speed = Swift.max(.zero, speed + (engine + gravityAlong + rolling + surfaceDelta) * dt)

        let cosGrade = (Swift.max(.zero, .one - grade * grade)).squareRoot
        let speedSquared = car.speed * car.speed
        var normalLoad = world.gravity * cosGrade + speedSquared * sample.verticalCurvature
        normalLoad += spec.downforce * speedSquared / Fixed(400)

        if car.groundedGrace > .zero {
            car.groundedGrace = Swift.max(.zero, car.groundedGrace - dt)
        } else if normalLoad <= .zero {
            launch(&car, &events, sample: sample, chain: chain)
            return
        }
        if normalLoad <= .zero { normalLoad = world.gravity * Fixed(1, over: 5) }

        let demand = speedSquared * sample.lateralCurvature
        let bankAssist = bankContribution(
            bank: sample.bank,
            lateralCurvature: sample.lateralCurvature,
            gravity: world.gravity
        )
        let gripLimit = corneringGrip
            * (spec.grip * world.gripScale * surface.gripMultiplier * normalLoad + bankAssist)

        let excess = demand.magnitude - gripLimit
        if excess > .zero {
            let outward = sample.lateralCurvature.raw > 0 ? Fixed(-1) : Fixed(1)
            car.lateralVelocity += excess * outward * dt
            events.append(.slid(excess: excess))
        } else {
            let decay = Swift.max(.zero, .one - lateralRecovery * dt)
            car.lateralVelocity = car.lateralVelocity * decay
            car.lateralOffset = car.lateralOffset * decay
        }

        car.lateralOffset += car.lateralVelocity * dt

        let halfWidth = chain.width(atArcLength: car.arcLength) / Fixed(2) * spec.widthTolerance
        let offset = car.lateralOffset.magnitude

        if offset > halfWidth {
            car.mode = .crashed
            car.crashReason = .ranOffTheEdge
            events.append(.crashed(.ranOffTheEdge))
            return
        }
        if offset > halfWidth * scrapeFraction {
            let cost = scrapeCostPerSecond * dt
            car.integrity -= cost
            events.append(.scraped(cost: cost))
        }

        if car.speed < stallSpeed {
            car.stallTime += dt
            if car.stallTime > stallTimeout {
                car.mode = .crashed
                car.crashReason = .stalled
                events.append(.crashed(.stalled))
                return
            }
        } else {
            car.stallTime = .zero
        }

        let advance = car.speed * dt
        car.arcLength += advance
        car.distanceTravelled += advance

        if car.arcLength >= chain.totalLength {
            car.arcLength = chain.totalLength
            car.mode = .finished
            events.append(.reachedEnd)
        }
    }

    static func bankContribution(
        bank: Fixed,
        lateralCurvature: Fixed,
        gravity: Fixed
    ) -> Fixed {
        if bank.raw == 0 || lateralCurvature.raw == 0 { return .zero }
        let magnitude = gravity * Trig.sin(bank.magnitude)
        return bank.sign == lateralCurvature.sign ? magnitude : -magnitude
    }

    static func launch(
        _ car: inout CarState,
        _ events: inout [SimEvent],
        sample: RibbonSample,
        chain: TrackChain
    ) {
        car.mode = .airborne
        car.airTime = .zero
        car.airPosition = sample.position + sample.lateral * car.lateralOffset
        car.airVelocity = sample.tangent * car.speed
        events.append(.launched(arcLength: car.arcLength))
    }

    static func stepAirborne(
        _ car: inout CarState,
        _ events: inout [SimEvent],
        chain: TrackChain,
        spec: CarSpec,
        world: WorldRules,
        dt: Fixed
    ) {
        car.airTime += dt
        car.airVelocity.y -= world.gravity * dt
        let previous = car.airPosition
        car.airPosition += car.airVelocity * dt
        car.distanceTravelled += car.airPosition.distance(to: previous)

        if car.airTime > maximumAirTime {
            car.mode = .crashed
            car.crashReason = .fell
            events.append(.crashed(.fell))
            return
        }

        if let landing = findLanding(car: car, chain: chain) {
            land(&car, &events, landing: landing, spec: spec)
        }
    }

    struct Landing: Sendable {
        var arcLength: Fixed
        var sample: RibbonSample
        var distance: Fixed
    }

    static func findLanding(car: CarState, chain: TrackChain) -> Landing? {
        var cursor = car.arcLength
        let limit = Swift.min(chain.totalLength, car.arcLength + landingSearchAhead)
        var best: Landing?

        while cursor <= limit {
            if let sample = chain.sample(atArcLength: cursor) {
                let distance = sample.position.distance(to: car.airPosition)
                if distance < landingRadius {
                    if best == nil || distance < best!.distance {
                        best = Landing(arcLength: cursor, sample: sample, distance: distance)
                    }
                }
            }
            cursor += landingSearchStride
        }
        return best
    }

    static func land(
        _ car: inout CarState,
        _ events: inout [SimEvent],
        landing: Landing,
        spec: CarSpec
    ) {
        let speed = car.airVelocity.length
        guard speed.raw > 0 else { return }

        let direction = car.airVelocity / speed
        let alignment = direction.dot(landing.sample.tangent)

        car.mode = .onTrack
        car.arcLength = landing.arcLength
        car.speed = Swift.max(.zero, speed * Swift.max(.zero, alignment))
        car.lateralVelocity = .zero
        car.airTime = .zero
        car.groundedGrace = groundedGrace

        if alignment < Fixed(88, over: 100) {
            let penalty = badLandingCost * (Fixed(88, over: 100) - alignment) * Fixed(8)
            car.integrity -= penalty
        }

        events.append(.landed(arcLength: landing.arcLength, quality: alignment))
    }
}
