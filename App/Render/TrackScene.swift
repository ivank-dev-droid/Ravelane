import Foundation
import RealityKit
import UIKit
import SwiftUI
import simd
import RavelinCore

@MainActor
final class TrackScene {
    let root = Entity()
    private let ribbon = ModelEntity()
    private let edges = ModelEntity()
    private let car = ModelEntity()
    private let ghost = ModelEntity()
    private let camera = PerspectiveCamera()
    private var coreEntities: [ModelEntity] = []
    private var gateEntities: [ModelEntity] = []
    private var builtRevision = -1

    init() {
        root.addChild(ribbon)
        root.addChild(edges)
        root.addChild(car)
        root.addChild(ghost)
        root.addChild(camera)

        camera.camera.fieldOfViewInDegrees = 62

        car.model = ModelComponent(
            mesh: .generateBox(size: SIMD3<Float>(1.6, 0.8, 3.2), cornerRadius: 0.25),
            materials: [Palette.carMaterial]
        )
        ghost.model = ModelComponent(
            mesh: .generateBox(size: SIMD3<Float>(0.1, 0.1, 0.1)),
            materials: [Palette.ghostMaterial(safe: true)]
        )
        ghost.isEnabled = false

        let light = DirectionalLight()
        light.light.intensity = 2600
        light.light.color = .white
        light.orientation = simd_quatf(angle: -.pi / 3, axis: SIMD3<Float>(1, 0, 0))
        root.addChild(light)
    }

    func rebuildIfNeeded(model: SessionViewModel) {
        guard model.trackRevision != builtRevision else { return }
        builtRevision = model.trackRevision
        rebuildTrack(chain: model.session.chain)
        rebuildLevelProps(level: model.level, session: model.session)
    }

    private func rebuildTrack(chain: TrackChain) {
        if let mesh = RibbonMesh.generate(from: chain) {
            ribbon.model = ModelComponent(mesh: mesh, materials: [Palette.ribbonMaterial])
        }
        if let mesh = RibbonMesh.edgeMesh(from: chain) {
            edges.model = ModelComponent(mesh: mesh, materials: [Palette.edgeMaterial])
        }
    }

    private func rebuildLevelProps(level: Level, session: Session) {
        for entity in coreEntities { entity.removeFromParent() }
        for entity in gateEntities { entity.removeFromParent() }
        coreEntities.removeAll()
        gateEntities.removeAll()

        for (index, core) in level.cores.enumerated() {
            let taken = index < session.objectives.coresCollected.count
                && session.objectives.coresCollected[index]
            let entity = ModelEntity(
                mesh: .generateSphere(radius: 1.4),
                materials: [Palette.coreMaterial(collected: taken)]
            )
            entity.position = core.position.simd
            root.addChild(entity)
            coreEntities.append(entity)
        }

        for gate in level.objectiveOrder {
            let entity = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(gate.radius.float * 2, 0.6, 0.6), cornerRadius: 0.3),
                materials: [Palette.gateMaterial]
            )
            entity.position = gate.position.simd + SIMD3<Float>(0, gate.radius.float, 0)
            root.addChild(entity)
            gateEntities.append(entity)
        }
    }

    func update(model: SessionViewModel) {
        rebuildIfNeeded(model: model)

        let frame = model.carFrame
        car.position = frame.position.simd + frame.up.simd * 0.6
        car.orientation = frame.rotation.simd

        let runway = model.clocks.runway.float
        let pullBack = min(34, 14 + runway * 0.05)
        let lift = min(16, 6 + runway * 0.02)
        let eye = frame.position.simd - frame.forward.simd * pullBack + SIMD3<Float>(0, lift, 0)
        camera.position = eye
        camera.look(at: frame.position.simd + frame.forward.simd * 18,
                    from: eye,
                    relativeTo: nil)
    }

    func showGhost(samples: [RibbonSample], safe: Bool) {
        guard samples.count > 1 else {
            ghost.isEnabled = false
            return
        }
        var descriptor = MeshDescriptor(name: "ghost")
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for (index, sample) in samples.enumerated() {
            let half = Float(3.6)
            positions.append(sample.frame.position.simd - sample.lateral.simd * half)
            positions.append(sample.frame.position.simd + sample.lateral.simd * half)
            if index > 0 {
                let base = UInt32((index - 1) * 2)
                indices.append(contentsOf: [base, base + 2, base + 1, base + 1, base + 2, base + 3])
                indices.append(contentsOf: [base + 1, base + 2, base, base + 3, base + 2, base + 1])
            }
        }
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)
        if let mesh = try? MeshResource.generate(from: [descriptor]) {
            ghost.model = ModelComponent(mesh: mesh, materials: [Palette.ghostMaterial(safe: safe)])
            ghost.isEnabled = true
        }
    }

    func hideGhost() { ghost.isEnabled = false }
}

enum Palette {
    static let void = SIMD3<Float>(0.043, 0.016, 0.094)
    static let neon = SIMD3<Float>(0.706, 0.294, 1.0)
    static let blue = SIMD3<Float>(0.180, 0.482, 1.0)
    static let gold = SIMD3<Float>(1.0, 0.761, 0.294)
    static let alarm = SIMD3<Float>(1.0, 0.239, 0.431)
    static let cold = SIMD3<Float>(0.294, 0.890, 1.0)

    static func colour(_ rgb: SIMD3<Float>, alpha: Float = 1) -> UnlitMaterial.Color {
        UnlitMaterial.Color(red: CGFloat(rgb.x), green: CGFloat(rgb.y),
                            blue: CGFloat(rgb.z), alpha: CGFloat(alpha))
    }

    static var ribbonMaterial: RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: colour(SIMD3<Float>(0.10, 0.05, 0.20)))
        material.roughness = 0.35
        material.metallic = 0.1
        material.emissiveColor = .init(color: colour(neon * 0.25))
        material.emissiveIntensity = 0.6
        return material
    }

    static var edgeMaterial: RealityKit.Material {
        UnlitMaterial(color: colour(neon))
    }

    static var carMaterial: RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: colour(SIMD3<Float>(0.9, 0.95, 1.0)))
        material.metallic = 0.9
        material.roughness = 0.2
        material.emissiveColor = .init(color: colour(cold))
        material.emissiveIntensity = 0.4
        return material
    }

    static var gateMaterial: RealityKit.Material {
        UnlitMaterial(color: colour(blue, alpha: 0.85))
    }

    static func coreMaterial(collected: Bool) -> RealityKit.Material {
        UnlitMaterial(color: colour(collected ? SIMD3<Float>(0.25, 0.25, 0.3) : gold))
    }

    static func ghostMaterial(safe: Bool) -> RealityKit.Material {
        var material = UnlitMaterial(color: colour(safe ? cold : alarm, alpha: 0.45))
        material.blending = .transparent(opacity: 0.45)
        return material
    }
}
