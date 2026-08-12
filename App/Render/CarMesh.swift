import Foundation
import RealityKit
import simd
import RavelaneCore

struct MeshBuilder {
    private(set) var positions: [SIMD3<Float>] = []
    private(set) var normals: [SIMD3<Float>] = []
    private(set) var indices: [UInt32] = []

    mutating func triangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
        let edge = cross(b - a, c - a)
        guard length_squared(edge) > 1e-9 else { return }
        let normal = normalize(edge)
        let base = UInt32(positions.count)
        positions.append(contentsOf: [a, b, c])
        normals.append(contentsOf: [normal, normal, normal])
        indices.append(contentsOf: [base, base + 1, base + 2])
    }

    mutating func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
        triangle(a, b, c)
        triangle(a, c, d)
    }

    func resource(name: String) -> MeshResource? {
        guard !positions.isEmpty else { return nil }
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }
}

struct Hull {
    var z: Float
    var halfWidth: Float
    var halfHeight: Float
    var lift: Float
}

@MainActor
enum CarMesh {
    private static let sides = 12

    private static func ring(_ section: Hull) -> [SIMD3<Float>] {
        (0..<sides).map { index in
            let angle = Float(index) / Float(sides) * 2 * .pi
            let cosine = cos(angle)
            let sine = sin(angle)
            let x = section.halfWidth * sign(cosine) * pow(abs(cosine), 0.55)
            let y = section.halfHeight * sign(sine) * pow(abs(sine), 0.55)
            return SIMD3<Float>(x, y + section.lift, section.z)
        }
    }

    private static func sign(_ value: Float) -> Float { value < 0 ? -1 : 1 }

    private static func loft(_ sections: [Hull], into builder: inout MeshBuilder) {
        guard sections.count >= 2 else { return }
        var rings = sections.map(ring)

        for index in 0..<(rings.count - 1) {
            let current = rings[index]
            let next = rings[index + 1]
            for side in 0..<sides {
                let following = (side + 1) % sides
                builder.quad(current[side], next[side], next[following], current[following])
            }
        }

        if let first = rings.first {
            let centre = SIMD3<Float>(0, sections[0].lift, sections[0].z)
            for side in 0..<sides {
                builder.triangle(centre, first[(side + 1) % sides], first[side])
            }
        }
        if let last = rings.last {
            let centre = SIMD3<Float>(0, sections[sections.count - 1].lift, sections[sections.count - 1].z)
            for side in 0..<sides {
                builder.triangle(centre, last[side], last[(side + 1) % sides])
            }
        }
        rings.removeAll()
    }

    private static func wheel(centre: SIMD3<Float>, radius: Float, width: Float, into builder: inout MeshBuilder) {
        let segments = 12
        let left = centre - SIMD3<Float>(width / 2, 0, 0)
        let right = centre + SIMD3<Float>(width / 2, 0, 0)
        for index in 0..<segments {
            let a = Float(index) / Float(segments) * 2 * .pi
            let b = Float(index + 1) / Float(segments) * 2 * .pi
            let offsetA = SIMD3<Float>(0, sin(a) * radius, cos(a) * radius)
            let offsetB = SIMD3<Float>(0, sin(b) * radius, cos(b) * radius)
            builder.quad(left + offsetA, right + offsetA, right + offsetB, left + offsetB)
            builder.triangle(left, left + offsetB, left + offsetA)
            builder.triangle(right, right + offsetA, right + offsetB)
        }
    }

    private static func slab(centre: SIMD3<Float>, size: SIMD3<Float>, into builder: inout MeshBuilder) {
        let half = size / 2
        let corners = (0..<8).map { index -> SIMD3<Float> in
            SIMD3<Float>(
                centre.x + (index & 1 == 0 ? -half.x : half.x),
                centre.y + (index & 2 == 0 ? -half.y : half.y),
                centre.z + (index & 4 == 0 ? -half.z : half.z)
            )
        }
        builder.quad(corners[0], corners[2], corners[3], corners[1])
        builder.quad(corners[4], corners[5], corners[7], corners[6])
        builder.quad(corners[0], corners[1], corners[5], corners[4])
        builder.quad(corners[2], corners[6], corners[7], corners[3])
        builder.quad(corners[0], corners[4], corners[6], corners[2])
        builder.quad(corners[1], corners[3], corners[7], corners[5])
    }

    struct Shape {
        var length: Float
        var width: Float
        var height: Float
        var wing: Float
        var wheelRadius: Float

