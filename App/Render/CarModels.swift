import Foundation
import RealityKit
import simd
import RavelaneCore

@MainActor
enum CarModels {
    struct Build {
        var asset: String
        var length: Float
        var width: Float
    }

    static func build(for id: CarID) -> Build {
        switch id.rawValue {
        case "shim", "sliver", "cinder":
            return Build(asset: "car_needle", length: 5.4, width: 1.9)
        case "ballast", "anvil", "burr":
            return Build(asset: "car_hauler", length: 4.4, width: 2.4)
        case "kite", "loom":
            return Build(asset: "car_glider", length: 4.8, width: 2.6)
        default:
            return Build(asset: "car_hero", length: 4.6, width: 2.1)
        }
    }

    private static var cache: [String: Entity] = [:]

    private static func prototype(_ name: String) -> Entity? {
        if let existing = cache[name] { return existing }
        guard let loaded = try? Entity.load(named: name) else { return nil }
        cache[name] = loaded
        return loaded
    }

    static func entity(for spec: CarSpec, drop: Float) -> Entity? {
        let build = build(for: spec.id)
        guard let prototype = prototype(build.asset) else { return nil }

        let shape = CarMesh.Shape(spec: spec)
        let along = shape.length / build.length
        let across = min(1.25, max(0.82, shape.width / build.width))

        let holder = Entity()
        holder.addChild(prototype.clone(recursive: true))
        holder.scale = SIMD3<Float>(along * across, along, along)
        holder.position = SIMD3<Float>(0, drop, 0)
        return holder
    }
}
