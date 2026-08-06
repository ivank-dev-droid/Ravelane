import SwiftUI
import RavelinCore

struct StatsView: View {
    @State private var progress = ProgressStore.shared
    @State private var confirmReset = false
    @Environment(\.dismiss) private var dismiss

    private var totalLevels: Int { LevelCatalog.summaries.count }
    private var maximumStars: Int { totalLevels * 3 }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    BackChip { dismiss() }
                    Text("PROGRESS")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .kerning(4)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 14) {
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 22) {
                                    Meter(label: "STARS",
                                          value: "\(progress.totalStars)/\(maximumStars)",
                                          tint: Theme.gold)
                                    Meter(label: "CLEARED",
                                          value: "\(progress.clearedCount)/\(totalLevels)",
                                          tint: Theme.cold)
                                    Spacer()
                                }
                                ProgressBar(fraction: maximumStars == 0 ? 0
                                            : Double(progress.totalStars) / Double(maximumStars))
                            }
                        }

                        ForEach(WorldID.allCases, id: \.self) { world in
                            let levels = LevelCatalog.summaries(in: world)
                            let stars = progress.stars(in: world)
                            let cleared = progress.cleared(in: world)
                            Card {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(world.displayName.uppercased())
                                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                                .kerning(2)
                                                .foregroundStyle(Theme.ink)
                                            Text(world.tagline)
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundStyle(Theme.dim)
                                        }
                                        Spacer()
                                        Text("\(cleared)/\(levels.count)")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundStyle(cleared == levels.count ? Theme.cold : Theme.dim)
                                    }
                                    ProgressBar(fraction: levels.isEmpty ? 0
                                                : Double(stars) / Double(levels.count * 3))
                                }
                            }
                        }

                        Button {
                            confirmReset = true
                        } label: {
                            Text("Reset progress")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Theme.alarm.opacity(0.85))
                        }
                        .confirmationDialog("Erase every star and best?",
                                            isPresented: $confirmReset, titleVisibility: .visible) {
                            Button("Erase", role: .destructive) { progress.reset() }
                            Button("Keep", role: .cancel) {}
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.panelStrong)
                Capsule()
                    .fill(LinearGradient(colors: [Theme.neon, Theme.blue],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: 6)
    }
}
