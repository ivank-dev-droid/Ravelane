import Foundation
import Observation
import RavelaneCore

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

    let deck: Deck

    init(level: Level, deck: Deck? = nil) {
        let chosen = deck ?? DeckStore.shared.deck(for: level.world, palette: level.allowedPieces)
        self.level = level
        self.deck = chosen
        self.session = SessionViewModel.makeSession(for: level, deck: chosen)
    }

    private static func makeSession(for level: Level, deck: Deck) -> Session {
        let settings = GameSettings.shared
        var eased = level
        eased.startingMaterial = Int(Double(level.startingMaterial) * settings.difficulty.materialScale)
        return Session(
            deck: deck,
            spec: settings.carSpec,
            parts: settings.partIDs,
            seed: 0x5241_5645,
            level: eased,
            extraHandSlots: settings.difficulty.extraHandSlots,
            drawDelayScale: settings.difficulty.drawDelayScale,
            enforceSafePlacement: settings.difficulty != .exact
        )
    }

    struct Trace: Sendable {
        var distance: Double
        var speed: Double
        var runway: Double
        var integrity: Double
    }

    private(set) var trace: [Trace] = []
    private var traceTick = 0

    var clocks: Clocks { session.clocks }
    var hand: [HandSlot] { session.hand }
    var material: Int { session.material }
    var isRunning: Bool { session.isRunning }
    var outcome: LevelResult? { session.outcome }
    var carSpeed: Fixed { session.car.speed }
    var carPosition: Vec3 { session.carPosition }
    var placedCount: Int { session.placedCount }

    struct Bearing: Sendable {
        var distance: Double
        var yaw: Double
        var climb: Double
        var isGoal: Bool
    }

    var nextObjective: Gate? {
        let index = session.objectives.nextCheckpoint
        let gates = level.objectiveOrder
        guard index < gates.count else { return nil }
        return gates[index]
    }

    var bearing: Bearing? {
        guard let gate = nextObjective else { return nil }
        let frame = carFrame
        let delta = gate.position - frame.position
        let distance = delta.length.approximateDouble
        guard distance > 0.01 else { return nil }

        let forward = frame.forward
        let flatForward = Vec3(forward.x, .zero, forward.z).normalized
        let flatDelta = Vec3(delta.x, .zero, delta.z)
        let flatDistance = flatDelta.length
        let unit = flatDistance.raw > 0 ? flatDelta / flatDistance : flatForward

        let ahead = unit.dot(flatForward).approximateDouble
        let side = unit.dot(Vec3(flatForward.z, .zero, -flatForward.x)).approximateDouble
        let yaw = atan2(side, ahead)

        return Bearing(
            distance: distance,
            yaw: yaw,
            climb: delta.y.approximateDouble,
            isGoal: session.objectives.nextCheckpoint >= level.checkpoints.count
        )
    }

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
        session = SessionViewModel.makeSession(for: level, deck: deck)
        trace.removeAll()
        traceTick = 0
        trackRevision += 1
        lastRejection = nil
        accumulator = 0
        lastTimestamp = nil
        isPaused = false
    }

    func togglePause() { isPaused.toggle() }

    func setPaused(_ value: Bool) { isPaused = value }

    func place(slot: Int) {
        guard session.isRunning else { return }
        lastRejection = session.place(slot: slot)
        if lastRejection == nil {
            trackRevision += 1
            Feedback.shared.play(.place)
        } else {
            Feedback.shared.play(.reject)
        }
    }

    func discard(slot: Int) {
        guard session.isRunning else { return }
        if session.discard(slot: slot) == nil { Feedback.shared.play(.discard) }
    }

    func previewSamples(for id: PieceID) -> [RibbonSample] {
        session.chain.projectedSamples(afterAppending: id) ?? []
    }

    func bringsCloser(_ id: PieceID) -> Bool? {
        guard let gate = nextObjective else { return nil }
        guard let samples = session.chain.projectedSamples(afterAppending: id),
              let tail = samples.last else { return nil }
        let now = (gate.position - session.chain.headFrame.position).length
        let after = (gate.position - tail.frame.position).length
        return after < now
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

        let scale = GameSettings.shared.effectiveSpeed
        let delta = min(0.25, max(0, timestamp - previous)) * scale
        accumulator += delta
        let stepSeconds = 1.0 / stepsPerSecond
        var budget = 0
        let before = session.simEvents.count
        let objectivesBefore = session.objectives
        while accumulator >= stepSeconds && budget < 40 {
            session.step()
            accumulator -= stepSeconds
            budget += 1
        }
        announce(from: before, objectivesBefore: objectivesBefore)
        recordTrace()
    }

    private func recordTrace() {
        traceTick += 1
        guard traceTick % 6 == 0 else { return }
        trace.append(Trace(
            distance: session.car.distanceTravelled.approximateDouble,
            speed: session.car.speed.approximateDouble,
            runway: session.clocks.runwaySeconds.approximateDouble,
            integrity: session.car.integrity.approximateDouble
        ))
        if trace.count > 900 { trace.removeFirst(300) }
    }

    private func announce(from index: Int, objectivesBefore: ObjectiveState) {
        if session.objectives.collectedCount > objectivesBefore.collectedCount {
            Feedback.shared.play(.core)
        }
        if session.objectives.nextCheckpoint > objectivesBefore.nextCheckpoint {
            Feedback.shared.play(.checkpoint)
        }
        if session.objectives.reachedGoal && !objectivesBefore.reachedGoal {
            Feedback.shared.play(.win)
            return
        }
        guard index < session.simEvents.count else { return }
        for event in session.simEvents[index...] {
            switch event {
            case .landed: Feedback.shared.play(.land)
            case .crashed: Feedback.shared.play(.crash)
            default: break
            }
        }
    }
}
