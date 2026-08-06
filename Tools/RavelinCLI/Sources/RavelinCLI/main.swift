import Foundation
import RavelinCore

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
    print("usage: RavelinCLI <catalog|render|verify> [--piece <id>] [--out <dir>]")
}
