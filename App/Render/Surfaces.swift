import Foundation
import Metal
import RealityKit

@MainActor
enum Surfaces {
    private static var cache: [String: TextureResource] = [:]

    static func texture(_ name: String) -> TextureResource? {
        if let existing = cache[name] { return existing }
        guard let loaded = try? TextureResource.load(named: name) else { return nil }
        cache[name] = loaded
        return loaded
    }

    static let repeatSampler: MaterialParameters.Texture.Sampler = {
        let descriptor = MTLSamplerDescriptor()
        descriptor.sAddressMode = .repeat
        descriptor.tAddressMode = .repeat
        descriptor.magFilter = .linear
        descriptor.minFilter = .linear
        descriptor.mipFilter = .linear
        descriptor.maxAnisotropy = 8
        return MaterialParameters.Texture.Sampler(descriptor)
    }()

    static func tiled(_ name: String) -> MaterialParameters.Texture? {
        guard let resource = texture(name) else { return nil }
        return MaterialParameters.Texture(resource, sampler: repeatSampler)
    }

    static var ribbon: RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        let surface = tiled("RoadBase")
        material.baseColor = .init(
            tint: Palette.colour(surface == nil ? SIMD3<Float>(0.09, 0.06, 0.15)
                                                : SIMD3<Float>(0.82, 0.80, 0.88)),
            texture: surface
        )
        material.roughness = 0.46
        material.metallic = 0.2
        if let normal = tiled("RoadNormal") {
            material.normal = .init(texture: normal)
        }
        if let glow = tiled("RoadEmissive") {
            material.emissiveColor = .init(color: Palette.colour(SIMD3<Float>(1, 1, 1)), texture: glow)
            material.emissiveIntensity = 0.9
        } else {
            material.emissiveIntensity = 0
        }
        return material
    }

    static var pulse: RealityKit.Material {
        var material = UnlitMaterial(color: Palette.colour(Palette.cold, alpha: 0.55))
        material.blending = .transparent(opacity: 0.55)
        material.faceCulling = .none
        return material
    }
}
