import XCTest
@testable import RavelinCore

final class RngTests: XCTestCase {
    func testSameSeedProducesSameSequence() {
        var a = SplitMix64(seed: 12345)
        var b = SplitMix64(seed: 12345)
        for _ in 0..<1000 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeedsDiverge() {
        var a = SplitMix64(seed: 1)
        var b = SplitMix64(seed: 2)
        var identical = 0
        for _ in 0..<100 where a.next() == b.next() { identical += 1 }
        XCTAssertLessThan(identical, 2)
    }

    func testKnownVectors() {
        var rng = SplitMix64(seed: 0)
        XCTAssertEqual(rng.next(), 16294208416658607535)
        XCTAssertEqual(rng.next(), 7960286522194355700)
        XCTAssertEqual(rng.next(), 487617019471545679)
    }

    func testUpperBoundIsRespected() {
        var rng = SplitMix64(seed: 99)
        for _ in 0..<5000 {
            XCTAssertLessThan(rng.next(upperBound: 40), 40)
        }
    }

    func testIntRangeCoversBounds() {
        var rng = SplitMix64(seed: 7)
        var seenLow = false
        var seenHigh = false
        for _ in 0..<5000 {
            let value = rng.nextInt(in: 1...6)
            XCTAssertTrue((1...6).contains(value))
            if value == 1 { seenLow = true }
            if value == 6 { seenHigh = true }
        }
        XCTAssertTrue(seenLow)
        XCTAssertTrue(seenHigh)
    }

    func testUnitFixedStaysInRange() {
        var rng = SplitMix64(seed: 424242)
        for _ in 0..<5000 {
            let value = rng.nextUnitFixed()
            XCTAssertGreaterThanOrEqual(value, .zero)
            XCTAssertLessThanOrEqual(value, .one)
        }
    }

    func testDerivedStreamsAreIndependent() {
        var draw = derivedStream(seed: 555, purpose: .draw, index: 0)
        var hazard = derivedStream(seed: 555, purpose: .hazardPhase, index: 0)
        var collisions = 0
        for _ in 0..<200 where draw.next() == hazard.next() { collisions += 1 }
        XCTAssertEqual(collisions, 0)
    }

    func testDerivedStreamIsReproducible() {
        var first = derivedStream(seed: 31337, purpose: .levelGeneration, index: 9)
        var second = derivedStream(seed: 31337, purpose: .levelGeneration, index: 9)
        for _ in 0..<200 {
            XCTAssertEqual(first.next(), second.next())
        }
    }
}
