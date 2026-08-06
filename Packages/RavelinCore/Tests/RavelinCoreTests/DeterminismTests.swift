import XCTest
@testable import RavelinCore

final class DeterminismTests: XCTestCase {
    private func fingerprint(_ values: [Int64]) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for value in values {
            var bits = UInt64(bitPattern: value)
            for _ in 0..<8 {
                hash ^= bits & 0xFF
                hash = hash &* 0x0000_0100_0000_01B3
                bits >>= 8
            }
        }
        return hash
    }

    private func buildChainFingerprint() -> UInt64 {
        var frame = Transform3.identity
        var raws: [Int64] = []
        var rng = SplitMix64(seed: 0x5241_5645_4C49_4E00)
        for step in 0..<200 {
            let yaw = Fixed(rng.nextInt(in: -60...60), over: 100)
            let pitch = Fixed(rng.nextInt(in: -30...30), over: 100)
            let roll = Fixed(rng.nextInt(in: -45...45), over: 100)
            let advance = Fixed(8 + step % 40)
            frame = frame.rotated(yaw: yaw, pitch: pitch, roll: roll)
            frame = frame.advanced(along: advance)
            raws.append(contentsOf: [
                frame.position.x.raw, frame.position.y.raw, frame.position.z.raw,
                frame.rotation.x.raw, frame.rotation.y.raw,
                frame.rotation.z.raw, frame.rotation.w.raw
            ])
        }
        return fingerprint(raws)
    }

    func testTransformChainIsReproducibleWithinProcess() {
        XCTAssertEqual(buildChainFingerprint(), buildChainFingerprint())
    }

    func testTransformChainMatchesGoldenFingerprint() {
        XCTAssertEqual(buildChainFingerprint(), DeterminismTests.goldenChainFingerprint)
    }

    func testTrigTableIsUnchanged() {
        XCTAssertEqual(Trig.arctanTable.count, 32)
        XCTAssertEqual(fingerprint(Trig.arctanTable), DeterminismTests.goldenTableFingerprint)
        XCTAssertEqual(Trig.cordicGain.raw, 2608131496)
        XCTAssertEqual(Trig.pi.raw, 13493037705)
    }

    func testFixedArithmeticGoldenVector() {
        var accumulator = Fixed(1)
        var raws: [Int64] = []
        for step in 1...500 {
            accumulator = accumulator * Fixed(1001, over: 1000)
            accumulator = accumulator + Fixed(step, over: 7)
            accumulator = accumulator / Fixed(1003, over: 1000)
            raws.append(accumulator.raw)
        }
        XCTAssertEqual(fingerprint(raws), DeterminismTests.goldenArithmeticFingerprint)
    }

    func testCatalogGeometryMatchesGoldenFingerprint() {
        var raws: [Int64] = []
        for piece in PieceCatalog.all.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            guard let geometry = PieceCatalog.cache.geometry(piece.id) else {
                return XCTFail("missing geometry for \(piece.id)")
            }
            let exit = geometry.exitTransform
            raws.append(contentsOf: [
                exit.position.x.raw, exit.position.y.raw, exit.position.z.raw,
                exit.rotation.x.raw, exit.rotation.y.raw,
                exit.rotation.z.raw, exit.rotation.w.raw,
                geometry.length.raw, Int64(geometry.sampleCount)
            ])
        }
        XCTAssertEqual(fingerprint(raws), DeterminismTests.goldenCatalogFingerprint)
    }

    static let goldenCatalogFingerprint: UInt64 = 13396143040586426581
    static let goldenChainFingerprint: UInt64 = 17638089423717976749
    static let goldenTableFingerprint: UInt64 = 11202701236706878950
    static let goldenArithmeticFingerprint: UInt64 = 9673759134698064605
}
