public enum CarMode: String, Sendable, Hashable, Codable {
    case onTrack
    case airborne
    case crashed
    case finished
}

public enum CrashReason: String, Sendable, Hashable, Codable {
    case ranOffTheEdge
    case ranOutOfTrack
    case fell
    case brokeUp
    case landedBadly
}

public struct CarState: Sendable, Hashable, Codable {
    public var mode: CarMode
    public var arcLength: Fixed
    public var speed: Fixed
    public var lateralOffset: Fixed
    public var lateralVelocity: Fixed
    public var integrity: Fixed
    public var airPosition: Vec3
    public var airVelocity: Vec3
    public var airTime: Fixed
    public var elapsed: Fixed
    public var distanceTravelled: Fixed
    public var crashReason: CrashReason?

    public init(
        mode: CarMode = .onTrack,
        arcLength: Fixed = .zero,
        speed: Fixed = .zero,
        lateralOffset: Fixed = .zero,
        lateralVelocity: Fixed = .zero,
        integrity: Fixed = Fixed(100),
        airPosition: Vec3 = .zero,
        airVelocity: Vec3 = .zero,
        airTime: Fixed = .zero,
        elapsed: Fixed = .zero,
        distanceTravelled: Fixed = .zero,
        crashReason: CrashReason? = nil
    ) {
        self.mode = mode
        self.arcLength = arcLength
        self.speed = speed
        self.lateralOffset = lateralOffset
        self.lateralVelocity = lateralVelocity
        self.integrity = integrity
        self.airPosition = airPosition
        self.airVelocity = airVelocity
        self.airTime = airTime
        self.elapsed = elapsed
        self.distanceTravelled = distanceTravelled
        self.crashReason = crashReason
    }

    public static func starting(spec: CarSpec, world: WorldRules) -> CarState {
        CarState(speed: world.startSpeed, integrity: spec.maxIntegrity)
    }

    public var isRunning: Bool { mode == .onTrack || mode == .airborne }
}

public enum SimEvent: Sendable, Hashable {
    case launched(arcLength: Fixed)
    case landed(arcLength: Fixed, quality: Fixed)
    case scraped(cost: Fixed)
    case slid(excess: Fixed)
    case surfaceEntered(TrackSurface)
    case reachedEnd
    case crashed(CrashReason)
}

public struct Clocks: Sendable, Hashable, Codable {
    public var runway: Fixed
    public var runwaySeconds: Fixed
    public var material: Int
    public var integrity: Fixed

    public init(runway: Fixed, runwaySeconds: Fixed, material: Int, integrity: Fixed) {
        self.runway = runway
        self.runwaySeconds = runwaySeconds
        self.material = material
        self.integrity = integrity
    }

    public static func measure(
        car: CarState,
        chain: TrackChain,
        material: Int
    ) -> Clocks {
        let remaining = Swift.max(.zero, chain.totalLength - car.arcLength)
        let seconds = car.speed.raw > 0 ? remaining / car.speed : Fixed(999)
        return Clocks(
            runway: remaining,
            runwaySeconds: seconds,
            material: material,
            integrity: car.integrity
        )
    }
}
