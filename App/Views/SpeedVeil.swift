import SwiftUI

struct SpeedVeil: View {
    let speed: Float
    let ceiling: Float

    private var intensity: Double {
        let normalised = Double(max(0, min(1, (speed - ceiling * 0.45) / (ceiling * 0.55))))
        return normalised * normalised
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { context, size in
                guard intensity > 0.02 else { return }
                let seconds = timeline.date.timeIntervalSinceReferenceDate
                let centre = CGPoint(x: size.width / 2, y: size.height * 0.46)
                let reach = max(size.width, size.height)

                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(colors: [.clear, Theme.neon.opacity(0.20 * intensity)]),
                        center: centre,
                        startRadius: reach * 0.24,
                        endRadius: reach * 0.72
                    )
                )

                let strokes = 26
                for index in 0..<strokes {
                    let seed = Double(index) * 2.399963
                    let angle = seed.truncatingRemainder(dividingBy: 2 * .pi)
                    let phase = (seconds * 1.7 + Double(index) * 0.137).truncatingRemainder(dividingBy: 1)
                    let near = reach * (0.20 + 0.55 * phase)
                    let far = near + reach * 0.14 * intensity
                    let start = CGPoint(x: centre.x + cos(angle) * near, y: centre.y + sin(angle) * near)
                    let end = CGPoint(x: centre.x + cos(angle) * far, y: centre.y + sin(angle) * far)

                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    let fade = (1 - abs(phase - 0.5) * 2) * intensity
                    context.stroke(
                        path,
                        with: .color(Theme.cold.opacity(0.42 * fade)),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                    )
                }
            }
        }
    }
}
