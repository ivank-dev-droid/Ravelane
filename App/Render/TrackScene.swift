import Foundation
import QuartzCore
import RealityKit
import UIKit
import SwiftUI
import simd
import RavelaneCore

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
    private let sky = SkyBuilder.dome()
    private let grid = SkyBuilder.grid()
    private let pulse = ModelEntity()
    private let effects = EffectField()
    private var coreHalos: [ModelEntity] = []
    private var gateFlashes: [ModelEntity] = []
    private var spinners: [ModelEntity] = []
    private var coreBeams: [ModelEntity] = []
    private var collectedSnapshot: [Bool] = []
    private var lastTimestamp: Double?
    private let carBody = ModelEntity()
    private let carWheels = ModelEntity()
    private let underglow = Billboard.entity(sprite: "GlowCold", tint: Palette.cold, size: 6, opacity: 0.5)
    private var fittedCar: String?

    init() {
        root.addChild(effects.root)
        root.addChild(sky)
        root.addChild(grid)
        if let mesh = RibbonMesh.chevronMesh() {
            pulse.model = ModelComponent(mesh: mesh, materials: [Surfaces.pulse])
        }
        pulse.isEnabled = false
        root.addChild(pulse)
        root.addChild(ribbon)
        root.addChild(edges)
        root.addChild(car)
        root.addChild(ghost)
        root.addChild(camera)

        camera.camera.fieldOfViewInDegrees = 62
        camera.camera.near = 0.4
        camera.camera.far = 4000

        car.addChild(carBody)
        car.addChild(carWheels)
        car.addChild(underglow)
        underglow.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        underglow.position = SIMD3<Float>(0, -0.55, 0)
        ghost.model = ModelComponent(
            mesh: .generateBox(size: SIMD3<Float>(0.1, 0.1, 0.1)),
            materials: [Palette.ghostMaterial(safe: true)]
        )
        ghost.isEnabled = false

        let key = DirectionalLight()
        key.light.intensity = 3200
        key.light.color = Palette.colour(SIMD3<Float>(1.0, 0.94, 0.86))
        key.orientation = simd_quatf(angle: -.pi / 3, axis: SIMD3<Float>(1, 0, 0))
        root.addChild(key)

        let fill = DirectionalLight()
        fill.light.intensity = 1100
        fill.light.color = Palette.colour(Palette.blue)
        fill.orientation = simd_quatf(angle: .pi / 2.6, axis: SIMD3<Float>(0.4, 1, 0))
        root.addChild(fill)

        let rim = DirectionalLight()
        rim.light.intensity = 1600
        rim.light.color = Palette.colour(Palette.neon)
        rim.orientation = simd_quatf(angle: .pi * 0.85, axis: SIMD3<Float>(0.2, 1, 0.1))
        root.addChild(rim)
    }

    func rebuildIfNeeded(model: SessionViewModel) {
        guard model.trackRevision != builtRevision else { return }
        builtRevision = model.trackRevision
        rebuildTrack(chain: model.session.chain)
        rebuildLevelProps(level: model.level, session: model.session)
    }

    private func rebuildTrack(chain: TrackChain) {
        if let mesh = RibbonMesh.generate(from: chain) {
            ribbon.model = ModelComponent(mesh: mesh, materials: [Surfaces.ribbon])
        }
        if let mesh = RibbonMesh.edgeMesh(from: chain) {
            edges.model = ModelComponent(mesh: mesh, materials: [Palette.edgeMaterial])
        }
    }

    private func rebuildLevelProps(level: Level, session: Session) {
        for entity in coreEntities { entity.removeFromParent() }
        for entity in gateEntities { entity.removeFromParent() }
        for entity in coreHalos { entity.removeFromParent() }
        coreEntities.removeAll()
        gateEntities.removeAll()
        coreHalos.removeAll()
        spinners.removeAll()
        coreBeams.removeAll()
        gateFlashes.removeAll()

        for (index, core) in level.cores.enumerated() {
            let taken = index < session.objectives.coresCollected.count
                && session.objectives.coresCollected[index]
            let entity = ModelEntity()
            if let mesh = Props.crystal(radius: 2.6) {
                entity.model = ModelComponent(mesh: mesh,
                                              materials: [taken ? Props.spentMaterial : Props.crystalMaterial])
            }
            entity.position = core.position.simd
            root.addChild(entity)
            coreEntities.append(entity)
            spinners.append(entity)

            let halo = Billboard.entity(sprite: "GlowGold", tint: Palette.gold,
                                        size: taken ? 5 : 14, opacity: taken ? 0.12 : 0.55)
            halo.position = core.position.simd
            root.addChild(halo)
            coreHalos.append(halo)

            let beam = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.5, 110, 0.5)),
                materials: [Palette.coreBeaconMaterial]
            )
            beam.position = core.position.simd + SIMD3<Float>(0, 53, 0)
            beam.isEnabled = !taken
            root.addChild(beam)
            coreEntities.append(beam)
            coreBeams.append(beam)
        }

        let gates = level.objectiveOrder
        for (index, gate) in gates.enumerated() {
            let isGoal = index == gates.count - 1
            let radius = gate.radius.float
            let ring = ModelEntity()
            if let mesh = Props.torus(major: radius, minor: isGoal ? 1.1 : 0.75) {
                ring.model = ModelComponent(mesh: mesh, materials: [Props.ringMaterial(goal: isGoal)])
            }
            ring.position = gate.position.simd + SIMD3<Float>(0, Float(Core.hoverHeight.approximateDouble) + radius * 0.5, 0)
            root.addChild(ring)
            gateEntities.append(ring)

            let flash = Billboard.entity(sprite: "RingFlash",
                                         tint: isGoal ? Palette.gold : Palette.cold,
                                         size: radius * 2.6,
                                         opacity: 0.4)
            flash.position = ring.position
            root.addChild(flash)
            gateEntities.append(flash)
            gateFlashes.append(flash)

            let beacon = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(1.2, 400, 1.2)),
                materials: [isGoal ? Palette.goalBeaconMaterial : Palette.beaconMaterial]
            )
            beacon.position = gate.position.simd + SIMD3<Float>(0, 150, 0)
            root.addChild(beacon)
            gateEntities.append(beacon)
        }
    }

    private func fitCar() {
        let selected = GameSettings.shared.selectedCar
        guard fittedCar != selected else { return }
        fittedCar = selected
        let spec = CarCatalog.spec(CarID(selected)) ?? CarCatalog.starting
        if let mesh = CarMesh.body(spec: spec) {
            carBody.model = ModelComponent(mesh: mesh, materials: [CarMesh.bodyMaterial(spec: spec)])
        }
        if let mesh = CarMesh.wheels(spec: spec) {
            carWheels.model = ModelComponent(mesh: mesh, materials: [CarMesh.wheelMaterial])
        }
        underglow.model?.materials = [
            Billboard.material(sprite: "GlowCold", tint: CarMesh.tint(for: spec), opacity: 0.5)
        ]
    }

    func update(model: SessionViewModel) {
        rebuildIfNeeded(model: model)
        fitCar()

        let frame = model.carFrame
        car.position = frame.position.simd + frame.up.simd * 0.6
        car.orientation = frame.rotation.simd

        let runway = model.clocks.runway.float
        let dial = Float(GameSettings.shared.cameraPullback)
        let pullBack = min(46, 14 + runway * 0.05) * dial
        let lift = min(20, 6 + runway * 0.02) * dial
        let eye = frame.position.simd - frame.forward.simd * pullBack + SIMD3<Float>(0, lift, 0)
        camera.position = eye
        camera.look(at: frame.position.simd + frame.forward.simd * 18,
                    from: eye,
                    relativeTo: nil)

        let now = CACurrentMediaTime()
        let delta = Float(min(0.05, max(0.001, now - (lastTimestamp ?? now - 1.0 / 60))))
        lastTimestamp = now

        updatePulse(model: model)
        updateCollectibles(model: model, delta: delta, now: now, eye: eye)
        effects.update(delta: delta, eye: eye)

        sky.position = eye
        grid.position = SIMD3<Float>(
            SkyBuilder.snap(frame.position.simd.x, to: SkyBuilder.gridSpacing),
            frame.position.simd.y - SkyBuilder.gridDrop,
            SkyBuilder.snap(frame.position.simd.z, to: SkyBuilder.gridSpacing)
        )
    }

    private func updateCollectibles(model: SessionViewModel, delta: Float, now: Double, eye: SIMD3<Float>) {
        let spin = simd_quatf(angle: Float(now.truncatingRemainder(dividingBy: 6.2831)) * 0.9,
                              axis: SIMD3<Float>(0, 1, 0))
        let bob = sin(Float(now.truncatingRemainder(dividingBy: 6.2831)) * 1.7) * 0.6
        for spinner in spinners {
            spinner.orientation = spin
        }

        let breath = 1 + sin(Float(now.truncatingRemainder(dividingBy: 6.2831)) * 2.3) * 0.12
        for (index, halo) in coreHalos.enumerated() {
            halo.scale = SIMD3<Float>(repeating: breath)
            Billboard.face(halo, towards: eye)
            if index < spinners.count {
                spinners[index].position.y = coreHalos[index].position.y + bob
            }
        }

        for flash in gateFlashes {
            Billboard.face(flash, towards: eye)
        }

        let collected = model.session.objectives.coresCollected
        if collectedSnapshot.count != collected.count {
            collectedSnapshot = collected
        } else {
            for index in collected.indices where collected[index] && !collectedSnapshot[index] {
                if index < coreHalos.count {
                    effects.burst(at: coreHalos[index].position,
                                  tint: Palette.gold,
                                  sprite: "GlowGold",
                                  count: 12,
                                  spread: 22)
                }
                if index < spinners.count {
                    spinners[index].model?.materials = [Props.spentMaterial]
                }
                if index < coreBeams.count {
                    coreBeams[index].isEnabled = false
                }
                if index < coreHalos.count {
                    coreHalos[index].model?.materials = [
                        Billboard.material(sprite: "GlowGold", tint: Palette.gold, opacity: 0.1)
                    ]
                }
            }
            collectedSnapshot = collected
        }
    }

    private func updatePulse(model: SessionViewModel) {
        guard model.isRunning else {
            pulse.isEnabled = false
            return
        }
        let travelled = model.session.car.distanceTravelled.approximateDouble
        let phase = CACurrentMediaTime().truncatingRemainder(dividingBy: 2.4) / 2.4
        let ahead = 16 + phase * 130
        guard let sample = model.session.chain.sample(atArcLength: Fixed(approximating: travelled + ahead)) else {
            pulse.isEnabled = false
            return
        }
        pulse.isEnabled = true
        pulse.position = sample.frame.position.simd + sample.normal.simd * 0.4
        pulse.orientation = sample.frame.rotation.simd
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

    static var goalMaterial: RealityKit.Material {
        UnlitMaterial(color: colour(gold))
    }

    static var beaconMaterial: RealityKit.Material {
        var material = UnlitMaterial(color: colour(blue, alpha: 0.22))
        material.blending = .transparent(opacity: 0.22)
        return material
    }

    static var goalBeaconMaterial: RealityKit.Material {
        var material = UnlitMaterial(color: colour(gold, alpha: 0.3))
        material.blending = .transparent(opacity: 0.3)
        return material
    }

    static var coreBeaconMaterial: RealityKit.Material {
        var material = UnlitMaterial(color: colour(gold, alpha: 0.16))
        material.blending = .transparent(opacity: 0.16)
        return material
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
