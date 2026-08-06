public struct PlacedPiece: Sendable, Hashable {
    public let index: Int
    public let pieceID: PieceID
    public let entryFrame: Transform3
    public let startArcLength: Fixed
    public let length: Fixed

    public var endArcLength: Fixed { startArcLength + length }
}

public struct LooseSocket: Sendable, Hashable {
    public let frame: Transform3
    public let originPieceIndex: Int
}

public struct TrackChain: Sendable {
    public let catalog: PieceCatalogCache
    public private(set) var placed: [PlacedPiece]
    public private(set) var worldSamplesByPiece: [[RibbonSample]]
    public private(set) var headFrame: Transform3
    public private(set) var totalLength: Fixed
    public private(set) var looseSockets: [LooseSocket]

    public init(catalog: PieceCatalogCache, origin: Transform3 = .identity) {
        self.catalog = catalog
        self.placed = []
        self.worldSamplesByPiece = []
        self.headFrame = origin
        self.totalLength = .zero
        self.looseSockets = []
    }

    @discardableResult
    public mutating func append(_ id: PieceID) -> PlacedPiece? {
        guard let geometry = catalog.geometry(id) else { return nil }
        let entry = headFrame
        let samples = geometry.samples(from: entry)
        let record = PlacedPiece(
            index: placed.count,
            pieceID: id,
            entryFrame: entry,
            startArcLength: totalLength,
            length: geometry.length
        )
        placed.append(record)
        worldSamplesByPiece.append(samples)
        totalLength += geometry.length
        headFrame = samples.last?.frame ?? entry
        if geometry.piece.branches {
            let branchRotation = Quat(yaw: degrees(35), pitch: .zero, roll: .zero)
            let branchFrame = Transform3(
                position: entry.position,
                rotation: (entry.rotation * branchRotation).normalized
            )
            looseSockets.append(LooseSocket(frame: branchFrame, originPieceIndex: record.index))
        }
        return record
    }

    public mutating func appendAll(_ ids: [PieceID]) {
        for id in ids { append(id) }
    }

    public func projectedHead(afterAppending id: PieceID) -> Transform3? {
        guard let geometry = catalog.geometry(id) else { return nil }
        return geometry.exit(from: headFrame)
    }

    public func projectedSamples(afterAppending id: PieceID) -> [RibbonSample]? {
        guard let geometry = catalog.geometry(id) else { return nil }
        return geometry.samples(from: headFrame)
    }

    public func pieceIndex(atArcLength arcLength: Fixed) -> Int? {
        guard !placed.isEmpty else { return nil }
        if arcLength < .zero { return nil }
        if arcLength >= totalLength { return placed.count - 1 }

        var low = 0
        var high = placed.count - 1
        while low < high {
            let mid = (low + high) / 2
            if placed[mid].endArcLength <= arcLength { low = mid + 1 } else { high = mid }
        }
        return low
    }

    public func sample(atArcLength arcLength: Fixed) -> RibbonSample? {
        guard let index = pieceIndex(atArcLength: arcLength) else { return nil }
        return sample(atArcLength: arcLength, pieceIndex: index)
    }

    public func sample(atArcLength arcLength: Fixed, pieceIndex index: Int) -> RibbonSample? {
        guard index >= 0 && index < placed.count else { return nil }
        let record = placed[index]
        guard let local = RibbonSampling.interpolate(
            worldSamplesByPiece[index],
            at: arcLength - record.startArcLength
        ) else { return nil }
        return RibbonSample(
            arcLength: arcLength,
            frame: local.frame,
            curvature: local.curvature,
            bank: local.bank
        )
    }

    public func worldSamples(strideMetres: Fixed = Fixed(2)) -> [RibbonSample] {
        var result: [RibbonSample] = []
        var cursor = Fixed.zero
        while cursor < totalLength {
            if let s = sample(atArcLength: cursor) { result.append(s) }
            cursor += strideMetres
        }
        if let last = sample(atArcLength: totalLength) { result.append(last) }
        return result
    }

    public func surface(atArcLength arcLength: Fixed) -> TrackSurface {
        guard let index = pieceIndex(atArcLength: arcLength),
              let piece = catalog.piece(placed[index].pieceID) else { return .normal }
        return piece.surface
    }

    public func width(atArcLength arcLength: Fixed) -> Fixed {
        guard let index = pieceIndex(atArcLength: arcLength),
              let piece = catalog.piece(placed[index].pieceID) else { return Fixed(8) }
        return piece.width
    }

    public var pieceIDs: [PieceID] { placed.map(\.pieceID) }
}
