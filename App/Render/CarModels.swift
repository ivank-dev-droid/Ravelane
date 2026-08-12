import Foundation
import RealityKit
import simd
import RavelaneCore

@MainActor
enum CarModels {
    private static var cache: [String: Entity] = [:]

    static func assetName(for id: CarID) -> String { "model_\(id.rawValue)" }

    private static func prototype(_ name: String) -> Entity? {
        if let existing = cache[name] { return existing }
        guard let loaded = try? Entity.load(named: name) else { return nil }
        cache[name] = loaded
        return loaded
    }

    static func entity(for spec: CarSpec, drop: Float) -> Entity? {
        let prototype = prototype(assetName(for: spec.id)) ?? prototype(assetName(for: CarCatalog.starting.id))
        guard let prototype else { return nil }
        let holder = Entity()
        holder.addChild(prototype.clone(recursive: true))
        holder.position = SIMD3<Float>(0, drop, 0)
        return holder
    }
}
