import Foundation
import Observation
import RavelinCore

@MainActor
@Observable
final class SessionViewModel {
    private(set) var session: Session
    private(set) var level: Level
    private(set) var trackRevision: Int = 0
    private(set) var isPaused = false
    private(set) var lastRejection: PlacementRejection?

    private var accumulator: Double = 0
    private var lastTimestamp: Double?

    let stepsPerSecond: Double = 120

    init(level: Level) {
        self.level = level
        self.session = SessionViewModel.makeSession(for: level)
    }

    private static func makeSession(for level: Level) -> Session {
        Session(deck: level.deck(), seed: 0x5241_5645, level: level)
    }

    var clocks: Clocks { session.clocks }
    var hand: [HandSlot] { session.hand }
    var material: Int { session.material }
    var isRunning: Bool { session.isRunning }
    var outcome: LevelResult? { session.outcome }
    var carSpeed: Fixed { session.car.speed }
    var carPosition: Vec3 { session.carPosition }
    var placedCount: Int { session.placedCount }

    var carFrame: Transform3 {
        if session.car.mode == .airborne {
            return Transform3(position: session.car.airPosition, rotation: session.chain.headFrame.rotation)
        }
        guard let sample = session.chain.sample(atArcLength: session.car.arcLength) else {
            return session.chain.headFrame
        }
        return Transform3(position: session.carPosition, rotation: sample.frame.rotation)
    }

    func restart() {
        session = SessionViewModel.makeSession(for: level)
        trackRevision += 1
        lastRejection = nil
        accumulator = 0
        lastTimestamp = nil
        isPaused = false
    }

    func togglePause() { isPaused.toggle() }

    func place(slot: Int) {
        guard session.isRunning else { return }
        lastRejection = session.place(slot: slot)
        if lastRejection == nil { trackRevision += 1 }
    }

    func discard(slot: Int) {
        guard session.isRunning else { return }
        session.discard(slot: slot)
    }

    func previewSamples(for id: PieceID) -> [RibbonSample] {
        session.chain.projectedSamples(afterAppending: id) ?? []
    }

    func previewIsSafe(_ id: PieceID) -> Bool {
        session.canPlace(slot: slotIndex(of: id) ?? -1) == nil
    }

    func slotIndex(of id: PieceID) -> Int? {
        session.hand.firstIndex { $0.piece == id }
    }

    func advance(to timestamp: Double) {
        guard !isPaused, session.isRunning else {
            lastTimestamp = timestamp
            return
        }
        defer { lastTimestamp = timestamp }
        guard let previous = lastTimestamp else { return }

        let delta = min(0.25, max(0, timestamp - previous))
        accumulator += delta
        let stepSeconds = 1.0 / stepsPerSecond
        var budget = 0
        while accumulator >= stepSeconds && budget < 40 {
            session.step()
            accumulator -= stepSeconds
            budget += 1
        }
    }
}
