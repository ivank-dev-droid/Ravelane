import SwiftUI
import QuartzCore
import RealityKit
import RavelaneCore

struct GameView: View {
    @State private var model: SessionViewModel
    @State private var scene = TrackScene()
    @State private var selectedSlot: Int?
    @State private var showPause = false
    @State private var recorded = false
    @Environment(\.dismiss) private var dismiss

    init(level: Level, deck: Deck? = nil) {
        _model = State(initialValue: SessionViewModel(level: level, deck: deck))
    }

    var body: some View {
        ZStack {
            RealityView { content in
                content.camera = .virtual
                content.add(scene.root)
            } update: { _ in
                scene.update(model: model)
            }
            .ignoresSafeArea()
            .background(Theme.void)

            VStack(spacing: 0) {
                header
                if let bearing = model.bearing, model.outcome == nil {
                    HStack {
                        CompassView(bearing: bearing)
                        Spacer()
                        if let slot = selectedSlot,
                           let id = model.hand[safe: slot]?.piece,
                           let piece = PieceCatalog.cache.piece(id) {
                            GhostVerdict(
                                piece: piece,
                                endsCloser: model.bringsCloser(id),
                                allowed: model.session.canPlace(slot: slot) == nil
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                Spacer()
                if let outcome = model.outcome {
                    ResultsCard(
                        level: model.level,
                        result: outcome,
                        trace: model.trace,
                        onRetry: { model.restart(); recorded = false },
                        onExit: { dismiss() }
                    )
                    .padding(.bottom, 20)
                } else {
                    HandBar(model: model, selectedSlot: $selectedSlot)
                        .padding(.bottom, 16)
                }
            }

            if showPause {
                PauseOverlay(
                    onResume: { showPause = false; model.setPaused(false) },
                    onRestart: { showPause = false; model.restart(); recorded = false },
                    onExit: { dismiss() }
                )
            }
        }
        .preferredColorScheme(.dark)
        .animation(.snappy(duration: 0.28), value: model.outcome != nil)
        .animation(.easeInOut(duration: 0.2), value: showPause)
        .onChange(of: selectedSlot) { _, slot in
            guard GameSettings.shared.showGhost,
                  let slot, let piece = model.hand[safe: slot]?.piece else {
                scene.hideGhost()
                return
            }
            scene.showGhost(samples: model.previewSamples(for: piece),
                            safe: model.session.canPlace(slot: slot) == nil)
        }
        .onChange(of: model.outcome != nil) { _, finished in
            guard finished, !recorded, let outcome = model.outcome else { return }
            recorded = true
            ProgressStore.shared.record(result: outcome, for: model.level)
        }
        .task {
            model.advance(to: CACurrentMediaTime())
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(8))
                model.advance(to: CACurrentMediaTime())
                scene.update(model: model)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                showPause = true
                model.setPaused(true)
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.35), in: Circle())
            }

            Clock(label: "RUNWAY",
                  value: model.clocks.runwaySeconds.oneDecimal + "s",
                  tint: model.clocks.runwaySeconds < Fixed(3) ? Theme.alarm : Theme.cold)
            Clock(label: "MATERIAL", value: "\(model.material)", tint: Theme.gold)
            Clock(label: "SPEED", value: model.carSpeed.oneDecimal, tint: Theme.neon)

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(model.session.objectives.collectedCount)/\(model.level.cores.count)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.gold)
                Text("\(model.placedCount)/\(model.level.parPieces)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

private struct Clock: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.dim)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }
}

private struct HandBar: View {
    let model: SessionViewModel
    @Binding var selectedSlot: Int?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(model.hand.enumerated()), id: \.offset) { index, slot in
                PieceCard(
                    slot: slot,
                    piece: slot.piece.flatMap { PieceCatalog.cache.piece($0) },
                    cost: slot.piece.map { model.session.cost(of: $0) } ?? 0,
                    selected: selectedSlot == index,
                    allowed: model.session.canPlace(slot: index) == nil
                )
                .frame(maxWidth: .infinity)
                .contentShape(RoundedRectangle(cornerRadius: 14))
                .onTapGesture {
                    if selectedSlot == index {
                        model.place(slot: index)
                        selectedSlot = nil
                    } else {
                        selectedSlot = index
                    }
                }
                .onLongPressGesture { model.discard(slot: index) }
            }
        }
        .padding(.horizontal, 14)
    }
}

private struct PieceCard: View {
    let slot: HandSlot
    let piece: Piece?
    let cost: Int
    let selected: Bool
    let allowed: Bool

