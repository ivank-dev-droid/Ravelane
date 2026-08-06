public struct Capsule: Sendable, Hashable {
    public var start: Vec3
    public var end: Vec3
    public var radius: Fixed

    public init(start: Vec3, end: Vec3, radius: Fixed) {
        self.start = start
        self.end = end
        self.radius = radius
    }

    public var minimumCorner: Vec3 {
        Vec3(
            Swift.min(start.x, end.x) - radius,
            Swift.min(start.y, end.y) - radius,
            Swift.min(start.z, end.z) - radius
        )
    }

    public var maximumCorner: Vec3 {
        Vec3(
            Swift.max(start.x, end.x) + radius,
            Swift.max(start.y, end.y) + radius,
            Swift.max(start.z, end.z) + radius
        )
    }
}

public enum SegmentDistance {
    public static func closestSquared(
        _ p0: Vec3, _ p1: Vec3, _ q0: Vec3, _ q1: Vec3
    ) -> Fixed {
        let d1 = p1 - p0
        let d2 = q1 - q0
        let r = p0 - q0
        let a = d1.dot(d1)
        let e = d2.dot(d2)
        let f = d2.dot(r)

        var s = Fixed.zero
        var t = Fixed.zero

        if a.raw == 0 && e.raw == 0 {
            return r.dot(r)
        }
        if a.raw == 0 {
            t = (f / e).clamped(to: .zero ... .one)
        } else {
            let c = d1.dot(r)
            if e.raw == 0 {
                s = (-c / a).clamped(to: .zero ... .one)
            } else {
                let b = d1.dot(d2)
                let denominator = a * e - b * b
                if denominator.raw != 0 {
                    s = ((b * f - c * e) / denominator).clamped(to: .zero ... .one)
                }
                t = (b * s + f) / e
                if t < .zero {
                    t = .zero
                    s = (-c / a).clamped(to: .zero ... .one)
                } else if t > .one {
                    t = .one
                    s = ((b - c) / a).clamped(to: .zero ... .one)
                }
            }
        }

        let closestOnFirst = p0 + d1 * s
        let closestOnSecond = q0 + d2 * t
        let delta = closestOnFirst - closestOnSecond
        return delta.dot(delta)
    }
}

public struct ClearanceIndex: Sendable {
    public struct Entry: Sendable, Hashable {
        public let pieceIndex: Int
        public let capsule: Capsule
    }

    static let cellSize = Fixed(8)

    private var buckets: [Int64: [Int]] = [:]
    private var entries: [Entry] = []

    public init() {}

    public var capsuleCount: Int { entries.count }

    private static func cellKey(_ x: Int, _ y: Int, _ z: Int) -> Int64 {
        var hash: Int64 = 0x9E37_79B9
        hash = hash &* 31 &+ Int64(x)
        hash = hash &* 31 &+ Int64(y)
        hash = hash &* 31 &+ Int64(z)
        return hash
    }

    private static func cellIndex(_ value: Fixed) -> Int {
        let divided = value / cellSize
        return divided.raw >= 0
            ? Int(divided.raw >> 32)
            : Int((divided.raw - (Fixed.scale - 1)) >> 32)
    }

    private static func cellRange(_ capsule: Capsule) -> (Vec3, Vec3) {
        (capsule.minimumCorner, capsule.maximumCorner)
    }

    public mutating func insert(_ capsule: Capsule, pieceIndex: Int) {
        let entryIndex = entries.count
        entries.append(Entry(pieceIndex: pieceIndex, capsule: capsule))
        let (low, high) = ClearanceIndex.cellRange(capsule)
        let x0 = ClearanceIndex.cellIndex(low.x), x1 = ClearanceIndex.cellIndex(high.x)
        let y0 = ClearanceIndex.cellIndex(low.y), y1 = ClearanceIndex.cellIndex(high.y)
        let z0 = ClearanceIndex.cellIndex(low.z), z1 = ClearanceIndex.cellIndex(high.z)
        for x in x0...x1 {
            for y in y0...y1 {
                for z in z0...z1 {
                    buckets[ClearanceIndex.cellKey(x, y, z), default: []].append(entryIndex)
                }
            }
        }
    }

    public func firstConflict(
        with capsule: Capsule,
        ignoringPieceIndicesAtOrAbove threshold: Int
    ) -> Int? {
        let (low, high) = ClearanceIndex.cellRange(capsule)
        let x0 = ClearanceIndex.cellIndex(low.x), x1 = ClearanceIndex.cellIndex(high.x)
        let y0 = ClearanceIndex.cellIndex(low.y), y1 = ClearanceIndex.cellIndex(high.y)
        let z0 = ClearanceIndex.cellIndex(low.z), z1 = ClearanceIndex.cellIndex(high.z)

        var visited = Set<Int>()
        for x in x0...x1 {
            for y in y0...y1 {
                for z in z0...z1 {
                    guard let bucket = buckets[ClearanceIndex.cellKey(x, y, z)] else { continue }
                    for entryIndex in bucket {
                        if visited.contains(entryIndex) { continue }
                        visited.insert(entryIndex)
                        let entry = entries[entryIndex]
                        if entry.pieceIndex >= threshold { continue }
                        let combined = entry.capsule.radius + capsule.radius
                        let distanceSquared = SegmentDistance.closestSquared(
                            entry.capsule.start, entry.capsule.end,
                            capsule.start, capsule.end
                        )
                        if distanceSquared < combined * combined {
                            return entry.pieceIndex
                        }
                    }
                }
            }
        }
        return nil
    }
}

public struct ClearanceBuilder {
    public static let samplesPerCapsule = 6
    public static let verticalTolerance = Fixed(6)

    public static func capsules(
        for chain: TrackChain,
        pieceIndex: Int,
        margin: Fixed = Fixed(1, over: 2)
    ) -> [Capsule] {
        guard pieceIndex >= 0 && pieceIndex < chain.placed.count else { return [] }
        let record = chain.placed[pieceIndex]
        guard let piece = chain.catalog.piece(record.pieceID) else { return [] }
        let samples = chain.worldSamplesByPiece[pieceIndex]
        guard samples.count > 1 else { return [] }
        let radius = piece.width / Fixed(2) + margin

        var result: [Capsule] = []
        let stride = Swift.max(1, samples.count / samplesPerCapsule)
        var index = 0
        while index + stride < samples.count {
            result.append(Capsule(
                start: samples[index].frame.position,
                end: samples[index + stride].frame.position,
                radius: radius
            ))
            index += stride
        }
        if index < samples.count - 1 {
            result.append(Capsule(
                start: samples[index].frame.position,
                end: samples[samples.count - 1].frame.position,
                radius: radius
            ))
        }
        return result
    }

    public static func index(for chain: TrackChain) -> ClearanceIndex {
        var index = ClearanceIndex()
        for pieceIndex in 0..<chain.placed.count {
            for capsule in capsules(for: chain, pieceIndex: pieceIndex) {
                index.insert(capsule, pieceIndex: pieceIndex)
            }
        }
        return index
    }
}
