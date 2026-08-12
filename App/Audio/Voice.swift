import Foundation

struct Partial {
    var ratio: Double
    var level: Double
    var decay: Double
}

struct Voice {
    var root: Double
    var glide: Double
    var duration: Double
    var level: Double
    var partials: [Partial]
    var noise: Double
    var noiseDecay: Double
    var attack: Double
    var shimmer: Double

    init(
        root: Double,
        glide: Double = 1,
        duration: Double,
        level: Double,
        partials: [Partial],
        noise: Double = 0,
        noiseDecay: Double = 12,
        attack: Double = 0.004,
        shimmer: Double = 0
    ) {
        self.root = root
        self.glide = glide
        self.duration = duration
        self.level = level
        self.partials = partials
        self.noise = noise
        self.noiseDecay = noiseDecay
        self.attack = attack
        self.shimmer = shimmer
    }

    func render(sampleRate: Double, into channel: UnsafeMutablePointer<Float>, frames: Int) {
        var seed: UInt64 = 0x9E3779B97F4A7C15
        var phases = [Double](repeating: 0, count: partials.count)

        for index in 0..<frames {
            let time = Double(index) / sampleRate
            let progress = time / duration
            let bend = pow(glide, progress)

            var value = 0.0
            for (slot, partial) in partials.enumerated() {
                let frequency = root * partial.ratio * bend
                phases[slot] += 2 * .pi * frequency / sampleRate
                let decay = exp(-partial.decay * progress)
                value += sin(phases[slot]) * partial.level * decay
            }

            if noise > 0 {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let random = Double(Int64(bitPattern: seed >> 11)) / Double(1 << 52) - 1
                value += random * noise * exp(-noiseDecay * progress)
            }

            if shimmer > 0 {
                value *= 1 + sin(2 * .pi * 7.5 * time) * shimmer
            }

            let rise = min(1, time / max(0.0005, attack))
            let fall = pow(max(0, 1 - progress), 1.7)
            channel[index] = Float(value * rise * fall * level)
        }
    }
}

enum VoiceBank {
    static func voice(for cue: Feedback.Cue) -> Voice {
        switch cue {
        case .place:
            return Voice(
                root: 392, glide: 1.5, duration: 0.16, level: 0.20,
                partials: [Partial(ratio: 1, level: 0.6, decay: 3.2),
                           Partial(ratio: 2, level: 0.28, decay: 5.0),
                           Partial(ratio: 3.01, level: 0.12, decay: 7.0)],
                noise: 0.10, noiseDecay: 40
            )
        case .discard:
            return Voice(
                root: 300, glide: 0.62, duration: 0.15, level: 0.16,
                partials: [Partial(ratio: 1, level: 0.5, decay: 4.5),
                           Partial(ratio: 1.5, level: 0.2, decay: 6.0)],
                noise: 0.08, noiseDecay: 26
            )
        case .reject:
            return Voice(
                root: 150, glide: 0.9, duration: 0.22, level: 0.20,
                partials: [Partial(ratio: 1, level: 0.5, decay: 2.4),
                           Partial(ratio: 1.06, level: 0.4, decay: 2.4),
                           Partial(ratio: 2.4, level: 0.12, decay: 6.0)],
                noise: 0.05, noiseDecay: 14
            )
        case .core:
            return Voice(
                root: 784, glide: 1.34, duration: 0.30, level: 0.20,
                partials: [Partial(ratio: 1, level: 0.5, decay: 2.0),
                           Partial(ratio: 1.5, level: 0.3, decay: 2.6),
                           Partial(ratio: 2, level: 0.22, decay: 3.4),
                           Partial(ratio: 4, level: 0.10, decay: 5.0)],
                shimmer: 0.10
            )
        case .checkpoint:
            return Voice(
                root: 523, glide: 1.26, duration: 0.34, level: 0.21,
                partials: [Partial(ratio: 1, level: 0.5, decay: 1.6),
                           Partial(ratio: 1.5, level: 0.34, decay: 2.2),
                           Partial(ratio: 2, level: 0.18, decay: 3.0)],
                shimmer: 0.06
            )
        case .land:
            return Voice(
                root: 132, glide: 0.86, duration: 0.24, level: 0.26,
                partials: [Partial(ratio: 1, level: 0.6, decay: 5.0),
                           Partial(ratio: 1.98, level: 0.2, decay: 8.0)],
                noise: 0.30, noiseDecay: 30, attack: 0.001
            )
        case .crash:
            return Voice(
                root: 88, glide: 0.55, duration: 0.62, level: 0.32,
                partials: [Partial(ratio: 1, level: 0.55, decay: 2.4),
                           Partial(ratio: 1.41, level: 0.30, decay: 3.0),
                           Partial(ratio: 2.13, level: 0.18, decay: 4.0)],
                noise: 0.55, noiseDecay: 6, attack: 0.001
            )
        case .win:
            return Voice(
                root: 523, glide: 2.0, duration: 0.85, level: 0.26,
                partials: [Partial(ratio: 1, level: 0.44, decay: 1.0),
                           Partial(ratio: 1.26, level: 0.30, decay: 1.2),
                           Partial(ratio: 1.5, level: 0.26, decay: 1.4),
                           Partial(ratio: 2, level: 0.20, decay: 1.8),
                           Partial(ratio: 3, level: 0.10, decay: 2.6)],
                attack: 0.012, shimmer: 0.08
            )
        }
    }
}
