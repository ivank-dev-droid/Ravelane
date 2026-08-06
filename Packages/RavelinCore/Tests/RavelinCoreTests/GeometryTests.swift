import XCTest
import Foundation
@testable import RavelinCore

final class GeometryTests: XCTestCase {
    func testVectorArithmetic() {
        let a = Vec3(Fixed(1), Fixed(2), Fixed(3))
        let b = Vec3(Fixed(4), Fixed(5), Fixed(6))
        XCTAssertEqual(a + b, Vec3(Fixed(5), Fixed(7), Fixed(9)))
        XCTAssertEqual(b - a, Vec3(Fixed(3), Fixed(3), Fixed(3)))
        XCTAssertEqual(a * Fixed(2), Vec3(Fixed(2), Fixed(4), Fixed(6)))
    }

    func testDotAndCross() {
        let a = Vec3(Fixed(1), Fixed(2), Fixed(3))
        let b = Vec3(Fixed(4), Fixed(5), Fixed(6))
        XCTAssertEqual(a.dot(b), Fixed(32))
        XCTAssertEqual(Vec3.unitX.cross(.unitY), Vec3.unitZ)
        XCTAssertEqual(Vec3.unitY.cross(.unitZ), Vec3.unitX)
    }

    func testLengthAndNormalize() {
        let v = Vec3(Fixed(3), Fixed(4), .zero)
        XCTAssertEqual(v.length.approximateDouble, 5.0, accuracy: 1e-8)
        let unit = v.normalized
        XCTAssertEqual(unit.length.approximateDouble, 1.0, accuracy: 1e-7)
        XCTAssertEqual(Vec3.zero.normalized, .zero)
    }

    func testQuaternionIdentityRotation() {
        let v = Vec3(Fixed(1), Fixed(2), Fixed(3))
        XCTAssertEqual(Quat.identity.rotate(v), v)
    }

    func testQuarterTurnAboutY() {
        let q = Quat(axis: .unitY, angle: Trig.halfPi)
        let rotated = q.rotate(.unitZ)
        XCTAssertEqual(rotated.x.approximateDouble, 1.0, accuracy: 1e-6)
        XCTAssertEqual(rotated.y.approximateDouble, 0.0, accuracy: 1e-6)
        XCTAssertEqual(rotated.z.approximateDouble, 0.0, accuracy: 1e-6)
    }

    func testQuaternionCompositionMatchesSequentialRotation() {
        let yaw = Quat(axis: .unitY, angle: Fixed(1, over: 3))
        let pitch = Quat(axis: .unitX, angle: Fixed(1, over: 5))
        let combined = (yaw * pitch).normalized
        let v = Vec3(Fixed(2), Fixed(-1), Fixed(4))
        let sequential = yaw.rotate(pitch.rotate(v))
        let direct = combined.rotate(v)
        XCTAssertEqual(direct.x.approximateDouble, sequential.x.approximateDouble, accuracy: 1e-5)
        XCTAssertEqual(direct.y.approximateDouble, sequential.y.approximateDouble, accuracy: 1e-5)
        XCTAssertEqual(direct.z.approximateDouble, sequential.z.approximateDouble, accuracy: 1e-5)
    }

    func testQuaternionRotationPreservesLength() {
        let q = Quat(yaw: Fixed(7, over: 10), pitch: Fixed(-3, over: 10), roll: Fixed(11, over: 10))
            .normalized
        let v = Vec3(Fixed(3), Fixed(-4), Fixed(12))
        let rotated = q.rotate(v)
        XCTAssertEqual(rotated.length.approximateDouble, v.length.approximateDouble, accuracy: 1e-5)
    }

    func testTransformComposition() {
        let step = Transform3(position: Vec3(.zero, .zero, Fixed(10)), rotation: .identity)
        var frame = Transform3.identity
        frame = frame.applying(step)
        frame = frame.applying(step)
        XCTAssertEqual(frame.position.z.approximateDouble, 20.0, accuracy: 1e-8)
    }

    func testTransformChainTurnsCorner() {
        let quarterTurn = Quat(axis: .unitY, angle: Trig.halfPi)
        let straight = Transform3(position: Vec3(.zero, .zero, Fixed(10)), rotation: .identity)
        let turn = Transform3(position: .zero, rotation: quarterTurn)

        var frame = Transform3.identity
        frame = frame.applying(straight)
        frame = frame.applying(turn)
        frame = frame.applying(straight)

        XCTAssertEqual(frame.position.x.approximateDouble, 10.0, accuracy: 1e-5)
        XCTAssertEqual(frame.position.z.approximateDouble, 10.0, accuracy: 1e-5)
    }

    func testTransformInverseRoundTrip() {
        let t = Transform3(
            position: Vec3(Fixed(5), Fixed(-2), Fixed(9)),
            rotation: Quat(yaw: Fixed(1, over: 2), pitch: Fixed(1, over: 4), roll: .zero).normalized
        )
        let point = Vec3(Fixed(3), Fixed(7), Fixed(-1))
        let round = t.inverse.transformPoint(t.transformPoint(point))
        XCTAssertEqual(round.x.approximateDouble, point.x.approximateDouble, accuracy: 1e-4)
        XCTAssertEqual(round.y.approximateDouble, point.y.approximateDouble, accuracy: 1e-4)
        XCTAssertEqual(round.z.approximateDouble, point.z.approximateDouble, accuracy: 1e-4)
    }

    func testFullCircleOfTurnsReturnsToOrigin() {
        let quarterTurn = Transform3(
            position: .zero,
            rotation: Quat(axis: .unitY, angle: Trig.halfPi)
        )
        let straight = Transform3(position: Vec3(.zero, .zero, Fixed(20)), rotation: .identity)

        var frame = Transform3.identity
        for _ in 0..<4 {
            frame = frame.applying(straight)
            frame = frame.applying(quarterTurn)
        }

        XCTAssertEqual(frame.position.x.approximateDouble, 0.0, accuracy: 1e-3)
        XCTAssertEqual(frame.position.y.approximateDouble, 0.0, accuracy: 1e-3)
        XCTAssertEqual(frame.position.z.approximateDouble, 0.0, accuracy: 1e-3)
    }
}
