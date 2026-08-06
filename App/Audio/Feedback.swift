import Foundation
import AVFoundation
import UIKit

@MainActor
final class Feedback {
    static let shared = Feedback()

    enum Cue {
        case place
        case discard
        case reject
        case core
        case checkpoint
        case land
        case crash
        case win

        var frequency: Double {
            switch self {
            case .place: return 620
            case .discard: return 330
            case .reject: return 180
            case .core: return 940
            case .checkpoint: return 780
            case .land: return 420
            case .crash: return 110
            case .win: return 1180
            }
        }

        var duration: Double {
            switch self {
            case .crash, .win: return 0.34
            case .reject: return 0.16
            default: return 0.09
            }
        }

        var level: Float {
            switch self {
            case .crash, .win: return 0.30
            case .reject: return 0.16
            default: return 0.19
            }
        }
    }

    private let engine = AVAudioEngine()
    private var player: AVAudioPlayerNode?
    private var format: AVAudioFormat?
    private var started = false

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notice = UINotificationFeedbackGenerator()

    private init() {
        light.prepare()
        rigid.prepare()
        heavy.prepare()
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true

        let node = AVAudioPlayerNode()
        let sampleFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        guard let sampleFormat else { return }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: sampleFormat)
        engine.mainMixerNode.outputVolume = 0.7

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            node.play()
            player = node
            format = sampleFormat
        } catch {
            player = nil
        }
    }

    private func buffer(for cue: Cue) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let frames = AVAudioFrameCount(cue.duration * format.sampleRate)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames

        let total = Double(frames)
        for index in 0..<Int(frames) {
            let progress = Double(index) / total
            let envelope = pow(1 - progress, 2.2)
            let sweep = cue.frequency * (1 + progress * 0.12)
            let sample = sin(2 * .pi * sweep * Double(index) / format.sampleRate)
            let harmonic = sin(4 * .pi * sweep * Double(index) / format.sampleRate) * 0.22
            channel[index] = Float((sample + harmonic) * envelope) * cue.level
        }
        return buffer
    }

    func play(_ cue: Cue) {
        let settings = GameSettings.shared

        if settings.hapticsEnabled {
            switch cue {
            case .place, .core: light.impactOccurred()
            case .land, .checkpoint: rigid.impactOccurred()
            case .crash: heavy.impactOccurred()
            case .win: notice.notificationOccurred(.success)
            case .reject: notice.notificationOccurred(.warning)
            case .discard: light.impactOccurred(intensity: 0.6)
            }
        }

        guard settings.soundEnabled else { return }
        startIfNeeded()
        guard let player, let buffer = buffer(for: cue) else { return }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
}
