import Foundation
import RavelaneCore

let arguments = Array(CommandLine.arguments.dropFirst())

func value(for flag: String, default fallback: String) -> String {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
        return fallback
    }
    return arguments[index + 1]
}

func writeDocument(_ contents: String, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try? contents.write(to: url, atomically: true, encoding: .utf8)
    print("wrote \(path)")
}

func chain(from ids: [String]) -> TrackChain {
    var built = TrackChain(catalog: PieceCatalog.cache)
    for id in ids { built.append(PieceID(id)) }
    return built
}

func reportCatalog() {
    print("pieces: \(PieceCatalog.all.count)")
    let header = ["id", "class", "len", "yaw", "pitch", "roll", "cost", "width"]
    print(header.map { $0.padding(toLength: 20, withPad: " ", startingAt: 0) }.joined())
    for piece in PieceCatalog.all {
        guard let geometry = PieceCatalog.cache.geometry(piece.id) else { continue }
        let exit = geometry.exitTransform
        let heading = Trig.atan2(y: exit.forward.x, x: exit.forward.z)
        let row = [
            piece.id.rawValue,
            piece.pieceClass.rawValue,
            piece.length.description,
            heading.description,
            exit.position.y.description,
            piece.totalRoll.description,
            String(piece.cost),
            piece.width.description
        ]
        print(row.map { $0.padding(toLength: 20, withPad: " ", startingAt: 0) }.joined())
    }
}

func renderDemo(outputDirectory: String) {
    let demo = [
        "straight", "gentle_curve_l", "rise_shallow", "banked_curve_r",
        "long_run", "hairpin_l", "drop_shallow", "spiral_up",
        "straight", "sharp_curve_r", "corkscrew_l", "loop",
        "drop_steep", "chicane_lr", "booster_strip", "straight"
    ]
    let track = chain(from: demo)
    for plane in OrthoPlane.allCases {
        let svg = OrthoSVG(plane: plane, pixelsPerMetre: 2.5).render(track)
        writeDocument(svg, to: "\(outputDirectory)/demo-\(plane.rawValue).svg")
    }
    print("demo track: \(track.placed.count) pieces, \(track.totalLength.description) m")
    print("head: \(track.headFrame.position)")
}

func renderPiece(_ id: String, outputDirectory: String) {
    let track = chain(from: [id])
    for plane in OrthoPlane.allCases {
        let svg = OrthoSVG(plane: plane, pixelsPerMetre: 6).render(track)
        writeDocument(svg, to: "\(outputDirectory)/piece-\(id)-\(plane.rawValue).svg")
    }
}

func solveAll(outputPath: String) {
    var solutions: [(String, [String])] = []
    var failures: [String] = []

    for world in WorldID.allCases {
        for index in 0..<LevelForge.levelsPerWorld {
            let forged = LevelForge.forge(world: world, index: index)
            let level = forged.level

            var candidates: [[PieceID]] = []
            if !forged.route.isEmpty { candidates.append(forged.route) }

            var accepted: (route: [PieceID], time: Fixed, par: Int)?
            for route in candidates {
                var candidate = level
                candidate.solution = route
                candidate.parPieces = Swift.max(level.parPieces, route.count + 3)
                let played = LevelRunner.play(level: candidate)
                if played.result.completed {
                    accepted = (route, played.result.elapsed, candidate.parPieces)
                    break
                }
            }

            if let accepted {
                solutions.append((level.id.rawValue, accepted.route.map(\.rawValue)))
                print("OK   \(level.id)  pieces=\(accepted.route.count) par=\(accepted.par) time=\(accepted.time)")
            } else {
                let played = LevelRunner.play(level: level)
                failures.append("\(level.id) mode=\(played.session.car.mode) reason=\(String(describing: played.result.crashReason)) placed=\(played.session.placedCount)/\(level.solution.count) arc=\(played.session.car.arcLength)/\(played.session.chain.totalLength) speed=\(played.session.car.speed) integrity=\(played.session.car.integrity) t=\(played.session.car.elapsed) cp=\(played.session.objectives.nextCheckpoint)/\(level.checkpoints.count) goalDist=\(played.session.carPosition.distance(to: level.goal.position))")
                print("FAIL \(level.id)")
            }
        }
    }

    var body = "public enum LevelSolutions {\n    public static let table: [String: [String]] = "
    body += solutions.isEmpty ? "[:]\n}\n" : "[\n"
    if solutions.isEmpty { writeDocument(body, to: outputPath) }
    for (id, route) in solutions.sorted(by: { $0.0 < $1.0 }) {
        let items = route.map { "\"\($0)\"" }.joined(separator: ", ")
        body += "        \"\(id)\": [\(items)],\n"
    }
    if !solutions.isEmpty {
        body += "    ]\n}\n"
        writeDocument(body, to: outputPath)
    }

    print("solved \(solutions.count) / \(solutions.count + failures.count)")
    for failure in failures { print("  \(failure)") }
}

