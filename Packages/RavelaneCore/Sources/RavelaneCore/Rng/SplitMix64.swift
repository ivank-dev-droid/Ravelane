public struct SplitMix64: Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func next(upperBound: UInt64) -> UInt64 {
        precondition(upperBound > 0)
        let threshold = (0 &- upperBound) % upperBound
        while true {
            let candidate = next()
            if candidate >= threshold { return candidate % upperBound }
        }
    }

    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next(upperBound: span))
    }

    public mutating func nextUnitFixed() -> Fixed {
        Fixed(raw: Int64(next() >> 33))
    }

    public mutating func nextBool(chanceOutOf denominator: Int) -> Bool {
        precondition(denominator > 0)
        return next(upperBound: UInt64(denominator)) == 0
    }
}

public enum StreamPurpose: UInt64, Sendable, CaseIterable {
    case draw = 1
    case hazardPhase = 2
    case levelGeneration = 3
    case cosmetic = 4
    case endlessObjectives = 5
}

public func derivedStream(seed: UInt64, purpose: StreamPurpose, index: UInt64) -> SplitMix64 {
    var mixer = SplitMix64(seed: seed ^ (purpose.rawValue &* 0x2545_F491_4F6C_DD1D))
    _ = mixer.next()
    return SplitMix64(seed: mixer.next() ^ (index &* 0x9E37_79B9_7F4A_7C15))
}
