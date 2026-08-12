import Foundation
import AVFoundation
import UIKit

@MainActor
final class Feedback {
    static let shared = Feedback()

    enum Cue: Hashable, CaseIterable {
        case place
        case discard
        case reject
        case core
        case checkpoint
        case land
        case crash
        case win
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

    private var cache: [Cue: AVAudioPCMBuffer] = [:]

    private func buffer(for cue: Cue) -> AVAudioPCMBuffer? {
        if let cached = cache[cue] { return cached }
        guard let format else { return nil }
        let voice = VoiceBank.voice(for: cue)
        let frames = AVAudioFrameCount(voice.duration * format.sampleRate)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        voice.render(sampleRate: format.sampleRate, into: channel, frames: Int(frames))
        cache[cue] = buffer
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