func sweep() {
    print("archetype    world        cleared  avgPieces  avgTime  avgStars")
    var worstPairs: [String] = []

    for archetype in Archetype.allCases {
        for world in WorldID.allCases {
            var cleared = 0
            var pieces = 0
            var time = Fixed.zero
            var stars = 0
            let levels = LevelCatalog.levels(in: world)

            for level in levels {
                var tuned = level
                tuned.allowedPieces = archetype.palette(from: level.allowedPieces, slots: Deck.slotLimit)
                guard let route = RouteWalker.solve(level: tuned, attempts: 30) else { continue }
                tuned.solution = route
                tuned.parPieces = Swift.max(level.parPieces, route.count + 3)
                let played = LevelRunner.play(level: tuned)
                if played.result.completed { cleared += 1 }
                pieces += played.result.piecesUsed
                time += played.result.elapsed
                stars += played.result.stars(for: level)
            }

            let count = Swift.max(1, levels.count)
            if cleared * 10 < levels.count * 7 {
                worstPairs.append("\(archetype.displayName)/\(world.rawValue) \(cleared)/\(levels.count)")
            }
            let row = [
                archetype.displayName.padding(toLength: 12, withPad: " ", startingAt: 0),
                world.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0),
                "\(cleared)/\(levels.count)".padding(toLength: 9, withPad: " ", startingAt: 0),
                "\(pieces / count)".padding(toLength: 11, withPad: " ", startingAt: 0),
                (time / Fixed(count)).description.padding(toLength: 9, withPad: " ", startingAt: 0),
                "\(Fixed(stars) / Fixed(count))"
            ].joined()
            print(row)
        }
    }

    print(worstPairs.isEmpty
          ? "every archetype clears at least 70 percent of every world"
          : "under target: \(worstPairs.joined(separator: ", "))")
}

func describeLevel(_ id: String) {
    guard let level = LevelCatalog.level(LevelID(id)) else { print("no such level"); return }
    print("\(level.id)  \(level.name)")
    print("  plinth      \(level.plinth.map(\.rawValue).joined(separator: ", "))")
    print("  solution    \(level.solution.count) pieces: \(level.solution.map(\.rawValue).joined(separator: ", "))")
    print("  par         \(level.parPieces)   material \(level.startingMaterial)   startSpeed \(level.startSpeed)")
    print("  checkpoints \(level.checkpoints.count)   cores \(level.cores.count)   blocks \(level.forbidden.count)")

    var chain = TrackChain(catalog: PieceCatalog.cache)
    chain.appendAll(level.plinth)
    let start = chain.headFrame
    let delta = level.goal.position - start.position
    let flat = Vec3(delta.x, .zero, delta.z)
    let heading = Trig.atan2(y: flat.x, x: flat.z)
    let carHeading = Trig.atan2(y: start.forward.x, x: start.forward.z)
    let turn = Trig.normalizedAngle(heading - carHeading)
    print("  goal        \(level.goal.position)  radius \(level.goal.radius)")
    print("  distance    \(delta.length) m   climb \(delta.y) m")
    print("  turn needed \(Int(turn.approximateDouble * 180 / 3.14159265)) degrees from the plinth")
    print("  deck        \(Archetype.core(from: level.allowedPieces).map(\.rawValue).joined(separator: ", "))")
}

