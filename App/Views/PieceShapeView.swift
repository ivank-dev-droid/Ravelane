import SwiftUI
import RavelaneCore

struct PieceShapeView: View {
    let piece: Piece
    var tint: Color = Theme.cold
    var lineWidth: CGFloat = 2.6

    private enum Projection {
        case top
        case side
        case bank
    }

    private var projection: Projection {
        if piece.totalYaw.magnitude > .zero { return .top }
        if piece.totalPitch.magnitude > .zero { return .side }
        if piece.totalRoll.magnitude > .zero { return .bank }
        return .top
    }

    private var points: [CGPoint] {
        guard let geometry = PieceCatalog.cache.geometry(piece.id) else { return [] }
        let samples = geometry.localSamples
        let stride = Swift.max(1, samples.count / 40)
        var result: [CGPoint] = []
        var index = 0
        while index < samples.count {
            let p = samples[index].frame.position
            switch projection {
            case .top:
                result.append(CGPoint(x: p.x.approximateDouble, y: p.z.approximateDouble))
            case .side, .bank:
                result.append(CGPoint(x: p.z.approximateDouble, y: p.y.approximateDouble))
            }
            index += stride
        }
        if let last = samples.last {
            let p = last.frame.position
            switch projection {
            case .top:
                result.append(CGPoint(x: p.x.approximateDouble, y: p.z.approximateDouble))
            case .side, .bank:
                result.append(CGPoint(x: p.z.approximateDouble, y: p.y.approximateDouble))
            }
        }
        return result
    }

    var body: some View {
        Canvas { context, size in
            let raw = points
            guard raw.count > 1 else { return }

            let minX = raw.map(\.x).min()!, maxX = raw.map(\.x).max()!
            let minY = raw.map(\.y).min()!, maxY = raw.map(\.y).max()!
            let spanX = Swift.max(0.001, maxX - minX)
            let spanY = Swift.max(0.001, maxY - minY)
            let inset: CGFloat = 7
            let scale = Swift.min((size.width - inset * 2) / spanX,
                                  (size.height - inset * 2) / spanY)

            let offsetX = (size.width - spanX * scale) / 2
            let offsetY = (size.height - spanY * scale) / 2

            func place(_ p: CGPoint) -> CGPoint {
                CGPoint(x: offsetX + (p.x - minX) * scale,
                        y: size.height - (offsetY + (p.y - minY) * scale))
            }

            var path = Path()
            for (index, point) in raw.enumerated() {
                let screen = place(point)
                if index == 0 { path.move(to: screen) } else { path.addLine(to: screen) }
            }
            context.stroke(path, with: .color(tint),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            if piece.isGap, let tail = raw.last {
                let end = place(tail)
                var dashed = Path()
                dashed.move(to: end)
                dashed.addLine(to: CGPoint(x: Swift.min(size.width - 3, end.x + 16), y: end.y))
                context.stroke(dashed, with: .color(tint.opacity(0.5)),
                               style: StrokeStyle(lineWidth: lineWidth * 0.7, dash: [3, 3]))
            }

            if let head = raw.first {
                let start = place(head)
                context.fill(
                    Path(ellipseIn: CGRect(x: start.x - 3, y: start.y - 3, width: 6, height: 6)),
                    with: .color(Theme.dim)
                )
            }

            if raw.count >= 2 {
                let tip = place(raw[raw.count - 1])
                let before = place(raw[raw.count - 2])
                let dx = tip.x - before.x, dy = tip.y - before.y
                let length = Swift.max(0.001, sqrt(dx * dx + dy * dy))
                let ux = dx / length, uy = dy / length
                let wing: CGFloat = 5
                var arrow = Path()
                arrow.move(to: tip)
                arrow.addLine(to: CGPoint(x: tip.x - ux * wing - uy * wing * 0.6,
                                          y: tip.y - uy * wing + ux * wing * 0.6))
                arrow.move(to: tip)
                arrow.addLine(to: CGPoint(x: tip.x - ux * wing + uy * wing * 0.6,
                                          y: tip.y - uy * wing - ux * wing * 0.6))
                context.stroke(arrow, with: .color(tint),
                               style: StrokeStyle(lineWidth: lineWidth * 0.8, lineCap: .round))
            }

            if projection == .bank {
                let angle = piece.totalRoll.approximateDouble
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                let arm: CGFloat = Swift.min(size.width, size.height) * 0.26
                var tick = Path()
                tick.move(to: CGPoint(x: centre.x - cos(angle) * arm, y: centre.y - sin(angle) * arm))
                tick.addLine(to: CGPoint(x: centre.x + cos(angle) * arm, y: centre.y + sin(angle) * arm))
                context.stroke(tick, with: .color(Theme.gold),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
    }
}
