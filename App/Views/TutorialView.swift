import SwiftUI

struct TutorialView: View {
    var onFinish: () -> Void
    @State private var page = 0

    private let lessons = Lesson.all

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        GameSettings.shared.tutorialSeen = true
                        onFinish()
                    } label: {
                        Text("SKIP")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .kerning(2)
                            .foregroundStyle(Theme.dim)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.panel, in: Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                TabView(selection: $page) {
                    ForEach(Array(lessons.enumerated()), id: \.offset) { index, lesson in
                        LessonPage(lesson: lesson).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(0..<lessons.count, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Theme.neon : Theme.panelStrong)
                            .frame(width: index == page ? 22 : 7, height: 7)
                            .animation(.snappy(duration: 0.2), value: page)
                    }
                }
                .padding(.bottom, 18)

                Button {
                    if page < lessons.count - 1 {
                        withAnimation { page += 1 }
                        Feedback.shared.play(.place)
                    } else {
                        GameSettings.shared.tutorialSeen = true
                        Feedback.shared.play(.win)
                        onFinish()
                    }
                } label: {
                    Text(page < lessons.count - 1 ? "NEXT" : "BUILD SOMETHING")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .kerning(2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.neon, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Theme.void)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

struct Lesson {
    let title: String
    let body: String
    let sketch: Sketch

    enum Sketch {
        case ribbon
        case runway
        case corner
        case economy
    }

    static let all: [Lesson] = [
        Lesson(
            title: "You never steer",
            body: "The car drives itself, forward, always, and it is already moving. What you control is the track. Pick a piece and it snaps onto the open end. Because the car goes wherever the track goes, building is steering.",
            sketch: .ribbon
        ),
        Lesson(
            title: "Runway is a clock",
            body: "The number at the top left is how many seconds of track are left in front of the car. When it reaches zero the car runs off the end of the world. Long straights buy you time to think. Corners spend it.",
            sketch: .runway
        ),
        Lesson(
            title: "You build the corner you will arrive at",
            body: "Speed is simulated. Downhill gains it, uphill sheds it, and a tight corner taken too fast throws the car off the edge. Lay a banked piece before a curve and you can carry far more speed through it. The ghost shows you the answer before you commit.",
            sketch: .corner
        ),
        Lesson(
            title: "Material runs out",
            body: "Every piece costs Material. You earn it back from checkpoints, gold cores and clean landings. That is why the safe route is rarely the right one: a track that never touches a core eventually cannot afford to continue.",
            sketch: .economy
        )
    ]
}

private struct LessonPage: View {
    let lesson: Lesson

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            SketchView(kind: lesson.sketch)
                .frame(height: 150)
                .padding(.horizontal, 30)

            VStack(spacing: 12) {
                Text(lesson.title)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(lesson.body)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 30)
            Spacer()
        }
    }
}

private struct SketchView: View {
    let kind: Lesson.Sketch

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                switch kind {
                case .ribbon: drawRibbon(&context, size, t)
                case .runway: drawRunway(&context, size, t)
                case .corner: drawCorner(&context, size, t)
                case .economy: drawEconomy(&context, size, t)
                }
            }
        }
    }

    private func drawRibbon(_ context: inout GraphicsContext, _ size: CGSize, _ t: TimeInterval) {
        let cycle = CGFloat(t.truncatingRemainder(dividingBy: 3) / 3)
        let laid = size.width * (0.25 + 0.6 * cycle)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height * 0.7))
        path.addLine(to: CGPoint(x: laid, y: size.height * 0.7))
        context.stroke(path, with: .color(Theme.neon), lineWidth: 5)

        var pending = Path()
        pending.move(to: CGPoint(x: laid, y: size.height * 0.7))
        pending.addLine(to: CGPoint(x: size.width, y: size.height * 0.7))
        context.stroke(pending, with: .color(Theme.hairline),
                       style: StrokeStyle(lineWidth: 3, dash: [5, 6]))

        let carX = laid - 40
        car(&context, at: CGPoint(x: max(20, carX), y: size.height * 0.7 - 9))
    }

    private func drawRunway(_ context: inout GraphicsContext, _ size: CGSize, _ t: TimeInterval) {
        let cycle = CGFloat((sin(t * 1.4) + 1) / 2)
        let end = size.width * (0.35 + 0.55 * cycle)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height * 0.65))
        path.addLine(to: CGPoint(x: end, y: size.height * 0.65))
        context.stroke(path, with: .color(Theme.neon), lineWidth: 5)

        let carX = size.width * 0.18
        car(&context, at: CGPoint(x: carX, y: size.height * 0.65 - 9))

        var gap = Path()
        gap.move(to: CGPoint(x: carX + 14, y: size.height * 0.4))
        gap.addLine(to: CGPoint(x: end, y: size.height * 0.4))
        context.stroke(gap, with: .color(cycle < 0.3 ? Theme.alarm : Theme.cold),
                       style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
        context.draw(
            Text(cycle < 0.3 ? "RUNWAY LOW" : "RUNWAY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(cycle < 0.3 ? Theme.alarm : Theme.cold),
            at: CGPoint(x: (carX + end) / 2, y: size.height * 0.28)
        )
    }

    private func drawCorner(_ context: inout GraphicsContext, _ size: CGSize, _ t: TimeInterval) {
        let flip = sin(t * 1.1) > 0
        var arc = Path()
        arc.move(to: CGPoint(x: 10, y: size.height * 0.8))
        arc.addQuadCurve(to: CGPoint(x: size.width - 10, y: size.height * 0.3),
                         control: CGPoint(x: size.width * 0.55, y: size.height * 0.85))
        context.stroke(arc, with: .color(flip ? Theme.cold : Theme.alarm), lineWidth: 5)

        context.draw(
            Text(flip ? "BANKED — HOLDS" : "FLAT — SLIDES OFF")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(flip ? Theme.cold : Theme.alarm),
            at: CGPoint(x: size.width / 2, y: 18)
        )
        car(&context, at: CGPoint(x: size.width * 0.3, y: size.height * 0.68))
    }

    private func drawEconomy(_ context: inout GraphicsContext, _ size: CGSize, _ t: TimeInterval) {
        let cycle = t.truncatingRemainder(dividingBy: 2.4) / 2.4
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height * 0.7))
        path.addLine(to: CGPoint(x: size.width, y: size.height * 0.7))
        context.stroke(path, with: .color(Theme.neon), lineWidth: 5)

        for index in 0..<4 {
            let x = size.width * (0.2 + 0.2 * CGFloat(index))
            let taken = CGFloat(cycle) * size.width > x
            let r: CGFloat = 6
            context.fill(
                Path(ellipseIn: CGRect(x: x - r, y: size.height * 0.42 - r, width: r * 2, height: r * 2)),
                with: .color(taken ? Theme.panelStrong : Theme.gold)
            )
        }
        car(&context, at: CGPoint(x: CGFloat(cycle) * size.width, y: size.height * 0.7 - 9))
        context.draw(
            Text("COLLECT OR RUN DRY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.gold),
            at: CGPoint(x: size.width / 2, y: 16)
        )
    }

    private func car(_ context: inout GraphicsContext, at point: CGPoint) {
        let rect = CGRect(x: point.x - 9, y: point.y - 5, width: 18, height: 10)
        context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.white))
        context.stroke(Path(roundedRect: rect, cornerRadius: 3),
                       with: .color(Theme.cold), lineWidth: 1.5)
    }
}
