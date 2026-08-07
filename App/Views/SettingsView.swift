import SwiftUI
import RavelaneCore

struct SettingsView: View {
    @State private var settings = GameSettings.shared
    @State private var showPrivacy = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    Panel(title: "Difficulty") {
                        Picker("Difficulty", selection: $settings.difficulty) {
                            ForEach(Difficulty.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text(settings.difficulty.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Panel(title: "Pace") {
                        Row(title: "Game speed", detail: "How fast the car covers the track")
                        Picker("Game speed", selection: $settings.gameSpeed) {
                            ForEach(GameSettings.speedChoices, id: \.value) { choice in
                                Text(choice.label).tag(choice.value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Panel(title: "Feel") {
                        Toggle(isOn: $settings.soundEnabled) {
                            Row(title: "Sound", detail: "A pitched click per placement, core and landing")
                        }
                        Toggle(isOn: $settings.hapticsEnabled) {
                            Row(title: "Vibration", detail: "A pulse alongside every sound")
                        }
                    }

                    Panel(title: "Build") {
                        Toggle(isOn: $settings.showGhost) {
                            Row(title: "Ghost preview", detail: "Show where the selected piece would land")
                        }
                        Row(title: "Camera distance", detail: "How far back the chase camera sits")
                        Slider(value: $settings.cameraPullback, in: 0.6...1.8).tint(Theme.neon)
                    }

                    Panel(title: "Catalog") {
                        Stat(label: "Levels", value: "\(LevelCatalog.summaries.count)")
                        Stat(label: "Worlds", value: "\(WorldID.allCases.count)")
                        Stat(label: "Track pieces", value: "\(PieceCatalog.all.count)")
                        Stat(label: "Cars", value: "\(CarCatalog.all.count)")
                        Stat(label: "Parts", value: "\(PartCatalog.all.count)")
                    }

                    Panel(title: "Legal") {
                        Button {
                            Feedback.shared.play(.place)
                            showPrivacy = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Privacy Policy")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text("This app collects no data")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.dim)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.neon)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(Legal.privacyPolicy == nil)

                        Stat(label: "Version", value: Legal.version)
                    }

                    Button {
                        settings.tutorialSeen = false
                        Feedback.shared.play(.place)
                    } label: {
                        plainButton("Show the tutorial again")
                    }

                    Button {
                        settings.reset()
                        Feedback.shared.play(.discard)
                    } label: {
                        plainButton("Reset settings")
                    }
                }
                .padding(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .tint(Theme.neon)
        .sheet(isPresented: $showPrivacy) {
            if let url = Legal.privacyPolicy {
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }

    private func plainButton(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1)
            }
            .foregroundStyle(Theme.dim)
    }

    private var header: some View {
        HStack {
            BackChip { dismiss() }
            Text("SETTINGS")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .kerning(4)
                .foregroundStyle(Theme.ink)
            Spacer()
        }
    }
}

private struct Panel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
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
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.dim)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
        }
    }
}
