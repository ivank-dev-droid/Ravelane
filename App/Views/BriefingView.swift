import SwiftUI
import RavelaneCore

struct BriefingView: View {
    let summary: LevelSummary
    @State private var level: Level?
    @State private var deck: Deck?
    @State private var launch = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let level {
                content(level)
            } else {
                LoadingView(caption: "laying the plinth")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let id = summary.id
            level = await Task.detached(priority: .userInitiated) { LevelCatalog.level(id) }.value
            if let level {
                deck = DeckStore.shared.deck(for: level.world, palette: level.allowedPieces)
            }
        }
        .navigationDestination(isPresented: $launch) {
            if let level {
                GameView(level: level, deck: deck)
                    .navigationBarBackButtonHidden()
            }
        }
    }

    @ViewBuilder
    private func content(_ level: Level) -> some View {
        VStack(spacing: 0) {
            HStack {
                BackChip { dismiss() }
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.name.uppercased())
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .kerning(3)
                        .foregroundStyle(Theme.ink)
                    Text(level.world.tagline)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
                Spacer()
                StarRow(count: ProgressStore.shared.stars(for: level.id))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 14) {
                    ObjectiveMap(level: level)
                    LevelPlan(level: level)
                        .frame(height: 230)
                        .background(Theme.void, in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.hairline, lineWidth: 1)
                        }

                    HStack(spacing: 14) {
                        Meter(label: "PAR", value: "\(level.parPieces)", tint: Theme.ink)
                        Meter(label: "CORES", value: "\(level.cores.count)", tint: Theme.gold)
                        Meter(label: "GATES", value: "\(level.checkpoints.count + 1)", tint: Theme.blue)
                        Meter(label: "MATERIAL", value: "\(level.startingMaterial)", tint: Theme.cold)
                        Spacer()
                    }

                    NavigationLink {
                        DeckBuilderView(world: level.world, palette: level.allowedPieces) { built in
                            deck = built
                        }
                    } label: {
                        SelectorRow(
                            title: "Deck",
                            value: deckLabel,
                            detail: "\(deck?.entries.count ?? 0) kinds, \(deck?.totalPieces ?? 0) pieces"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink { GarageView() } label: {
                        SelectorRow(
                            title: "Car",
                            value: GameSettings.shared.carSpec.name,
                            detail: GameSettings.shared.selectedParts.isEmpty
                                ? "no parts fitted"
                                : "\(GameSettings.shared.selectedParts.count) parts fitted"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink { CodexView() } label: {
                        SelectorRow(title: "Codex", value: "Reference",
                                    detail: "Every piece, car and part with its numbers")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            Button {
                ProgressStore.shared.recordAttempt(level.id)
                Feedback.shared.play(.checkpoint)
                launch = true
            } label: {
                Text("START")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .kerning(3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.neon, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Theme.void)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
    }

    private var deckLabel: String {
        guard let deck, !deck.entries.isEmpty else { return "Default" }
        return "\(deck.entries.count) slots"
    }
}

struct SelectorRow: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .kerning(2)
                    .foregroundStyle(Theme.dim)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.dim)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.dim)
        }
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}

struct StarRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < count ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundStyle(index < count ? Theme.gold : Theme.dim.opacity(0.5))
            }
        }
    }
}

struct LevelPlan: View {
    let level: Level

    var body: some View {
        Canvas { context, size in
            var points: [CGPoint] = []
            var gates: [(CGPoint, Bool)] = []
            var cores: [CGPoint] = []
            var blocks: [(CGPoint, CGFloat)] = []

            let start = CGPoint(x: 0, y: 0)
            points.append(start)
            for gate in level.checkpoints {
                let p = CGPoint(x: gate.position.x.approximateDouble, y: gate.position.z.approximateDouble)
                points.append(p)
                gates.append((p, false))
            }
            let goal = CGPoint(x: level.goal.position.x.approximateDouble,
                               y: level.goal.position.z.approximateDouble)
            points.append(goal)
            gates.append((goal, true))
            for core in level.cores {
                let p = CGPoint(x: core.position.x.approximateDouble, y: core.position.z.approximateDouble)
                cores.append(p)
                points.append(p)
            }
            for volume in level.forbidden {
                let centre = volume.centre
                let p = CGPoint(x: centre.x.approximateDouble, y: centre.z.approximateDouble)
                let radius: CGFloat
                if case .sphere(_, let r) = volume { radius = CGFloat(r.approximateDouble) } else { radius = 12 }
                blocks.append((p, radius))
                points.append(p)
            }

            guard points.count > 1 else { return }
            let minX = points.map(\.x).min()!, maxX = points.map(\.x).max()!
            let minY = points.map(\.y).min()!, maxY = points.map(\.y).max()!
            let spanX = max(1, maxX - minX), spanY = max(1, maxY - minY)
            let inset: CGFloat = 26
            let scale = min((size.width - inset * 2) / spanX, (size.height - inset * 2) / spanY)

            func project(_ p: CGPoint) -> CGPoint {
                CGPoint(x: inset + (p.x - minX) * scale,
                        y: size.height - (inset + (p.y - minY) * scale))
            }

            for (centre, radius) in blocks {
                let c = project(centre)
                let r = radius * scale
                context.fill(
                    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                    with: .color(Theme.alarm.opacity(0.14))
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                    with: .color(Theme.alarm.opacity(0.5)),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
            }

            var thread = Path()
            let ordered = [start] + level.checkpoints.map {
                CGPoint(x: $0.position.x.approximateDouble, y: $0.position.z.approximateDouble)
            } + [goal]
            for (index, point) in ordered.enumerated() {
                let p = project(point)
                if index == 0 { thread.move(to: p) } else { thread.addLine(to: p) }
            }
            context.stroke(thread, with: .color(Theme.neon.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))

            for point in cores {
                let p = project(point)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)),
                             with: .color(Theme.gold))
            }

            let origin = project(start)
            context.fill(Path(ellipseIn: CGRect(x: origin.x - 5, y: origin.y - 5, width: 10, height: 10)),
                         with: .color(Theme.cold))

            for (point, isGoal) in gates {
                let p = project(point)
                let r: CGFloat = isGoal ? 9 : 6
                context.stroke(
                    Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                    with: .color(isGoal ? Theme.gold : Theme.blue),
                    lineWidth: 2
                )
            }

            context.draw(
                Text("PLAN · objectives only, not the route")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Theme.dim),
                at: CGPoint(x: size.width / 2, y: size.height - 10)
            )
        }
    }
}
