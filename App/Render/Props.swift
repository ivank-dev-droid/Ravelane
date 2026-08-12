import Foundation
import RealityKit
import simd

@MainActor
enum Props {
    static func torus(major: Float, minor: Float, majorSegments: Int = 48, minorSegments: Int = 10) -> MeshResource? {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for ring in 0...majorSegments {
            let phi = Float(ring) / Float(majorSegments) * 2 * .pi
            let centre = SIMD3<Float>(cos(phi) * major, sin(phi) * major, 0)
            let outward = SIMD3<Float>(cos(phi), sin(phi), 0)
            for tube in 0...minorSegments {
                let theta = Float(tube) / Float(minorSegments) * 2 * .pi
                let normal = outward * cos(theta) + SIMD3<Float>(0, 0, 1) * sin(theta)
                positions.append(centre + normal * minor)
                normals.append(normal)
            }
        }

        let stride = minorSegments + 1
        for ring in 0..<majorSegments {
            for tube in 0..<minorSegments {
                let a = UInt32(ring * stride + tube)
                let b = a + 1
                let c = UInt32((ring + 1) * stride + tube)
                let d = c + 1
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }

        var descriptor = MeshDescriptor(name: "torus")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    static func crystal(radius: Float, waist: Float = 0.55) -> MeshResource? {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let sides = 6

        let top = SIMD3<Float>(0, radius, 0)
        let bottom = SIMD3<Float>(0, -radius, 0)
        var belt: [SIMD3<Float>] = []
        for side in 0..<sides {
            let angle = Float(side) / Float(sides) * 2 * .pi
            belt.append(SIMD3<Float>(cos(angle) * radius * waist, 0, sin(angle) * radius * waist))
        }

        func facet(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
            let normal = normalize(cross(b - a, c - a))
            let base = UInt32(positions.count)
            positions.append(contentsOf: [a, b, c])
            normals.append(contentsOf: [normal, normal, normal])
            indices.append(contentsOf: [base, base + 1, base + 2])
        }

        for side in 0..<sides {
            let current = belt[side]
            let next = belt[(side + 1) % sides]
            facet(top, current, next)
            facet(bottom, next, current)
        }

        var descriptor = MeshDescriptor(name: "crystal")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    static var crystalMaterial: RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: Palette.colour(Palette.gold))
        material.metallic = 1.0
        material.roughness = 0.12
        material.emissiveColor = .init(color: Palette.colour(Palette.gold))
        material.emissiveIntensity = 3.0
        return material
    }

    static var spentMaterial: RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: Palette.colour(SIMD3<Float>(0.22, 0.20, 0.28)))
        material.metallic = 0.4
        material.roughness = 0.7
        return material
    }

    static func ringMaterial(goal: Bool) -> RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        let tint = goal ? Palette.gold : Palette.blue
        material.baseColor = .init(tint: Palette.colour(tint * 0.4))
        material.metallic = 0.85
        material.roughness = 0.2
        material.emissiveColor = .init(color: Palette.colour(tint))
        material.emissiveIntensity = goal ? 3.4 : 2.2
        return material
    }
}
