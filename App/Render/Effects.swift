import Foundation
import RealityKit
import simd

@MainActor
enum Billboard {
    static func quad(size: Float) -> MeshResource? {
        let half = size / 2
        var descriptor = MeshDescriptor(name: "billboard")
        descriptor.positions = MeshBuffers.Positions([
            SIMD3<Float>(-half, -half, 0),
            SIMD3<Float>(half, -half, 0),
            SIMD3<Float>(-half, half, 0),
            SIMD3<Float>(half, half, 0)
        ])
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates([
            SIMD2<Float>(0, 1), SIMD2<Float>(1, 1),
            SIMD2<Float>(0, 0), SIMD2<Float>(1, 0)
        ])
        descriptor.primitives = .triangles([0, 1, 2, 2, 1, 3])
        return try? MeshResource.generate(from: [descriptor])
    }

    static func material(sprite: String, tint: SIMD3<Float>, opacity: Float) -> RealityKit.Material {
        var material = UnlitMaterial(color: Palette.colour(tint))
        if let texture = Surfaces.texture(sprite) {
            material.color = .init(tint: Palette.colour(tint), texture: .init(texture))
        }
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        material.faceCulling = .none
        return material
    }

    static func entity(sprite: String, tint: SIMD3<Float>, size: Float, opacity: Float) -> ModelEntity {
        let entity = ModelEntity()
        if let mesh = quad(size: size) {
            entity.model = ModelComponent(mesh: mesh,
                                          materials: [material(sprite: sprite, tint: tint, opacity: opacity)])
        }
        return entity
    }

    static func face(_ entity: Entity, towards eye: SIMD3<Float>) {
        let delta = eye - entity.position
        guard length_squared(delta) > 0.0001 else { return }
        entity.look(at: eye, from: entity.position, relativeTo: nil)
    }
}

@MainActor
final class EffectField {
    let root = Entity()

    private struct Spark {
        var entity: ModelEntity
        var velocity: SIMD3<Float>
        var life: Float
        var span: Float
        var size: Float
    }

    private var sparks: [Spark] = []
    private var idle: [ModelEntity] = []
    private let capacity = 40

    init() {
        for _ in 0..<capacity {
            let entity = Billboard.entity(sprite: "GlowGold", tint: Palette.gold, size: 1, opacity: 0.9)
            entity.isEnabled = false
            root.addChild(entity)
            idle.append(entity)
        }
    }

    func burst(at position: SIMD3<Float>, tint: SIMD3<Float>, sprite: String, count: Int, spread: Float) {
        for index in 0..<count {
            guard let entity = idle.popLast() else { return }
            let angle = Float(index) / Float(count) * 2 * .pi
            let tilt = Float(index % 5) / 5 * 1.4 - 0.7
            let direction = SIMD3<Float>(cos(angle) * cos(tilt), sin(tilt), sin(angle) * cos(tilt))
            entity.model?.materials = [Billboard.material(sprite: sprite, tint: tint, opacity: 0.95)]
            entity.position = position
            entity.scale = .one
            entity.isEnabled = true
            sparks.append(Spark(entity: entity,
                                velocity: direction * spread,
                                life: 0,
                                span: 0.55 + Float(index % 4) * 0.12,
                                size: 3.4))
        }
    }

    func update(delta: Float, eye: SIMD3<Float>) {
        var survivors: [Spark] = []
        survivors.reserveCapacity(sparks.count)
        for var spark in sparks {
            spark.life += delta
            if spark.life >= spark.span {
                spark.entity.isEnabled = false
                idle.append(spark.entity)
                continue
            }
            let progress = spark.life / spark.span
            spark.entity.position += spark.velocity * delta
            spark.velocity *= 0.94
            let scale = spark.size * (1 - progress * progress)
            spark.entity.scale = SIMD3<Float>(repeating: max(0.02, scale))
            Billboard.face(spark.entity, towards: eye)
            survivors.append(spark)
        }
        sparks = survivors
    }
}
