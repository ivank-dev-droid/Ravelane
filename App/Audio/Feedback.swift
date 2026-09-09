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

    private var engine = AVAudioEngine()
    private var player: AVAudioPlayerNode?
    private var format: AVAudioFormat?
    private var cache: [Cue: AVAudioPCMBuffer] = [:]
    private var rebuilds = 0

    private static let maximumRebuilds = 4

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notice = UINotificationFeedbackGenerator()

    private init() {
        light.prepare()
        rigid.prepare()
        heavy.prepare()
    }

    private func prepareEngine() {
        if let player, engine.isRunning, player.isPlaying { return }
        guard rebuilds <= Feedback.maximumRebuilds else { return }

        if player == nil {
            guard let sampleFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: sampleFormat)
            engine.mainMixerNode.outputVolume = 0.7
            player = node
            format = sampleFormat
        }

        guard let player else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient)
            try session.setActive(true)
            if !engine.isRunning { try engine.start() }
            if !player.isPlaying { player.play() }
        } catch {
            discardEngine()
        }
    }

    private func discardEngine() {
        engine.stop()
        engine = AVAudioEngine()
        player = nil
        format = nil
        cache.removeAll()
        rebuilds += 1
    }

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
        prepareEngine()
        guard let player, engine.isRunning, let buffer = buffer(for: cue) else { return }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
}
