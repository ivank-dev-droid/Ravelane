import SwiftUI
import RavelinCore

struct SettingsView: View {
    @State private var settings = GameSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    Section(title: "Feel") {
                        Toggle(isOn: $settings.soundEnabled) {
                            Row(title: "Sound", detail: "Reel clicks, landings, checkpoints")
                        }
                        Toggle(isOn: $settings.hapticsEnabled) {
                            Row(title: "Vibration", detail: "A pulse on every placement and impact")
                        }
                    }

                    Section(title: "Pace") {
                        VStack(alignment: .leading, spacing: 10) {
                            Row(title: "Game speed", detail: "How fast the car covers the track")
                            Picker("Game speed", selection: $settings.gameSpeed) {
                                ForEach(GameSettings.speedChoices, id: \.value) { choice in
                                    Text(choice.label).tag(choice.value)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        Toggle(isOn: $settings.assistMode) {
                            Row(title: "Assist", detail: "A further 30 percent slower, for learning a world")
                        }
                    }

                    Section(title: "Build") {
                        Toggle(isOn: $settings.showGhost) {
                            Row(title: "Ghost preview", detail: "Show where the selected piece would land")
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Row(title: "Camera distance", detail: "How far back the chase camera sits")
                            Slider(value: $settings.cameraPullback, in: 0.6...1.8)
                                .tint(Theme.neon)
                        }
                    }

                    Section(title: "Catalog") {
                        Stat(label: "Levels", value: "\(LevelCatalog.summaries.count)")
                        Stat(label: "Worlds", value: "\(WorldID.allCases.count)")
                        Stat(label: "Track pieces", value: "\(PieceCatalog.all.count)")
                        Stat(label: "Cars", value: "\(CarCatalog.all.count)")
                        Stat(label: "Parts", value: "\(PartCatalog.all.count)")
                    }

                    Button {
                        settings.reset()
                        Feedback.shared.play(.discard)
                    } label: {
                        Text("Reset to defaults")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1)
                            }
                    }
                    .foregroundStyle(Theme.dim)
                }
                .padding(22)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .tint(Theme.neon)
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Theme.panel, in: Circle())
            }
            Text("SETTINGS")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .kerning(4)
                .foregroundStyle(Theme.ink)
                .padding(.leading, 6)
            Spacer()
        }
    }
}

private struct Section<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .kerning(3)
                .foregroundStyle(Theme.neon)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}

private struct Row: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct Stat: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.dim)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
        }
    }
}
