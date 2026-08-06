public struct Transform3: Sendable, Hashable, Codable {
    public var position: Vec3
    public var rotation: Quat

    public init(position: Vec3 = .zero, rotation: Quat = .identity) {
        self.position = position
        self.rotation = rotation
    }

    public static let identity = Transform3()

    public func applying(_ local: Transform3) -> Transform3 {
        Transform3(
            position: position + rotation.rotate(local.position),
            rotation: (rotation * local.rotation).normalized
        )
    }

    public func transformPoint(_ point: Vec3) -> Vec3 {
        position + rotation.rotate(point)
    }

    public func transformDirection(_ direction: Vec3) -> Vec3 {
        rotation.rotate(direction)
    }

    public var inverse: Transform3 {
        let inverseRotation = rotation.conjugate
        return Transform3(
            position: -inverseRotation.rotate(position),
            rotation: inverseRotation
        )
    }

    public var forward: Vec3 { rotation.forward }
    public var up: Vec3 { rotation.up }
    public var right: Vec3 { rotation.right }

    public func advanced(along distance: Fixed) -> Transform3 {
        Transform3(position: position + forward * distance, rotation: rotation)
    }

    public func rotatedAboutWorldUp(_ angle: Fixed) -> Transform3 {
        if angle.raw == 0 { return self }
        let worldRotation = Quat(axis: .unitY, angle: angle)
        return Transform3(
            position: position,
            rotation: (worldRotation * rotation).normalized
        )
    }

    public func rotated(yaw: Fixed, pitch: Fixed, roll: Fixed) -> Transform3 {
        if yaw.raw == 0 && pitch.raw == 0 && roll.raw == 0 { return self }
        return Transform3(
            position: position,
            rotation: (rotation * Quat(yaw: yaw, pitch: pitch, roll: roll)).normalized
        )
    }
}
