import SwiftUI
import QuartzCore
import RealityKit
import RavelinCore

struct GameView: View {
    @State private var model: SessionViewModel
    @State private var scene = TrackScene()
    @State private var selectedSlot: Int?
    @Environment(\.dismiss) private var dismiss

    init(level: Level) {
        _model = State(initialValue: SessionViewModel(level: level))
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
            .background(Color(red: 0.043, green: 0.016, blue: 0.094))

            VStack(spacing: 0) {
                Header(model: model, onExit: { dismiss() })
                Spacer()
                if let outcome = model.outcome {
                    ResultCard(level: model.level, result: outcome,
                               onRetry: { model.restart() },
                               onExit: { dismiss() })
                        .padding(.bottom, 24)
                } else {
                    HandBar(model: model, selectedSlot: $selectedSlot)
                        .padding(.bottom, 18)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedSlot) { _, slot in
            guard let slot, let piece = model.hand[safe: slot]?.piece else {
                scene.hideGhost()
                return
            }
            scene.showGhost(samples: model.previewSamples(for: piece),
                            safe: model.session.canPlace(slot: slot) == nil)
        }
        .task {
            let start = CACurrentMediaTime()
            model.advance(to: start)
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(8))
                model.advance(to: CACurrentMediaTime())
                scene.update(model: model)
            }
        }
    }
}

private struct Header: View {
    let model: SessionViewModel
    let onExit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(10)
                    .background(.white.opacity(0.08), in: Circle())
            }

            Clock(label: "RUNWAY",
                  value: model.clocks.runwaySeconds.oneDecimal + "s",
                  tint: model.clocks.runwaySeconds < Fixed(3) ? .red : .cyan)
            Clock(label: "MATERIAL", value: "\(model.material)", tint: .yellow)
            Clock(label: "SPEED", value: model.carSpeed.oneDecimal, tint: .purple)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct Clock: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }
}

private struct HandBar: View {
    let model: SessionViewModel
    @Binding var selectedSlot: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(model.hand.enumerated()), id: \.offset) { index, slot in
                    PieceCard(
                        slot: slot,
                        cost: slot.piece.map { model.session.cost(of: $0) } ?? 0,
                        selected: selectedSlot == index,
                        affordable: model.session.canPlace(slot: index) == nil
                    )
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
            .padding(.horizontal, 16)
        }
    }
}

private struct PieceCard: View {
    let slot: HandSlot
    let cost: Int
    let selected: Bool
    let affordable: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(slot.piece?.rawValue.replacingOccurrences(of: "_", with: " ") ?? "…")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(slot.isFilled ? 0.9 : 0.3))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(slot.isFilled ? "\(cost)" : "")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(affordable ? .yellow : .red)
        }
        .frame(width: 92, height: 58)
        .background(.white.opacity(selected ? 0.18 : 0.07),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selected ? Color.cyan : Color.white.opacity(0.12), lineWidth: 1.5)
        }
    }
}

private struct ResultCard: View {
    let level: Level
    let result: LevelResult
    let onRetry: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(result.completed ? "ROUTE COMPLETE" : "RUN ENDED")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(result.completed ? .cyan : .red)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < result.stars(for: level) ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                }
            }

            Text("\(result.piecesUsed) pieces · par \(level.parPieces) · \(result.coresCollected)/\(result.coreTotal) cores")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 12) {
                Button("Retry", action: onRetry)
                Button("Levels", action: onExit)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(24)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 28)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
