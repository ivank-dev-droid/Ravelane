public enum Volume: Sendable, Hashable, Codable {
    case box(center: Vec3, halfExtents: Vec3)
    case sphere(center: Vec3, radius: Fixed)
    case capsule(from: Vec3, to: Vec3, radius: Fixed)

    public func contains(_ point: Vec3) -> Bool {
        switch self {
        case .box(let center, let halfExtents):
            let delta = point - center
            return delta.x.magnitude <= halfExtents.x
                && delta.y.magnitude <= halfExtents.y
                && delta.z.magnitude <= halfExtents.z
        case .sphere(let center, let radius):
            return (point - center).lengthSquared <= radius * radius
        case .capsule(let from, let to, let radius):
            let squared = SegmentDistance.closestSquared(from, to, point, point)
            return squared <= radius * radius
        }
    }

    public func distanceSquared(to point: Vec3) -> Fixed {
        switch self {
        case .box(let center, let halfExtents):
            let delta = point - center
            let outside = Vec3(
                Swift.max(.zero, delta.x.magnitude - halfExtents.x),
                Swift.max(.zero, delta.y.magnitude - halfExtents.y),
                Swift.max(.zero, delta.z.magnitude - halfExtents.z)
            )
            return outside.lengthSquared
        case .sphere(let center, let radius):
            let distance = (point - center).length - radius
            return distance <= .zero ? .zero : distance * distance
        case .capsule(let from, let to, let radius):
            let squared = SegmentDistance.closestSquared(from, to, point, point)
            let distance = squared.squareRoot - radius
            return distance <= .zero ? .zero : distance * distance
        }
    }

    public func intersects(_ capsule: Capsule) -> Bool {
        switch self {
        case .capsule(let from, let to, let radius):
            let combined = radius + capsule.radius
            let squared = SegmentDistance.closestSquared(from, to, capsule.start, capsule.end)
            return squared < combined * combined
        default:
            let samples = 5
            for index in 0...samples {
                let t = Fixed(index, over: samples)
                let point = capsule.start.lerp(to: capsule.end, t)
                if distanceSquared(to: point) < capsule.radius * capsule.radius { return true }
            }
            return false
        }
    }

    public var centre: Vec3 {
        switch self {
        case .box(let center, _): return center
        case .sphere(let center, _): return center
        case .capsule(let from, let to, _): return (from + to) * Fixed(1, over: 2)
        }
    }
}

public struct Gate: Sendable, Hashable, Codable {
    public var position: Vec3
    public var normal: Vec3
    public var radius: Fixed

    public init(position: Vec3, normal: Vec3 = .unitZ, radius: Fixed = Fixed(9)) {
        self.position = position
        self.normal = normal.normalized
        self.radius = radius
    }

    public func signedDistance(_ point: Vec3) -> Fixed {
        (point - position).dot(normal)
    }

    public func isCrossed(from previous: Vec3, to current: Vec3) -> Bool {
        let squared = SegmentDistance.closestSquared(previous, current, position, position)
        return squared <= radius * radius
    }
}

public struct Core: Sendable, Hashable, Codable {
    public var position: Vec3
    public var radius: Fixed
    public var value: Int

    public static let pickupRadius = Fixed(11)
    public static let hoverHeight = Fixed(3)

    public init(position: Vec3, radius: Fixed = Core.pickupRadius, value: Int = 18) {
        self.position = position
        self.radius = radius
        self.value = value
    }

    public func isCollected(from previous: Vec3, to current: Vec3) -> Bool {
        let flatPrevious = Vec3(previous.x, .zero, previous.z)
        let flatCurrent = Vec3(current.x, .zero, current.z)
        let flatCore = Vec3(position.x, .zero, position.z)
        let sideways = SegmentDistance.closestSquared(flatPrevious, flatCurrent, flatCore, flatCore)
        guard sideways <= radius * radius else { return false }

        let lowest = Swift.min(previous.y, current.y)
        let highest = Swift.max(previous.y, current.y)
        let band = radius + Core.hoverHeight
        return position.y >= lowest - band && position.y <= highest + band
    }
}

public struct Hazard: Sendable, Hashable, Codable {
    public enum Motion: Sendable, Hashable, Codable {
        case still
        case pulse(period: Fixed, dutyCycle: Fixed, phase: Fixed)
        case drift(to: Vec3, period: Fixed, phase: Fixed)
    }

    public var volume: Volume
    public var motion: Motion

    public init(volume: Volume, motion: Motion = .still) {
        self.volume = volume
        self.motion = motion
    }

    public func isActive(at time: Fixed) -> Bool {
        switch motion {
        case .still, .drift:
            return true
        case .pulse(let period, let dutyCycle, let phase):
            guard period.raw > 0 else { return true }
            let shifted = time + phase
            let cycles = (shifted / period).whole
            let position = shifted - Fixed(cycles) * period
            return position < period * dutyCycle
        }
    }

    public func volume(at time: Fixed) -> Volume {
        switch motion {
        case .drift(let target, let period, let phase):
            guard period.raw > 0 else { return volume }
            let shifted = time + phase
            let cycles = (shifted / period).whole
            let position = (shifted - Fixed(cycles) * period) / period
            let bounce = position < Fixed(1, over: 2)
                ? position * Fixed(2)
                : (.one - position) * Fixed(2)
            let origin = volume.centre
            let offset = (target - origin) * bounce
            return volume.translated(by: offset)
        default:
            return volume
        }
    }
}

extension Volume {
    public func translated(by offset: Vec3) -> Volume {
        switch self {
        case .box(let center, let halfExtents):
            return .box(center: center + offset, halfExtents: halfExtents)
        case .sphere(let center, let radius):
            return .sphere(center: center + offset, radius: radius)
        case .capsule(let from, let to, let radius):
            return .capsule(from: from + offset, to: to + offset, radius: radius)
        }
    }
}
