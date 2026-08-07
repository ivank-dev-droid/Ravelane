public struct CarID: Sendable, Hashable, Codable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

public struct CarSpec: Sendable, Hashable, Codable, Identifiable {
    public var id: CarID
    public var name: String
    public var mass: Fixed
    public var grip: Fixed
    public var acceleration: Fixed
    public var topSpeed: Fixed
    public var downforce: Fixed
    public var widthTolerance: Fixed
    public var maxIntegrity: Fixed

    public init(
        id: CarID,
        name: String,
        mass: Fixed,
        grip: Fixed,
        acceleration: Fixed,
        topSpeed: Fixed,
        downforce: Fixed,
        widthTolerance: Fixed,
        maxIntegrity: Fixed = Fixed(100)
    ) {
        self.id = id
        self.name = name
        self.mass = mass
        self.grip = grip
        self.acceleration = acceleration
        self.topSpeed = topSpeed
        self.downforce = downforce
        self.widthTolerance = widthTolerance
        self.maxIntegrity = maxIntegrity
    }

    public var absoluteTopSpeed: Fixed { Physics.baseTopSpeed * topSpeed }
    public var absoluteAcceleration: Fixed { Physics.baseAcceleration * acceleration }
}

public enum CarCatalog {
    public static let all: [CarSpec] = [
        CarSpec(id: CarID("fettle"), name: "Fettle",
                mass: Fixed(1), grip: Fixed(1), acceleration: Fixed(1),
                topSpeed: Fixed(1), downforce: .zero, widthTolerance: Fixed(1)),
        CarSpec(id: CarID("shim"), name: "Shim",
                mass: Fixed(6, over: 10), grip: Fixed(85, over: 100), acceleration: Fixed(14, over: 10),
                topSpeed: Fixed(105, over: 100), downforce: .zero, widthTolerance: Fixed(9, over: 10)),
        CarSpec(id: CarID("ballast"), name: "Ballast",
                mass: Fixed(19, over: 10), grip: Fixed(13, over: 10), acceleration: Fixed(6, over: 10),
                topSpeed: Fixed(9, over: 10), downforce: Fixed(1, over: 10), widthTolerance: Fixed(13, over: 10)),
        CarSpec(id: CarID("kite"), name: "Kite",
                mass: Fixed(5, over: 10), grip: Fixed(7, over: 10), acceleration: Fixed(11, over: 10),
                topSpeed: Fixed(1), downforce: Fixed(-2, over: 10), widthTolerance: Fixed(9, over: 10)),
        CarSpec(id: CarID("anvil"), name: "Anvil",
                mass: Fixed(24, over: 10), grip: Fixed(115, over: 100), acceleration: Fixed(5, over: 10),
                topSpeed: Fixed(85, over: 100), downforce: Fixed(3, over: 10), widthTolerance: Fixed(15, over: 10),
                maxIntegrity: Fixed(140)),
        CarSpec(id: CarID("sliver"), name: "Sliver",
                mass: Fixed(7, over: 10), grip: Fixed(95, over: 100), acceleration: Fixed(12, over: 10),
                topSpeed: Fixed(13, over: 10), downforce: .zero, widthTolerance: Fixed(7, over: 10)),
        CarSpec(id: CarID("burr"), name: "Burr",
                mass: Fixed(11, over: 10), grip: Fixed(105, over: 100), acceleration: Fixed(1),
                topSpeed: Fixed(95, over: 100), downforce: Fixed(2, over: 10), widthTolerance: Fixed(11, over: 10)),
        CarSpec(id: CarID("tack"), name: "Tack",
                mass: Fixed(9, over: 10), grip: Fixed(11, over: 10), acceleration: Fixed(9, over: 10),
                topSpeed: Fixed(9, over: 10), downforce: .zero, widthTolerance: Fixed(12, over: 10)),
        CarSpec(id: CarID("cinder"), name: "Cinder",
                mass: Fixed(1), grip: Fixed(9, over: 10), acceleration: Fixed(16, over: 10),
                topSpeed: Fixed(115, over: 100), downforce: .zero, widthTolerance: Fixed(1)),
        CarSpec(id: CarID("loom"), name: "Loom",
                mass: Fixed(12, over: 10), grip: Fixed(1), acceleration: Fixed(8, over: 10),
                topSpeed: Fixed(8, over: 10), downforce: .zero, widthTolerance: Fixed(14, over: 10)),
        CarSpec(id: CarID("spindle"), name: "Spindle",
                mass: Fixed(8, over: 10), grip: Fixed(125, over: 100), acceleration: Fixed(1),
                topSpeed: Fixed(1), downforce: Fixed(15, over: 100), widthTolerance: Fixed(8, over: 10)),
        CarSpec(id: CarID("ravelane"), name: "Ravelane",
                mass: Fixed(1), grip: Fixed(1), acceleration: Fixed(1),
                topSpeed: Fixed(1), downforce: .zero, widthTolerance: Fixed(1))
    ]

    public static let starting = all[0]

    public static func spec(_ id: CarID) -> CarSpec? {
        all.first { $0.id == id }
    }
}

public struct WorldRules: Sendable, Hashable, Codable {
    public var name: String
    public var gravity: Fixed
    public var gripScale: Fixed
    public var startSpeed: Fixed

    public init(name: String, gravity: Fixed, gripScale: Fixed = .one, startSpeed: Fixed = Fixed(9)) {
        self.name = name
        self.gravity = gravity
        self.gripScale = gripScale
        self.startSpeed = startSpeed
    }

    public static let foundry = WorldRules(name: "Foundry", gravity: Fixed(981, over: 100))
    public static let updraft = WorldRules(name: "Updraft", gravity: Fixed(36, over: 10),
                                           gripScale: Fixed(27, over: 10))
    public static let overdrive = WorldRules(name: "Overdrive", gravity: Fixed(981, over: 100),
                                             gripScale: Fixed(11, over: 10), startSpeed: Fixed(15))
}
