import XCTest
import Foundation
@testable import RavelinCore

final class PurityTests: XCTestCase {
    static let floatingPointAllowlist: Set<String> = [
        "Math/Fixed.swift",
        "Math/Vec3.swift"
    ]
    static let allowedDirectories: Set<String> = ["Debug"]

    private var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RavelinCore")
    }

    private func swiftSources() throws -> [(relativePath: String, contents: String)] {
        let root = sourceRoot
        let enumerator = FileManager.default.enumerator(atPath: root.path)
        var result: [(String, String)] = []
        while let entry = enumerator?.nextObject() as? String {
            guard entry.hasSuffix(".swift") else { continue }
            let contents = try String(contentsOf: root.appendingPathComponent(entry), encoding: .utf8)
            result.append((entry, contents))
        }
        return result.sorted { $0.0 < $1.0 }
    }

    private func isAllowed(_ relativePath: String) -> Bool {
        if PurityTests.floatingPointAllowlist.contains(relativePath) { return true }
        let directory = relativePath.split(separator: "/").first.map(String.init) ?? ""
        return PurityTests.allowedDirectories.contains(directory)
    }

    func testSourcesAreDiscoverable() throws {
        let sources = try swiftSources()
        XCTAssertGreaterThanOrEqual(sources.count, 10,
                                    "purity scan found no sources — check the path derivation")
    }

    func testNoPlatformImports() throws {
        let forbidden = ["import Foundation", "import Glibc", "import Darwin", "import ucrt"]
        for (path, contents) in try swiftSources() {
            for token in forbidden {
                XCTAssertFalse(
                    contents.contains(token),
                    "\(path) contains \(token). RavelinCore must build with the standard library alone."
                )
            }
        }
    }

    func testNoFloatingPointOutsideAllowlist() throws {
        for (path, contents) in try swiftSources() where !isAllowed(path) {
            for keyword in ["Double", "Float", "CGFloat"] {
                XCTAssertFalse(
                    contents.contains(keyword),
                    """
                    \(path) mentions \(keyword). The simulation runs on Fixed so that a replay \
                    recorded on x86-64 reproduces bit-exactly on ARM64. If this is genuinely \
                    presentation-only code, move it under Debug/ or add it to the allowlist \
                    deliberately.
                    """
                )
            }
        }
    }

    func testNoBareLibraryMathCalls() throws {
        let functions = ["sin", "cos", "tan", "atan", "atan2", "sqrt", "pow", "exp", "log", "hypot"]
        for (path, contents) in try swiftSources() where !isAllowed(path) {
            let characters = Array(contents)
            for function in functions {
                var searchStart = contents.startIndex
                while let range = contents.range(of: function + "(", range: searchStart..<contents.endIndex) {
                    let offset = contents.distance(from: contents.startIndex, to: range.lowerBound)
                    let previous: Character? = offset > 0 ? characters[offset - 1] : nil
                    let qualified = previous == "."
                    let partOfWord = previous.map { $0.isLetter || $0.isNumber || $0 == "_" } ?? false
                    let precedingText = String(characters[0..<offset])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let isDeclaration = precedingText.hasSuffix("func")
                    if !qualified && !partOfWord && !isDeclaration {
                        XCTFail("\(path) calls \(function)( directly. Use Trig, which is CORDIC over a generated table.")
                    }
                    searchStart = range.upperBound
                }
            }
        }
    }

    func testTrigDoesNotDependOnPlatformMath() throws {
        let sources = try swiftSources()
        guard let trig = sources.first(where: { $0.relativePath == "Math/Trig.swift" }) else {
            return XCTFail("Math/Trig.swift not found")
        }
        XCTAssertFalse(trig.contents.contains("Double"))
        XCTAssertFalse(trig.contents.contains("import"))
        XCTAssertTrue(trig.contents.contains("arctanTable"))
    }
}
