import Foundation
import Observation

@MainActor
@Observable
final class GameSettings {
    static let shared = GameSettings()

    var soundEnabled: Bool { didSet { store.set(soundEnabled, forKey: Keys.sound) } }
    var hapticsEnabled: Bool { didSet { store.set(hapticsEnabled, forKey: Keys.haptics) } }
    var gameSpeed: Double { didSet { store.set(gameSpeed, forKey: Keys.speed) } }
    var assistMode: Bool { didSet { store.set(assistMode, forKey: Keys.assist) } }
    var showGhost: Bool { didSet { store.set(showGhost, forKey: Keys.ghost) } }
    var cameraPullback: Double { didSet { store.set(cameraPullback, forKey: Keys.camera) } }

    private let store = UserDefaults.standard

    private enum Keys {
        static let sound = "ravelin.sound"
        static let haptics = "ravelin.haptics"
        static let speed = "ravelin.speed"
        static let assist = "ravelin.assist"
        static let ghost = "ravelin.ghost"
        static let camera = "ravelin.camera"
    }

    static let speedChoices: [(label: String, value: Double)] = [
        ("Cautious", 0.45),
        ("Steady", 0.65),
        ("Brisk", 0.85),
        ("Full", 1.0)
    ]

    private init() {
        store.register(defaults: [
            Keys.sound: true,
            Keys.haptics: true,
            Keys.speed: 0.55,
            Keys.assist: false,
            Keys.ghost: true,
            Keys.camera: 1.0
        ])
        soundEnabled = store.bool(forKey: Keys.sound)
        hapticsEnabled = store.bool(forKey: Keys.haptics)
        gameSpeed = store.double(forKey: Keys.speed)
        assistMode = store.bool(forKey: Keys.assist)
        showGhost = store.bool(forKey: Keys.ghost)
        cameraPullback = store.double(forKey: Keys.camera)
    }

    var effectiveSpeed: Double {
        assistMode ? gameSpeed * 0.7 : gameSpeed
    }

    var speedLabel: String {
        GameSettings.speedChoices
            .min { abs($0.value - gameSpeed) < abs($1.value - gameSpeed) }?
            .label ?? "Custom"
    }

    func reset() {
        soundEnabled = true
        hapticsEnabled = true
        gameSpeed = 0.55
        assistMode = false
        showGhost = true
        cameraPullback = 1.0
    }
}
