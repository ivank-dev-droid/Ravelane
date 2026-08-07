import Foundation
import Observation
import RavelaneCore

enum Difficulty: String, CaseIterable, Identifiable {
    case relaxed
    case standard
    case exact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .standard: return "Standard"
        case .exact: return "Exact"
        }
    }

    var detail: String {
        switch self {
        case .relaxed: return "Extra grip, a wider car, a bigger purse and a sixth hand slot"
        case .standard: return "The tuned game"
        case .exact: return "No help at all, and Material is tight"
        }
    }

    var gripBonus: Fixed {
        switch self {
        case .relaxed: return Fixed(16, over: 10)
        case .standard: return Fixed(12, over: 10)
        case .exact: return .one
        }
    }

    var widthBonus: Fixed {
        switch self {
        case .relaxed: return Fixed(15, over: 10)
        case .standard: return Fixed(12, over: 10)
        case .exact: return .one
        }
    }

    var materialScale: Double {
        switch self {
        case .relaxed: return 1.9
        case .standard: return 1.4
        case .exact: return 1.0
        }
    }

    var extraHandSlots: Int {
        switch self {
        case .relaxed: return 2
        case .standard: return 1
        case .exact: return 0
        }
    }

    var drawDelayScale: Fixed {
        switch self {
        case .relaxed: return Fixed(5, over: 10)
        case .standard: return Fixed(7, over: 10)
        case .exact: return .one
        }
    }

    var defaultSpeed: Double {
        switch self {
        case .relaxed: return 0.35
        case .standard: return 0.5
        case .exact: return 0.75
        }
    }
}

@MainActor
@Observable
final class GameSettings {
    static let shared = GameSettings()

    var soundEnabled: Bool { didSet { store.set(soundEnabled, forKey: Keys.sound) } }
    var hapticsEnabled: Bool { didSet { store.set(hapticsEnabled, forKey: Keys.haptics) } }
    var gameSpeed: Double { didSet { store.set(gameSpeed, forKey: Keys.speed) } }
    var showGhost: Bool { didSet { store.set(showGhost, forKey: Keys.ghost) } }
    var cameraPullback: Double { didSet { store.set(cameraPullback, forKey: Keys.camera) } }
    var tutorialSeen: Bool { didSet { store.set(tutorialSeen, forKey: Keys.tutorial) } }

    var difficulty: Difficulty {
        didSet {
            store.set(difficulty.rawValue, forKey: Keys.difficulty)
            gameSpeed = difficulty.defaultSpeed
        }
    }

    var selectedCar: String { didSet { store.set(selectedCar, forKey: Keys.car) } }
    var selectedParts: [String] { didSet { store.set(selectedParts, forKey: Keys.parts) } }

    private let store = UserDefaults.standard

    private enum Keys {
        static let sound = "ravelane.sound"
        static let haptics = "ravelane.haptics"
        static let speed = "ravelane.speed"
        static let ghost = "ravelane.ghost"
        static let camera = "ravelane.camera"
        static let difficulty = "ravelane.difficulty"
        static let car = "ravelane.car"
        static let parts = "ravelane.parts"
        static let tutorial = "ravelane.tutorial"
    }

    static let speedChoices: [(label: String, value: Double)] = [
        ("Slowest", 0.3), ("Slow", 0.45), ("Steady", 0.6), ("Brisk", 0.8), ("Full", 1.0)
    ]

    private init() {
        store.register(defaults: [
            Keys.sound: true,
            Keys.haptics: true,
            Keys.speed: 0.35,
            Keys.ghost: true,
            Keys.camera: 1.0,
            Keys.difficulty: Difficulty.relaxed.rawValue,
            Keys.car: CarCatalog.starting.id.rawValue,
            Keys.parts: [String](),
            Keys.tutorial: false
        ])
        soundEnabled = store.bool(forKey: Keys.sound)
        hapticsEnabled = store.bool(forKey: Keys.haptics)
        gameSpeed = store.double(forKey: Keys.speed)
        showGhost = store.bool(forKey: Keys.ghost)
        cameraPullback = store.double(forKey: Keys.camera)
        difficulty = Difficulty(rawValue: store.string(forKey: Keys.difficulty) ?? "") ?? .relaxed
        selectedCar = store.string(forKey: Keys.car) ?? CarCatalog.starting.id.rawValue
        selectedParts = store.stringArray(forKey: Keys.parts) ?? []
        tutorialSeen = store.bool(forKey: Keys.tutorial)
    }

    var effectiveSpeed: Double { max(0.15, gameSpeed) }

    var carSpec: CarSpec {
        let base = CarCatalog.spec(CarID(selectedCar)) ?? CarCatalog.starting
        var tuned = base
        tuned.grip *= difficulty.gripBonus
        tuned.widthTolerance *= difficulty.widthBonus
        return tuned
    }

    var partIDs: [PartID] { selectedParts.map { PartID($0) } }

    func reset() {
        soundEnabled = true
        hapticsEnabled = true
        difficulty = .relaxed
        gameSpeed = Difficulty.relaxed.defaultSpeed
        showGhost = true
        cameraPullback = 1.0
        selectedCar = CarCatalog.starting.id.rawValue
        selectedParts = []
    }
}
