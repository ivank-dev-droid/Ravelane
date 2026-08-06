import XCTest
import Foundation
@testable import RavelinCore

final class TrigTests: XCTestCase {
    private let tolerance = 1e-8

    func testConstants() {
        XCTAssertEqual(Trig.pi.approximateDouble, Double.pi, accuracy: 1e-9)
        XCTAssertEqual(Trig.halfPi.approximateDouble, Double.pi / 2, accuracy: 1e-9)
        XCTAssertEqual(Trig.twoPi.approximateDouble, Double.pi * 2, accuracy: 1e-9)
    }

    func testSinCosAgainstReference() {
        var degrees = -720
        while degrees <= 720 {
            let radians = Double(degrees) * Double.pi / 180.0
            let angle = Fixed(approximating: radians)
            let (s, c) = Trig.sinCos(angle)
            XCTAssertEqual(s.approximateDouble, Foundation.sin(radians), accuracy: tolerance,
                           "sin failed at \(degrees) degrees")
            XCTAssertEqual(c.approximateDouble, Foundation.cos(radians), accuracy: tolerance,
                           "cos failed at \(degrees) degrees")
            degrees += 1
        }
    }

    func testPythagoreanIdentity() {
        for step in stride(from: -400, through: 400, by: 7) {
            let angle = Fixed(step, over: 100)
            let (s, c) = Trig.sinCos(angle)
            let identity = s * s + c * c
            XCTAssertEqual(identity.approximateDouble, 1.0, accuracy: 1e-8)
        }
    }

    func testAtan2AgainstReference() {
        let samples: [(Double, Double)] = [
            (1, 0), (0, 1), (-1, 0), (0, -1),
            (1, 1), (-1, 1), (1, -1), (-1, -1),
            (3, 4), (-3, 4), (3, -4), (-3, -4),
            (0.001, 100), (100, 0.001)
        ]
        for (y, x) in samples {
            let result = Trig.atan2(y: Fixed(approximating: y), x: Fixed(approximating: x))
            let expected = Foundation.atan2(y, x)
            XCTAssertEqual(result.approximateDouble, expected, accuracy: 1e-7,
                           "atan2(\(y), \(x)) failed")
        }
    }

    func testAtan2RoundTripWithSinCos() {
        for step in stride(from: -300, through: 300, by: 11) {
            let angle = Trig.normalizedAngle(Fixed(step, over: 100))
            let (s, c) = Trig.sinCos(angle)
            let recovered = Trig.atan2(y: s, x: c)
            XCTAssertEqual(recovered.approximateDouble, angle.approximateDouble, accuracy: 1e-7)
        }
    }

    func testNormalizedAngleWraps() {
        let wrapped = Trig.normalizedAngle(Fixed(raw: Trig.twoPi.raw * 3 + Trig.halfPi.raw))
        XCTAssertEqual(wrapped.approximateDouble, Double.pi / 2, accuracy: 1e-8)
    }

    func testZeroAndRightAngles() {
        XCTAssertEqual(Trig.sin(.zero).approximateDouble, 0.0, accuracy: 1e-9)
        XCTAssertEqual(Trig.cos(.zero).approximateDouble, 1.0, accuracy: 1e-8)
        XCTAssertEqual(Trig.sin(Trig.halfPi).approximateDouble, 1.0, accuracy: 1e-6)
        XCTAssertEqual(Trig.cos(Trig.halfPi).approximateDouble, 0.0, accuracy: 1e-6)
        XCTAssertEqual(Trig.sin(Trig.pi).approximateDouble, 0.0, accuracy: 1e-6)
        XCTAssertEqual(Trig.cos(Trig.pi).approximateDouble, -1.0, accuracy: 1e-6)
    }
}
