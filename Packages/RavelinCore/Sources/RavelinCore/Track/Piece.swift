public struct PieceID: Sendable, Hashable, Codable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

public enum PieceClass: String, Sendable, Codable, Hashable, CaseIterable {
    case straight
    case turn
    case vertical
    case roll
    case air
    case surface
    case structural
}

public enum PieceTag: String, Sendable, Codable, Hashable, CaseIterable {
    case runwayBuy
    case navigation
    case speedGain
    case speedLoss
    case forgiving
    case fragile
    case worldLocked
    case branching
    case utility
}

public enum TrackSurface: String, Sendable, Codable, Hashable, CaseIterable {
    case normal
    case boost
    case brake
    case rumble
    case magnet
    case scaffold

    public var speedDeltaPerSecond: Fixed {
        switch self {
        case .boost: return Fixed(14)
        case .brake: return Fixed(-18)
        case .rumble: return Fixed(-7)
        default: return .zero
        }
    }

    public var gripMultiplier: Fixed {
        switch self {
        case .rumble: return Fixed(7, over: 10)
        case .magnet: return Fixed(3)
        case .scaffold: return Fixed(9, over: 10)
        default: return .one
        }
    }
}

public enum YawAxis: String, Sendable, Hashable, Codable {
    case body
    case world
}

public struct PieceSegment: Sendable, Hashable, Codable {
    public var length: Fixed
    public var yaw: Fixed
    public var pitch: Fixed
    public var roll: Fixed
    public var yawAxis: YawAxis

    public init(
        length: Fixed,
        yaw: Fixed = .zero,
        pitch: Fixed = .zero,
        roll: Fixed = .zero,
        yawAxis: YawAxis = .world
    ) {
        self.length = length
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
        self.yawAxis = yawAxis
    }

    public static func straight(_ length: Fixed) -> PieceSegment {
        PieceSegment(length: length)
    }

    public var curvature: Fixed {
        if length.raw == 0 { return .zero }
        let bend = (yaw * yaw + pitch * pitch).squareRoot
        return bend / length
    }

    public var lateralCurvature: Fixed {
        length.raw == 0 ? .zero : yaw / length
    }

    public var verticalCurvature: Fixed {
        length.raw == 0 ? .zero : pitch / length
    }

    public var rollRate: Fixed {
        length.raw == 0 ? .zero : roll / length
    }
}

public struct Piece: Sendable, Hashable, Codable, Identifiable {
    public var id: PieceID
    public var name: String
    public var pieceClass: PieceClass
    public var segments: [PieceSegment]
    public var width: Fixed
    public var cost: Int
    public var surface: TrackSurface
    public var tags: [PieceTag]
    public var gapLength: Fixed
    public var landingTolerance: Fixed
    public var branches: Bool

    public init(
        id: PieceID,
        name: String,
        pieceClass: PieceClass,
        segments: [PieceSegment],
        width: Fixed = Fixed(8),
        cost: Int,
        surface: TrackSurface = .normal,
        tags: [PieceTag] = [],
        gapLength: Fixed = .zero,
        landingTolerance: Fixed = .zero,
        branches: Bool = false
    ) {
        self.id = id
        self.name = name
        self.pieceClass = pieceClass
        self.segments = segments
        self.width = width
        self.cost = cost
        self.surface = surface
        self.tags = tags
        self.gapLength = gapLength
        self.landingTolerance = landingTolerance
        self.branches = branches
    }

    public var length: Fixed {
        segments.reduce(Fixed.zero) { $0 + $1.length }
    }

    public var totalYaw: Fixed { segments.reduce(Fixed.zero) { $0 + $1.yaw } }
    public var totalPitch: Fixed { segments.reduce(Fixed.zero) { $0 + $1.pitch } }
    public var totalRoll: Fixed { segments.reduce(Fixed.zero) { $0 + $1.roll } }

    public var isGap: Bool { gapLength.raw > 0 }

    public func mirrored(id: PieceID, name: String) -> Piece {
        var copy = self
        copy.id = id
        copy.name = name
        copy.segments = segments.map {
            PieceSegment(length: $0.length, yaw: -$0.yaw, pitch: $0.pitch, roll: -$0.roll)
        }
        return copy
    }
}

public func degrees(_ value: Int) -> Fixed {
    Fixed(raw: (Trig.pi.raw / 180) * Int64(value))
}

public func degrees(_ numerator: Int, over denominator: Int) -> Fixed {
    Fixed(raw: (Trig.pi.raw * Int64(numerator)) / (180 * Int64(denominator)))
}
