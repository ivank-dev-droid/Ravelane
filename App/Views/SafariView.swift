import SwiftUI
import SafariServices
import UIKit

enum Legal {
    static let privacyPolicy = URL(
        string: "https://www.freeprivacypolicy.com/live/15e4cb6a-6846-4ed5-9b35-9e2602cba36c"
    )

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (version?, build?): return "\(version) (\(build))"
        case let (version?, nil): return version
        default: return "1.0"
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true

        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.dismissButtonStyle = .close
        controller.preferredControlTintColor = UIColor(Theme.neon)
        controller.preferredBarTintColor = UIColor(Theme.void)
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
