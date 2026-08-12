public enum TuningTrack: String, Sendable, Hashable, Codable, CaseIterable {
    case grip
    case power
    case frame

    public var title: String {
        switch self {
        case .grip: return "Grip"
        case .power: return "Power"
        case .frame: return "Frame"
        }
    }

    public var detail: String {
        switch self {
        case .grip: return "more lateral bite through corners"
        case .power: return "quicker off the line, a little more top end"
        case .frame: return "tougher shell, slightly lighter"
        }
    }
}

public struct Tuning: Sendable, Hashable, Codable {
    public static let maxLevel = 3

    public var levels: [String: Int]

    public init(levels: [String: Int] = [:]) {
        self.levels = levels
    }

    public func level(_ track: TuningTrack) -> Int {
        Swift.min(Tuning.maxLevel, Swift.max(0, levels[track.rawValue] ?? 0))
    }

    public mutating func raise(_ track: TuningTrack) {
        levels[track.rawValue] = Swift.min(Tuning.maxLevel, level(track) + 1)
    }

    public var spent: Int {
        TuningTrack.allCases.reduce(0) { total, track in
            total + (1...Tuning.maxLevel).reduce(0) { sum, step in
                step <= level(track) ? sum + Tuning.cost(step) : sum
            }
        }
    }

    public static func cost(_ nextLevel: Int) -> Int {
        switch nextLevel {
        case 1: return 300
        case 2: return 700
        default: return 1400
        }
    }

    public func apply(to spec: CarSpec) -> CarSpec {
        var tuned = spec
        let grip = level(.grip)
        let power = level(.power)
        let frame = level(.frame)

        for _ in 0..<grip {
            tuned.grip *= Fixed(106, over: 100)
        }
        for _ in 0..<power {
            tuned.acceleration *= Fixed(108, over: 100)
            tuned.topSpeed *= Fixed(103, over: 100)
        }
        for _ in 0..<frame {
            tuned.maxIntegrity += Fixed(18)
            tuned.mass *= Fixed(97, over: 100)
        }
        return tuned
    }
}

public enum Shop {
    public static func price(for spec: CarSpec) -> Int {
        if spec.id == CarCatalog.starting.id { return 0 }
        let reach = spec.grip + spec.acceleration + spec.topSpeed + spec.widthTolerance
        let shell = spec.maxIntegrity / Fixed(100)
        let burden = spec.mass / Fixed(4)
        let rating = (reach + shell - burden).approximateDouble
        let raw = (rating - 3.4) * 900
        return round(Swift.max(200, raw))
    }

    public static func price(for part: Part) -> Int {
        let base: Int
        switch part.group {
        case .hand: return round(Double(450 + 220 * (part.effects.count - 1)))
        case .economy: base = 400
        case .physics: base = 350
        case .survival: base = 350
        }
        return round(Double(base + 180 * (part.effects.count - 1)))
    }

    private static func round(_ value: Double) -> Int {
        Swift.max(0, Int((value / 50).rounded()) * 50)
    }
}

public enum Payout {
    public static let firstClearBonus = 120

    public static func credits(
        summary: LevelSummary,
        result: LevelResult,
        stars: Int,
        firstClear: Bool
    ) -> Int {
        guard result.completed else { return 0 }
        let base = 50
        let starReward = 30 * Swift.max(0, Swift.min(3, stars))
        let coreReward = 20 * Swift.max(0, result.coresCollected)
        let depth = 3 * Swift.max(0, summary.number)
        return base + starReward + coreReward + depth + (firstClear ? firstClearBonus : 0)
    }
}
