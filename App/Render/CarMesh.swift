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
    private static let profile: [SIMD2<Float>] = [
        SIMD2<Float>(0.88, 0.00),
        SIMD2<Float>(1.00, 0.16),
        SIMD2<Float>(1.00, 0.58),
        SIMD2<Float>(0.68, 0.94),
        SIMD2<Float>(0.00, 1.00),
        SIMD2<Float>(-0.68, 0.94),
        SIMD2<Float>(-1.00, 0.58),
        SIMD2<Float>(-1.00, 0.16),
        SIMD2<Float>(-0.88, 0.00)
    ]

    private static var sides: Int { profile.count }

    private static func ring(_ section: Hull) -> [SIMD3<Float>] {
        profile.map { point in
            SIMD3<Float>(point.x * section.halfWidth,
                         section.lift + point.y * section.halfHeight,
                         section.z)
        }
    }

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
            length = 4.1 + speed * 1.2
            width = 1.70 + tolerance * 0.55
            height = 0.60 + mass * 0.17
            wing = max(0, push) * 3.0
            wheelRadius = 0.40 + mass * 0.07
        }
    }

    static func body(spec: CarSpec) -> MeshResource? {
        let shape = Shape(spec: spec)
        var builder = MeshBuilder()

        let halfLength = shape.length / 2
        let halfWidth = shape.width / 2
        let floor = -shape.height * 0.18

        let sections = [
            Hull(z: -halfLength, halfWidth: halfWidth * 0.90, halfHeight: shape.height * 0.72, lift: floor),
            Hull(z: -halfLength * 0.62, halfWidth: halfWidth, halfHeight: shape.height * 0.90, lift: floor),
            Hull(z: -halfLength * 0.10, halfWidth: halfWidth, halfHeight: shape.height, lift: floor),
            Hull(z: halfLength * 0.40, halfWidth: halfWidth * 0.94, halfHeight: shape.height * 0.66, lift: floor),
            Hull(z: halfLength * 0.78, halfWidth: halfWidth * 0.78, halfHeight: shape.height * 0.42, lift: floor),
            Hull(z: halfLength, halfWidth: halfWidth * 0.50, halfHeight: shape.height * 0.26, lift: floor)
        ]
        loft(sections, into: &builder)

        slab(centre: SIMD3<Float>(0, floor + 0.03, halfLength * 0.94),
             size: SIMD3<Float>(shape.width * 1.02, 0.07, shape.length * 0.13),
             into: &builder)

        if shape.wing > 0.05 {
            slab(centre: SIMD3<Float>(0, floor + shape.height * 1.22, -halfLength * 0.94),
                 size: SIMD3<Float>(shape.width * 1.05, 0.08, shape.wing * 0.32),
                 into: &builder)
            for side in [-1, 1] as [Float] {
                slab(centre: SIMD3<Float>(side * shape.width * 0.40, floor + shape.height * 0.95, -halfLength * 0.94),
                     size: SIMD3<Float>(0.07, shape.height * 0.55, 0.22),
                     into: &builder)
            }
        }

        return builder.resource(name: "carBody")
    }

    static func canopy(spec: CarSpec) -> MeshResource? {
        let shape = Shape(spec: spec)
        var builder = MeshBuilder()
        let halfLength = shape.length / 2
        let halfWidth = shape.width / 2
        let base = -shape.height * 0.18 + shape.height * 0.60

        let sections = [
            Hull(z: -halfLength * 0.34, halfWidth: halfWidth * 0.62, halfHeight: shape.height * 0.40, lift: base),
            Hull(z: -halfLength * 0.05, halfWidth: halfWidth * 0.66, halfHeight: shape.height * 0.46, lift: base),
            Hull(z: halfLength * 0.30, halfWidth: halfWidth * 0.46, halfHeight: shape.height * 0.26, lift: base)
        ]
        loft(sections, into: &builder)
        return builder.resource(name: "carCanopy")
    }

    static func wheels(spec: CarSpec) -> MeshResource? {
        let shape = Shape(spec: spec)
        var builder = MeshBuilder()
        let halfLength = shape.length / 2
        let radius = shape.wheelRadius
        let width = 0.24 + radius * 0.26
        let offsetX = shape.width / 2 - width * 0.28
        let axle = -shape.height * 0.18 + radius * 0.62
        for side in [-1, 1] as [Float] {
            wheel(centre: SIMD3<Float>(side * offsetX, axle, halfLength * 0.62),
                  radius: radius * 0.90, width: width, into: &builder)
            wheel(centre: SIMD3<Float>(side * offsetX, axle, -halfLength * 0.64),
                  radius: radius, width: width * 1.18, into: &builder)
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

    static var canopyMaterial: RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: Palette.colour(SIMD3<Float>(0.05, 0.07, 0.12)))
        material.metallic = 0.6
        material.roughness = 0.08
        material.clearcoat = 1.0
        material.clearcoatRoughness = 0.05
        material.emissiveColor = .init(color: Palette.colour(Palette.cold * 0.5))
        material.emissiveIntensity = 0.35
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
