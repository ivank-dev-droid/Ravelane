import SwiftUI
import RavelaneCore

struct ObjectiveMap: View {
    let level: Level

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("APPROACH")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .kerning(3)
                    .foregroundStyle(Theme.dim)
                Spacer()
                Text("\(level.objectiveOrder.count) gates · \(level.cores.count) cores")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }

            RouteSilhouette(levelID: level.id, lineWidth: 3, showsMarkers: true, showsPath: false)
                .frame(height: 168)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}

struct RouteSilhouette: View {
    let levelID: LevelID
    var lineWidth: CGFloat = 2
    var showsMarkers = true
    var showsPath = true

    private var silhouette: LevelSilhouette? {
        LevelSilhouettes.table[levelID.rawValue]
    }

    var body: some View {
        GeometryReader { proxy in
            let box = min(proxy.size.width, proxy.size.height)
            let inset = box * 0.10
            let span = box - inset * 2

            if let silhouette, silhouette.path.count >= 4 {
                ZStack {
                    if showsPath {
                        routePath(silhouette.path, span: span, inset: inset)
                            .stroke(Theme.neon.opacity(0.28),
                                    style: StrokeStyle(lineWidth: lineWidth * 3, lineCap: .round, lineJoin: .round))
                        routePath(silhouette.path, span: span, inset: inset)
                            .stroke(Theme.neon,
                                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    }

                    if showsMarkers {
                        markers(silhouette.cores, span: span, inset: inset, radius: lineWidth * 0.9)
                            .fill(Theme.gold)
                        markers(silhouette.gates, span: span, inset: inset, radius: lineWidth * 1.5)
                            .stroke(Theme.cold, lineWidth: lineWidth * 0.7)
                    }
                }
                .frame(width: box, height: box)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func point(_ values: [Int], at index: Int, span: CGFloat, inset: CGFloat) -> CGPoint {
        CGPoint(x: inset + CGFloat(values[index]) / 1000 * span,
                y: inset + CGFloat(values[index + 1]) / 1000 * span)
    }

    private func routePath(_ values: [Int], span: CGFloat, inset: CGFloat) -> Path {
        var path = Path()
        var index = 0
        while index + 1 < values.count {
            let location = point(values, at: index, span: span, inset: inset)
            if index == 0 {
                path.move(to: location)
            } else {
                path.addLine(to: location)
            }
            index += 2
        }
        return path
    }

    private func markers(_ values: [Int], span: CGFloat, inset: CGFloat, radius: CGFloat) -> Path {
        var path = Path()
        var index = 0
        while index + 1 < values.count {
            let location = point(values, at: index, span: span, inset: inset)
            path.addEllipse(in: CGRect(x: location.x - radius, y: location.y - radius,
                                       width: radius * 2, height: radius * 2))
            index += 2
        }
        return path
    }
}
