import SwiftUI

enum Legal {
    static let policyUpdated = "9 September 2026"
    static let contact = "HableKristmundsson@gmail.com"

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (version?, build?): return "\(version) (\(build))"
        case let (version?, nil): return version
        default: return "1.0"
        }
    }

    static let policy: [PolicySection] = [
        PolicySection(
            title: "In short",
            paragraphs: [
                """
                Ravelane is a single-player game that runs entirely on your device. It collects \
                no personal data, sends nothing anywhere, contains no advertising and no \
                analytics, and works with the internet switched off.
                """
            ]
        ),
        PolicySection(
            title: "Data we collect",
            paragraphs: [
                """
                None. Ravelane has no accounts and no sign-up. It never asks for and never \
                records your name, email address, phone number, date of birth, location, \
                contacts, photos, microphone or camera input.
                """,
                """
                The game does not read the advertising identifier, does not build a device \
                fingerprint and does not track you across apps or websites.
                """
            ]
        ),
        PolicySection(
            title: "What is stored on your device",
            paragraphs: [
                """
                Your progress and preferences are saved on the device itself so the game can \
                pick up where you left off: stars and attempts per level, best piece counts, \
                credits, owned cars and parts, car tuning, saved decks, and your settings for \
                difficulty, speed, sound, vibration, ghost preview and camera distance.
                """,
                """
                This information is written to the app's own private storage on your device. \
                It is never uploaded, never shared, and no one but you can read it. Removing \
                the app removes all of it. "Reset settings" in the Settings screen restores \
                the default preferences; deleting the app erases progress and credits as well.
                """
            ]
        ),
        PolicySection(
            title: "Network use",
            paragraphs: [
                """
                Ravelane makes no network requests of any kind. There is no server behind the \
                game, no remote configuration, no download of extra content, no crash \
                reporting and no third-party SDK of any sort inside the app. Every level, car \
                and texture ships inside the app itself.
                """
            ]
        ),
        PolicySection(
            title: "Third parties",
            paragraphs: [
                """
                We share, sell and disclose nothing, because we hold nothing. No advertising \
                networks, no analytics providers, no data brokers.
                """,
                """
                Apple handles the download and any App Store transaction under Apple's own \
                privacy policy. That relationship is between you and Apple; we receive no \
                personal data from it.
                """
            ]
        ),
        PolicySection(
            title: "Children",
            paragraphs: [
                """
                The game is safe for players of any age. Because it collects no data at all, \
                it collects no data from children either. There is no advertising, no chat, no \
                user-generated content and no link that leads out of the app.
                """
            ]
        ),
        PolicySection(
            title: "Your rights",
            paragraphs: [
                """
                Rights to access, correct, export or erase personal data apply to data a \
                developer holds. We hold none, so there is nothing for us to look up or delete \
                on your behalf. Everything the game knows about you lives on your device and \
                is under your control: delete the app and it is gone.
                """
            ]
        ),
        PolicySection(
            title: "Changes to this policy",
            paragraphs: [
                """
                If the policy ever changes, the new text ships inside an app update and the \
                date below changes with it. There is no remote copy of this document, so what \
                you read here is exactly what the installed version does.
                """
            ]
        ),
        PolicySection(
            title: "Contact",
            paragraphs: [
                """
                Questions about this policy can be sent to \(contact).
                """
            ]
        )
    ]
}

struct PolicySection: Identifiable {
    let title: String
    let paragraphs: [String]

    var id: String { title }
}

struct PrivacyPolicyView: View {
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    Text("Ravelane collects no data and never connects to the internet.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(Legal.policy) { section in
                        PolicyCard(section: section)
                    }

                    HStack {
                        Text("LAST UPDATED")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .kerning(3)
                            .foregroundStyle(Theme.neon)
                        Spacer()
                        Text(Legal.policyUpdated)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.dim)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .padding(20)
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .tint(Theme.neon)
    }

    private var header: some View {
        HStack {
            BackChip(action: dismiss)
            Text("PRIVACY")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .kerning(4)
                .foregroundStyle(Theme.ink)
            Spacer()
        }
    }
}

private struct PolicyCard: View {
    let section: PolicySection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .kerning(3)
                .foregroundStyle(Theme.neon)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}
