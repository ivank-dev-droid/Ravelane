import Foundation
import RealityKit
import simd
import RavelaneCore

enum RibbonMesh {
    static let edgeLift: Float = 0.35

    static func generate(from chain: TrackChain, stride: Fixed = Fixed(2)) -> MeshResource? {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        var cursor = Fixed.zero
        var rows = 0
        let total = chain.totalLength
        guard total.raw > 0 else { return nil }

        while cursor <= total {
            guard let sample = chain.sample(atArcLength: cursor) else { break }
            let halfWidth = chain.width(atArcLength: cursor) / Fixed(2)
            let centre = sample.frame.position.simd
            let lateral = sample.lateral.simd
            let up = sample.normal.simd
            let half = halfWidth.float

            positions.append(centre - lateral * half)
            positions.append(centre + lateral * half)
            normals.append(up)
            normals.append(up)
            let v = cursor.float / 8
            uvs.append(SIMD2<Float>(0, v))
            uvs.append(SIMD2<Float>(1, v))
            rows += 1
            cursor += stride
        }

        guard rows >= 2 else { return nil }

        for row in 0..<(rows - 1) {
            let a = UInt32(row * 2)
            let b = a + 1
            let c = a + 2
            let d = a + 3
            indices.append(contentsOf: [a, c, b, b, c, d])
            indices.append(contentsOf: [b, c, a, d, c, b])
        }

        var descriptor = MeshDescriptor(name: "ribbon")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)

        return try? MeshResource.generate(from: [descriptor])
    }

    static func edgeMesh(from chain: TrackChain, stride: Fixed = Fixed(2)) -> MeshResource? {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        var cursor = Fixed.zero
        var rows = 0
        let total = chain.totalLength
        guard total.raw > 0 else { return nil }

        while cursor <= total {
            guard let sample = chain.sample(atArcLength: cursor) else { break }
            let halfWidth = (chain.width(atArcLength: cursor) / Fixed(2)).float
            let centre = sample.frame.position.simd
            let lateral = sample.lateral.simd
            let up = sample.normal.simd

            positions.append(centre - lateral * halfWidth)
            positions.append(centre - lateral * halfWidth + up * edgeLift)
            positions.append(centre + lateral * halfWidth)
            positions.append(centre + lateral * halfWidth + up * edgeLift)
            for _ in 0..<4 { normals.append(up) }
            rows += 1
            cursor += stride
        }

        guard rows >= 2 else { return nil }

        for row in 0..<(rows - 1) {
            let base = UInt32(row * 4)
            let next = base + 4
            indices.append(contentsOf: [base, next, base + 1, base + 1, next, next + 1])
            indices.append(contentsOf: [base + 2, base + 3, next + 2, base + 3, next + 3, next + 2])
        }

        var descriptor = MeshDescriptor(name: "ribbonEdge")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }
}