func playAiming(_ count: Int) {
    print("level        result      reason            placed  arc/total        material  runway")
    for summary in LevelCatalog.summaries.prefix(count) {
        guard let level = LevelCatalog.level(summary.id) else { continue }
        var session = Session(deck: level.deck(), level: level)
        var steps = 0
        var starved = 0
        while session.isRunning && steps < 12000 {
            if session.clocks.runwaySeconds < Fixed(5) {
                let gates = level.objectiveOrder
                let target = gates[Swift.min(session.objectives.nextCheckpoint, gates.count - 1)]
                let best = session.placeableSlots.min { left, right in
                    func score(_ slot: Int) -> Fixed {
                        guard let id = session.hand[slot].piece,
                              let samples = session.chain.projectedSamples(afterAppending: id),
                              let tail = samples.last else { return Fixed(99999) }
                        let toTarget = target.position - tail.frame.position
                        let distance = toTarget.length
                        let heading = distance.raw == 0
                            ? Fixed.one
                            : toTarget.normalized.dot(tail.frame.forward)
                        return distance + (.one - heading) * Fixed(70)
                    }
                    return score(left) < score(right)
                }
                if let best { session.place(slot: best) } else { starved += 1 }
            }
            session.step()
            steps += 1
        }
        let done = session.objectives.reachedGoal ? "REACHED " : "failed  "
        let reason = session.car.crashReason.map { "\($0)" } ?? "ran dry"
        print("\(summary.id.rawValue.padding(toLength: 13, withPad: " ", startingAt: 0))\(done)    \(reason.padding(toLength: 18, withPad: " ", startingAt: 0))\(session.placedCount)      \(session.car.arcLength)/\(session.chain.totalLength)   \(session.material)     starved=\(starved)")
    }
}

func verifyLevels() {
    var bad = 0
    for level in LevelCatalog.all {
        if let problem = LevelRunner.verify(level: level) {
            print("FAIL \(level.id): \(problem)")
            bad += 1
        }
    }
    print(bad == 0 ? "OK \(LevelCatalog.all.count) levels" : "\(bad) level failures")
}

let command = arguments.first ?? "help"
let output = value(for: "--out", default: "out")

switch command {
case "catalog":
    reportCatalog()
case "render":
    let pieceID = value(for: "--piece", default: "")
    if pieceID.isEmpty {
        renderDemo(outputDirectory: output)
    } else {
        renderPiece(pieceID, outputDirectory: output)
    }
case "solve":
    solveAll(outputPath: value(for: "--out", default: "Packages/RavelaneCore/Sources/RavelaneCore/Level/LevelSolutions.swift"))
case "levels":
    verifyLevels()
case "play":
    playAiming(Int(value(for: "--count", default: "10")) ?? 10)
case "describe":
    describeLevel(value(for: "--level", default: "foundry_01"))
case "sweep":
    sweep()
case "verify":
    var failures = 0
    for piece in PieceCatalog.all {
        guard let geometry = PieceCatalog.cache.geometry(piece.id) else {
            print("FAIL \(piece.id): no geometry")
            failures += 1
            continue
        }
        let declared = piece.length
        let traced = geometry.localSamples.last?.arcLength ?? .zero
        let drift = (declared - traced).magnitude
        if drift > Fixed(1, over: 1000) {
            print("FAIL \(piece.id): arc length drift \(drift)")
            failures += 1
        }
    }
    print(failures == 0 ? "OK \(PieceCatalog.all.count) pieces" : "\(failures) failures")
default:
    print("usage: RavelaneCLI <catalog|render|verify> [--piece <id>] [--out <dir>]")
}
