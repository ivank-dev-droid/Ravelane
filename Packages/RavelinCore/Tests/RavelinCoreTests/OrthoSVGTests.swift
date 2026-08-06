import XCTest
@testable import RavelinCore

final class OrthoSVGTests: XCTestCase {
    private let catalog = PieceCatalog.cache

    private func sampleChain() -> TrackChain {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll([
            PieceID("straight"), PieceID("gentle_curve_l"), PieceID("rise_shallow"),
            PieceID("banked_curve_r"), PieceID("long_run"), PieceID("hairpin_l"),
            PieceID("drop_shallow"), PieceID("straight")
        ])
        return chain
    }

    func testRenderProducesWellFormedDocument() {
        let svg = OrthoSVG(plane: .top).render(sampleChain())
        XCTAssertTrue(svg.hasPrefix("<svg"))
        XCTAssertTrue(svg.hasSuffix("</svg>\n"))
        XCTAssertTrue(svg.contains("<polyline"))
        XCTAssertFalse(svg.contains("nan"))
        XCTAssertFalse(svg.contains("inf"))
    }

    func testEveryPieceProducesAPolyline() {
        let chain = sampleChain()
        let svg = OrthoSVG(plane: .top).render(chain)
        let count = svg.components(separatedBy: "<polyline").count - 1
        XCTAssertEqual(count, chain.placed.count)
    }

    func testAllPlanesRender() {
        let chain = sampleChain()
        for plane in OrthoPlane.allCases {
            let svg = OrthoSVG(plane: plane).render(chain)
            XCTAssertTrue(svg.contains(plane.rawValue))
            XCTAssertTrue(svg.contains("<polyline"))
        }
    }

    func testEmptyChainRendersPlaceholder() {
        let chain = TrackChain(catalog: catalog)
        let svg = OrthoSVG().render(chain)
        XCTAssertEqual(svg, OrthoSVG.emptyDocument)
    }

    func testRenderIsDeterministic() {
        let chain = sampleChain()
        let renderer = OrthoSVG(plane: .side)
        XCTAssertEqual(renderer.render(chain), renderer.render(chain))
    }
}
