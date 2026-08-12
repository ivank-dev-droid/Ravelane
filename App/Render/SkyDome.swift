import Foundation
import RealityKit
import simd

@MainActor
enum SkyBuilder {
    static let domeRadius: Float = 1200

    static func dome() -> ModelEntity {
        let entity = ModelEntity()
        guard let mesh = domeMesh(rings: 32, segments: 64) else { return entity }

        var material = UnlitMaterial(color: Palette.colour(SIMD3<Float>(0.10, 0.05, 0.20)))
        if let texture = try? TextureResource.load(named: "SkyDome") {
            material.color = .init(tint: .white, texture: .init(texture))
        }
        material.faceCulling = .none

        entity.model = ModelComponent(mesh: mesh, materials: [material])
        return entity
    }

    private static func domeMesh(rings: Int, segments: Int) -> MeshResource? {
        var positions: [SIMD3<Float>] = []
        var coordinates: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        for ring in 0...rings {
            let v = Float(ring) / Float(rings)
            let theta = v * .pi
            let y = cos(theta)
            let radial = sin(theta)
            for segment in 0...segments {
                let u = Float(segment) / Float(segments)
                let phi = u * 2 * .pi
                positions.append(SIMD3<Float>(radial * sin(phi), y, radial * cos(phi)) * domeRadius)
                coordinates.append(SIMD2<Float>(u, v))
            }
        }

        let stride = segments + 1
        for ring in 0..<rings {
            for segment in 0..<segments {
                let a = UInt32(ring * stride + segment)
                let b = a + 1
                let c = UInt32((ring + 1) * stride + segment)
                let d = c + 1
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }

        var descriptor = MeshDescriptor(name: "skydome")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(coordinates)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    static let gridSpacing: Float = 40
    static let gridExtent: Float = 720
    static let gridDrop: Float = 150

    static func grid() -> ModelEntity {
        let entity = ModelEntity()
        guard let mesh = gridMesh() else { return entity }
        var material = UnlitMaterial(color: Palette.colour(Palette.neon, alpha: 0.20))
        material.blending = .transparent(opacity: 0.20)
        material.faceCulling = .none
        entity.model = ModelComponent(mesh: mesh, materials: [material])
        return entity
    }

    private static func gridMesh() -> MeshResource? {
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let half = Float(0.35)
        let count = Int(gridExtent / gridSpacing)

        func line(from start: SIMD3<Float>, to end: SIMD3<Float>, lateral: SIMD3<Float>) {
            let base = UInt32(positions.count)
            positions.append(start - lateral * half)
            positions.append(start + lateral * half)
            positions.append(end - lateral * half)
            positions.append(end + lateral * half)
            indices.append(contentsOf: [base, base + 2, base + 1, base + 1, base + 2, base + 3])
        }

        for step in -count...count {
            let offset = Float(step) * gridSpacing
            line(from: SIMD3<Float>(offset, 0, -gridExtent),
                 to: SIMD3<Float>(offset, 0, gridExtent),
                 lateral: SIMD3<Float>(1, 0, 0))
            line(from: SIMD3<Float>(-gridExtent, 0, offset),
                 to: SIMD3<Float>(gridExtent, 0, offset),
                 lateral: SIMD3<Float>(0, 0, 1))
        }

        var descriptor = MeshDescriptor(name: "grid")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    static func snap(_ value: Float, to spacing: Float) -> Float {
        (value / spacing).rounded() * spacing
    }
}