        init(spec: CarSpec) {
            let mass = Float(spec.mass.approximateDouble)
            let speed = Float(spec.topSpeed.approximateDouble)
            let tolerance = Float(spec.widthTolerance.approximateDouble)
            let push = Float(spec.downforce.approximateDouble)
            length = 3.0 + speed * 0.9
            width = 1.15 + tolerance * 0.5
            height = 0.52 + mass * 0.16
            wing = max(0, push) * 2.6
            wheelRadius = 0.34 + mass * 0.06
        }
    }

    static func body(spec: CarSpec) -> MeshResource? {
        let shape = Shape(spec: spec)
        var builder = MeshBuilder()

        let halfLength = shape.length / 2
        let halfWidth = shape.width / 2
        let sections = [
            Hull(z: -halfLength, halfWidth: halfWidth * 0.62, halfHeight: shape.height * 0.42, lift: 0.04),
            Hull(z: -halfLength * 0.55, halfWidth: halfWidth * 0.98, halfHeight: shape.height * 0.55, lift: 0.02),
            Hull(z: 0, halfWidth: halfWidth, halfHeight: shape.height * 0.5, lift: 0),
            Hull(z: halfLength * 0.52, halfWidth: halfWidth * 0.82, halfHeight: shape.height * 0.38, lift: -0.04),
            Hull(z: halfLength, halfWidth: halfWidth * 0.34, halfHeight: shape.height * 0.22, lift: -0.06)
        ]
        loft(sections, into: &builder)

        let canopy = [
            Hull(z: -halfLength * 0.34, halfWidth: halfWidth * 0.52, halfHeight: shape.height * 0.30, lift: shape.height * 0.52),
            Hull(z: 0, halfWidth: halfWidth * 0.58, halfHeight: shape.height * 0.34, lift: shape.height * 0.54),
            Hull(z: halfLength * 0.30, halfWidth: halfWidth * 0.40, halfHeight: shape.height * 0.22, lift: shape.height * 0.48)
        ]
        loft(canopy, into: &builder)

        if shape.wing > 0.05 {
            slab(centre: SIMD3<Float>(0, shape.height * 0.92, -halfLength * 0.92),
                 size: SIMD3<Float>(shape.width * 1.08, 0.09, shape.wing * 0.34),
                 into: &builder)
            for side in [-1, 1] as [Float] {
                slab(centre: SIMD3<Float>(side * shape.width * 0.44, shape.height * 0.66, -halfLength * 0.92),
                     size: SIMD3<Float>(0.08, shape.height * 0.6, 0.26),
                     into: &builder)
            }
        }

        for side in [-1, 1] as [Float] {
            slab(centre: SIMD3<Float>(side * (halfWidth + 0.06), shape.height * 0.06, 0),
                 size: SIMD3<Float>(0.10, 0.12, shape.length * 0.62),
                 into: &builder)
        }

        return builder.resource(name: "carBody")
    }

    static func wheels(spec: CarSpec) -> MeshResource? {
        let shape = Shape(spec: spec)
        var builder = MeshBuilder()
        let halfLength = shape.length / 2
        let offsetX = shape.width / 2 + 0.02
        let radius = shape.wheelRadius
        let width = 0.26 + radius * 0.3
        for side in [-1, 1] as [Float] {
            wheel(centre: SIMD3<Float>(side * offsetX, -shape.height * 0.18, halfLength * 0.58),
                  radius: radius * 0.92, width: width, into: &builder)
            wheel(centre: SIMD3<Float>(side * offsetX, -shape.height * 0.18, -halfLength * 0.60),
                  radius: radius, width: width * 1.15, into: &builder)
        }
        return builder.resource(name: "carWheels")
    }

    static func tint(for spec: CarSpec) -> SIMD3<Float> {
        let index = CarCatalog.all.firstIndex(where: { $0.id == spec.id }) ?? 0
        let hue = Float(index) / Float(max(1, CarCatalog.all.count)) * 2 * .pi
        let base = SIMD3<Float>(
            0.55 + 0.45 * sin(hue),
            0.55 + 0.45 * sin(hue + 2.094),
            0.55 + 0.45 * sin(hue + 4.188)
        )
        return simd_mix(base, SIMD3<Float>(0.92, 0.96, 1.0), SIMD3<Float>(repeating: 0.35))
    }

    static func bodyMaterial(spec: CarSpec) -> RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: Palette.colour(tint(for: spec)))
        material.metallic = 0.85
        material.roughness = 0.22
        material.clearcoat = 0.8
        material.clearcoatRoughness = 0.1
        material.emissiveColor = .init(color: Palette.colour(tint(for: spec) * 0.35))
        material.emissiveIntensity = 0.5
        return material
    }

    static var wheelMaterial: RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: Palette.colour(SIMD3<Float>(0.07, 0.07, 0.10)))
        material.metallic = 0.2
        material.roughness = 0.85
        return material
    }
}
