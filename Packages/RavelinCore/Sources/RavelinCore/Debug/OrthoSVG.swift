public enum OrthoPlane: String, Sendable, CaseIterable {
    case top
    case side
    case front

    public func project(_ point: Vec3) -> (Fixed, Fixed) {
        switch self {
        case .top: return (point.x, point.z)
        case .side: return (point.z, point.y)
        case .front: return (point.x, point.y)
        }
    }

    public var horizontalLabel: String {
        switch self {
        case .top: return "x"
        case .side: return "z"
        case .front: return "x"
        }
    }

    public var verticalLabel: String {
        switch self {
        case .top: return "z"
        case .side: return "y"
        case .front: return "y"
        }
    }
}

public struct OrthoSVG {
    public var plane: OrthoPlane
    public var pixelsPerMetre: Double
    public var padding: Double
    public var strokeWidth: Double

    public init(
        plane: OrthoPlane = .top,
        pixelsPerMetre: Double = 3.0,
        padding: Double = 40.0,
        strokeWidth: Double = 2.0
    ) {
        self.plane = plane
        self.pixelsPerMetre = pixelsPerMetre
        self.padding = padding
        self.strokeWidth = strokeWidth
    }

    static let classColours: [PieceClass: String] = [
        .straight: "#B44BFF",
        .turn: "#2E7BFF",
        .vertical: "#4BE3FF",
        .roll: "#FF6BE3",
        .air: "#FFC24B",
        .surface: "#7CFFB0",
        .structural: "#FFFFFF"
    ]

    public func render(_ chain: TrackChain, strideMetres: Fixed = Fixed(1)) -> String {
        var polylines: [(String, [(Double, Double)])] = []

        for record in chain.placed {
            guard let piece = chain.catalog.piece(record.pieceID) else { continue }
            let colour = OrthoSVG.classColours[piece.pieceClass] ?? "#FFFFFF"
            var points: [(Double, Double)] = []
            var cursor = record.startArcLength
            while cursor < record.endArcLength {
                if let sample = chain.sample(atArcLength: cursor, pieceIndex: record.index) {
                    let (h, v) = plane.project(sample.frame.position)
                    points.append((h.approximateDouble, v.approximateDouble))
                }
                cursor += strideMetres
            }
            if let sample = chain.sample(atArcLength: record.endArcLength, pieceIndex: record.index) {
                let (h, v) = plane.project(sample.frame.position)
                points.append((h.approximateDouble, v.approximateDouble))
            }
            if points.count > 1 { polylines.append((colour, points)) }
        }

        let allPoints = polylines.flatMap { $0.1 }
        guard !allPoints.isEmpty else { return OrthoSVG.emptyDocument }

        let minH = allPoints.map(\.0).min() ?? 0
        let maxH = allPoints.map(\.0).max() ?? 0
        let minV = allPoints.map(\.1).min() ?? 0
        let maxV = allPoints.map(\.1).max() ?? 0

        let width = (maxH - minH) * pixelsPerMetre + padding * 2
        let height = (maxV - minV) * pixelsPerMetre + padding * 2

        func screen(_ point: (Double, Double)) -> (Double, Double) {
            let x = (point.0 - minH) * pixelsPerMetre + padding
            let y = height - ((point.1 - minV) * pixelsPerMetre + padding)
            return (x, y)
        }

        var body = ""
        for (colour, points) in polylines {
            let coordinates = points.map { point -> String in
                let (x, y) = screen(point)
                return "\(OrthoSVG.format(x)),\(OrthoSVG.format(y))"
            }.joined(separator: " ")
            body += "<polyline points=\"\(coordinates)\" fill=\"none\" stroke=\"\(colour)\""
            body += " stroke-width=\"\(OrthoSVG.format(strokeWidth))\" stroke-linecap=\"round\"/>\n"
        }

        if let start = polylines.first?.1.first {
            let (x, y) = screen(start)
            body += "<circle cx=\"\(OrthoSVG.format(x))\" cy=\"\(OrthoSVG.format(y))\""
            body += " r=\"5\" fill=\"#7CFFB0\"/>\n"
        }
        if let end = polylines.last?.1.last {
            let (x, y) = screen(end)
            body += "<circle cx=\"\(OrthoSVG.format(x))\" cy=\"\(OrthoSVG.format(y))\""
            body += " r=\"5\" fill=\"#FF3D6E\"/>\n"
        }

        var document = "<svg xmlns=\"http://www.w3.org/2000/svg\""
        document += " width=\"\(OrthoSVG.format(width))\" height=\"\(OrthoSVG.format(height))\""
        document += " viewBox=\"0 0 \(OrthoSVG.format(width)) \(OrthoSVG.format(height))\">\n"
        document += "<rect width=\"100%\" height=\"100%\" fill=\"#0B0418\"/>\n"
        document += body
        document += "<text x=\"12\" y=\"22\" fill=\"#B44BFF\" font-family=\"monospace\""
        document += " font-size=\"14\">\(plane.rawValue) "
        document += "\(plane.horizontalLabel)/\(plane.verticalLabel) "
        document += "\(chain.placed.count) pieces "
        document += "\(chain.totalLength.description)m</text>\n"
        document += "</svg>\n"
        return document
    }

    static let emptyDocument = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1\" height=\"1\"/>\n"

    static func format(_ value: Double) -> String {
        let scaled = (value * 100).rounded() / 100
        if scaled == scaled.rounded() { return String(Int(scaled)) }
        return String(scaled)
    }
}
