import XCTest
@testable import RavelinCore

final class FixedTests: XCTestCase {
    func testIntegerConstruction() {
        XCTAssertEqual(Fixed(3).raw, 3 << 32)
        XCTAssertEqual(Fixed(-7).raw, -7 << 32)
        XCTAssertEqual(Fixed.one.raw, 1 << 32)
    }

    func testRationalConstruction() {
        XCTAssertEqual(Fixed(1, over: 2), Fixed.half)
        XCTAssertEqual(Fixed(3, over: 4).approximateDouble, 0.75, accuracy: 1e-9)
    }

    func testAddSubtract() {
        XCTAssertEqual(Fixed(2) + Fixed(3), Fixed(5))
        XCTAssertEqual(Fixed(2) - Fixed(5), Fixed(-3))
        XCTAssertEqual(Fixed.half + Fixed.half, Fixed.one)
    }

    func testMultiplication() {
        XCTAssertEqual(Fixed(3) * Fixed(4), Fixed(12))
        XCTAssertEqual(Fixed.half * Fixed.half, Fixed(1, over: 4))
        XCTAssertEqual((Fixed(-3) * Fixed(4)), Fixed(-12))
        XCTAssertEqual((Fixed(-3) * Fixed(-4)), Fixed(12))
    }

    func testDivision() {
        XCTAssertEqual(Fixed(12) / Fixed(4), Fixed(3))
        XCTAssertEqual(Fixed.one / Fixed(2), Fixed.half)
        XCTAssertEqual(Fixed(-12) / Fixed(4), Fixed(-3))
        XCTAssertEqual((Fixed(1) / Fixed(3)).approximateDouble, 1.0 / 3.0, accuracy: 1e-9)
    }

    func testMultiplyDivideRoundTrip() {
        let values = [Fixed(1, over: 7), Fixed(355, over: 113), Fixed(-9, over: 4), Fixed(1000)]
        for value in values {
            let round = (value * Fixed(37)) / Fixed(37)
            XCTAssertEqual(round.approximateDouble, value.approximateDouble, accuracy: 1e-7)
        }
    }

    func testSquareRoot() {
        XCTAssertEqual(Fixed(16).squareRoot.approximateDouble, 4.0, accuracy: 1e-8)
        XCTAssertEqual(Fixed(2).squareRoot.approximateDouble, 1.4142135623730951, accuracy: 1e-8)
        XCTAssertEqual(Fixed.zero.squareRoot, .zero)
        XCTAssertEqual(Fixed(1, over: 4).squareRoot.approximateDouble, 0.5, accuracy: 1e-8)
    }

    func testSaturationInsteadOfOverflow() {
        XCTAssertEqual(Fixed.max + Fixed.one, Fixed.max)
        XCTAssertEqual(Fixed.min - Fixed.one, Fixed.min)
        XCTAssertEqual((Fixed.max * Fixed(2)), Fixed.max)
    }

    func testComparisonAndClamp() {
        XCTAssertLessThan(Fixed(1), Fixed(2))
        XCTAssertEqual(Fixed(5).clamped(to: Fixed(0)...Fixed(3)), Fixed(3))
        XCTAssertEqual(Fixed(-5).clamped(to: Fixed(0)...Fixed(3)), Fixed(0))
    }

    func testDescription() {
        XCTAssertEqual(Fixed(3, over: 2).description, "1.500")
        XCTAssertEqual(Fixed(-3, over: 2).description, "-1.500")
    }
}
