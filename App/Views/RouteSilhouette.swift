import SwiftUI
import RavelaneCore

struct FittedCarCard: View {
    private var spec: CarSpec {
        CarCatalog.spec(CarID(GameSettings.shared.selectedCar)) ?? CarCatalog.starting
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ON THE GRID")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .kerning(3)
                    .foregroundStyle(Theme.dim)
                Text(spec.name)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(CarCopy.note(for: spec))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Image("car_\(spec.id.rawValue)")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 92)
        }
        .padding(16)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}

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

            HStack(spacing: 14) {
                LegendKey(tint: Theme.neon, label: "start", filled: true)
                LegendKey(tint: Theme.cold, label: "gate", filled: false)
                LegendKey(tint: Theme.gold, label: "core", filled: true)
                Spacer()
            }
        }
        .padding(16)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}

private struct LegendKey: View {
    let tint: Color
    let label: String
    let filled: Bool

    var body: some View {
        HStack(spacing: 5) {
            Group {
                if filled {
                    Circle().fill(tint)
                } else {
                    Circle().strokeBorder(tint, lineWidth: 1.5)
                }
            }
            .frame(width: 7, height: 7)

            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.dim)
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
                        grid(span: span, inset: inset)
                            .stroke(Theme.hairline, lineWidth: 0.6)
                        markers(silhouette.cores, span: span, inset: inset, radius: lineWidth * 1.9)
                            .fill(Theme.gold.opacity(0.16))
                        markers(silhouette.cores, span: span, inset: inset, radius: lineWidth * 0.9)
                            .fill(Theme.gold)
                        markers(silhouette.gates, span: span, inset: inset, radius: lineWidth * 1.5)
                            .stroke(Theme.cold, lineWidth: lineWidth * 0.7)
                        markers(silhouette.gates, span: span, inset: inset, radius: lineWidth * 0.35)
                            .fill(Theme.cold)
                        endpoint(silhouette.path, atStart: true, span: span, inset: inset,
                                 radius: lineWidth * 1.4)
                            .fill(Theme.neon)
                        endpoint(silhouette.path, atStart: false, span: span, inset: inset,
                                 radius: lineWidth * 2.2)
                            .stroke(Theme.neon.opacity(0.8), lineWidth: lineWidth * 0.6)
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

    private func grid(span: CGFloat, inset: CGFloat) -> Path {
        var path = Path()
        let divisions = 4
        for step in 0...divisions {
            let offset: CGFloat = inset + span * CGFloat(step) / CGFloat(divisions)
            path.move(to: CGPoint(x: inset, y: offset))
            path.addLine(to: CGPoint(x: inset + span, y: offset))
            path.move(to: CGPoint(x: offset, y: inset))
            path.addLine(to: CGPoint(x: offset, y: inset + span))
        }
        return path
    }

    private func endpoint(_ values: [Int], atStart: Bool, span: CGFloat, inset: CGFloat,
                          radius: CGFloat) -> Path {
        guard values.count >= 4 else { return Path() }
        let index: Int = atStart ? 0 : values.count - 2
        let location: CGPoint = point(values, at: index, span: span, inset: inset)
        var path = Path()
        path.addEllipse(in: CGRect(x: location.x - radius, y: location.y - radius,
                                   width: radius * 2, height: radius * 2))
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