    var body: some View {
        VStack(spacing: 5) {
            if let piece {
                PieceShapeView(piece: piece, tint: allowed ? Theme.cold : Theme.alarm)
                    .frame(height: 46)
            } else {
                Image(systemName: "hourglass")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.dim.opacity(0.6))
                    .frame(height: 46)
            }

            Text(piece?.name ?? "drawing")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(slot.isFilled ? Theme.ink : Theme.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let piece {
                HStack(spacing: 5) {
                    Text("\(piece.length.whole)m")
                        .foregroundStyle(Theme.dim)
                    Text("\(cost)")
                        .foregroundStyle(allowed ? Theme.gold : Theme.alarm)
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 6)
        .frame(height: 104)
        .background(.black.opacity(selected ? 0.6 : 0.42),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(selected ? Theme.cold : Theme.hairline, lineWidth: selected ? 2 : 1)
        }
    }
}

private struct PauseOverlay: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("PAUSED")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .kerning(6)
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 4)

                ActionButton(title: "Resume", primary: true, action: onResume)
                ActionButton(title: "Restart", primary: false, action: onRestart)
                ActionButton(title: "Leave", primary: false, action: onExit)
            }
            .padding(28)
            .background(Theme.void.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.hairline, lineWidth: 1)
            }
            .padding(.horizontal, 40)
        }
    }
}

struct ActionButton: View {
    let title: String
    let primary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .kerning(2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(primary ? Theme.neon : Theme.panelStrong,
                            in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(primary ? Theme.void : Theme.ink)
        }
    }
}

private struct ResultsCard: View {
    let level: Level
    let result: LevelResult
    let trace: [SessionViewModel.Trace]
    let onRetry: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 13) {
            Text(result.completed ? "ROUTE COMPLETE" : title(for: result.crashReason))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .kerning(2)
                .foregroundStyle(result.completed ? Theme.cold : Theme.alarm)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < result.stars(for: level) ? "star.fill" : "star")
                        .font(.system(size: 16))
                        .foregroundStyle(index < result.stars(for: level) ? Theme.gold : Theme.dim.opacity(0.4))
                }
            }

            HStack(spacing: 18) {
                Meter(label: "PIECES", value: "\(result.piecesUsed)/\(level.parPieces)",
                      tint: result.piecesUsed <= level.parPieces ? Theme.cold : Theme.alarm)
                Meter(label: "CORES", value: "\(result.coresCollected)/\(result.coreTotal)", tint: Theme.gold)
                Meter(label: "TIME", value: result.elapsed.oneDecimal, tint: Theme.ink)
            }

            if trace.count > 3 {
                RunTrace(trace: trace)
                    .frame(height: 74)
                    .background(Theme.void.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 10) {
                ActionButton(title: "Retry", primary: true, action: onRetry)
                ActionButton(title: "Levels", primary: false, action: onExit)
            }
        }
        .padding(20)
        .background(Theme.void.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .padding(.horizontal, 22)
    }

    private func title(for reason: CrashReason?) -> String {
        switch reason {
        case .ranOffTheEdge: return "SLID OFF"
        case .ranOutOfTrack: return "NO TRACK LEFT"
        case .fell: return "FELL"
        case .brokeUp: return "BROKE UP"
        case .landedBadly: return "BAD LANDING"
        case .stalled: return "STALLED ON THE CLIMB"
        case .boxedIn: return "NOWHERE LEFT TO BUILD"
        case nil: return "RAN OUT OF RUNWAY"
        }
    }
}

private struct RunTrace: View {
    let trace: [SessionViewModel.Trace]

    var body: some View {
        Canvas { context, size in
            guard trace.count > 1 else { return }
            let maxSpeed = max(1.0, trace.map(\.speed).max() ?? 1)

            func line(_ values: [Double], scale: Double) -> Path {
                var path = Path()
                for (index, value) in values.enumerated() {
                    let x = size.width * CGFloat(index) / CGFloat(max(1, values.count - 1))
                    let y = size.height - CGFloat(min(1, value / scale)) * (size.height - 16) - 6
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                return path
            }

            context.stroke(line(trace.map(\.speed), scale: maxSpeed),
                           with: .color(Theme.neon), lineWidth: 1.6)
            context.stroke(line(trace.map { min($0.runway, 12) }, scale: 12),
                           with: .color(Theme.cold.opacity(0.75)),
                           style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))

            context.draw(
                Text("speed and runway over the run")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(Theme.dim),
                at: CGPoint(x: size.width / 2, y: 8)
            )
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
