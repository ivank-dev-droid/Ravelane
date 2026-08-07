public enum PieceCatalog {
    public static let standardWidth = Fixed(8)
    public static let narrowWidth = Fixed(4)
    public static let wideWidth = Fixed(16)

    public static let all: [Piece] = straights + turns + verticals + rolls + air + surfaces + structural + worldLocked

    public static let cache = PieceCatalogCache(pieces: all)

    public static let straights: [Piece] = [
        Piece(id: PieceID("stub"), name: "Stub", pieceClass: .straight,
              segments: [.straight(Fixed(8))], cost: 4, tags: [.utility]),
        Piece(id: PieceID("straight"), name: "Straight", pieceClass: .straight,
              segments: [.straight(Fixed(24))], cost: 10, tags: [.runwayBuy]),
        Piece(id: PieceID("long_run"), name: "Long Run", pieceClass: .straight,
              segments: [.straight(Fixed(48))], cost: 22, tags: [.runwayBuy]),
        Piece(id: PieceID("narrow_bridge"), name: "Narrow Bridge", pieceClass: .straight,
              segments: [.straight(Fixed(32))], width: narrowWidth, cost: 6,
              tags: [.runwayBuy, .fragile])
    ]

    public static let turns: [Piece] = {
        let gentleLeft = Piece(
            id: PieceID("gentle_curve_l"), name: "Gentle Curve L", pieceClass: .turn,
            segments: [PieceSegment(length: Fixed(16), yaw: -degrees(30))],
            cost: 9, tags: [.navigation])
        let sharpLeft = Piece(
            id: PieceID("sharp_curve_l"), name: "Sharp Curve L", pieceClass: .turn,
            segments: [PieceSegment(length: Fixed(12), yaw: -degrees(60))],
            cost: 12, tags: [.navigation, .speedLoss])
        let hairpinLeft = Piece(
            id: PieceID("hairpin_l"), name: "Hairpin L", pieceClass: .turn,
            segments: [PieceSegment(length: Fixed(14), yaw: -degrees(120))],
            cost: 18, tags: [.navigation, .speedLoss])
        let bankedLeft = Piece(
            id: PieceID("banked_curve_l"), name: "Banked Curve L", pieceClass: .turn,
            segments: [
                PieceSegment(length: Fixed(3), roll: -degrees(30)),
                PieceSegment(length: Fixed(12), yaw: -degrees(60)),
                PieceSegment(length: Fixed(3), roll: degrees(30))
            ],
            cost: 20, tags: [.navigation, .forgiving])
        let chicane = Piece(
            id: PieceID("chicane_lr"), name: "Chicane L-R", pieceClass: .turn,
            segments: [
                PieceSegment(length: Fixed(13), yaw: -degrees(25)),
                PieceSegment(length: Fixed(13), yaw: degrees(25))
            ],
            cost: 15, tags: [.navigation, .speedLoss])
        let offCamber = Piece(
            id: PieceID("off_camber_l"), name: "Off-camber Curve L", pieceClass: .turn,
            segments: [PieceSegment(length: Fixed(14), yaw: -degrees(45), roll: degrees(15))],
            cost: 5, tags: [.navigation, .fragile])

        return [
            gentleLeft,
            gentleLeft.mirrored(id: PieceID("gentle_curve_r"), name: "Gentle Curve R"),
            sharpLeft,
            sharpLeft.mirrored(id: PieceID("sharp_curve_r"), name: "Sharp Curve R"),
            hairpinLeft,
            hairpinLeft.mirrored(id: PieceID("hairpin_r"), name: "Hairpin R"),
            bankedLeft,
            bankedLeft.mirrored(id: PieceID("banked_curve_r"), name: "Banked Curve R"),
            chicane,
            offCamber
        ]
    }()

    public static let verticals: [Piece] = [
        Piece(id: PieceID("rise_shallow"), name: "Rise Shallow", pieceClass: .vertical,
              segments: [PieceSegment(length: Fixed(20), pitch: degrees(12))],
              cost: 11, tags: [.navigation, .speedLoss]),
        Piece(id: PieceID("rise_steep"), name: "Rise Steep", pieceClass: .vertical,
              segments: [PieceSegment(length: Fixed(16), pitch: degrees(30))],
              cost: 16, tags: [.navigation, .speedLoss]),
        Piece(id: PieceID("drop_shallow"), name: "Drop Shallow", pieceClass: .vertical,
              segments: [PieceSegment(length: Fixed(20), pitch: -degrees(12))],
              cost: 11, tags: [.navigation, .speedGain]),
        Piece(id: PieceID("drop_steep"), name: "Drop Steep", pieceClass: .vertical,
              segments: [PieceSegment(length: Fixed(16), pitch: -degrees(30))],
              cost: 16, tags: [.navigation, .speedGain]),
        Piece(id: PieceID("crest"), name: "Crest", pieceClass: .vertical,
              segments: [
                PieceSegment(length: Fixed(11), pitch: degrees(18)),
                PieceSegment(length: Fixed(11), pitch: -degrees(18))
              ],
              cost: 14, tags: [.navigation]),
        Piece(id: PieceID("dip"), name: "Dip", pieceClass: .vertical,
              segments: [
                PieceSegment(length: Fixed(11), pitch: -degrees(18)),
                PieceSegment(length: Fixed(11), pitch: degrees(18))
              ],
              cost: 14, tags: [.navigation]),
        Piece(id: PieceID("spiral_up"), name: "Spiral Up", pieceClass: .vertical,
              segments: [
                PieceSegment(length: Fixed(4), pitch: degrees(24)),
                PieceSegment(length: Fixed(36), yaw: degrees(360), yawAxis: .world),
                PieceSegment(length: Fixed(4), pitch: -degrees(24))
              ],
              cost: 26, tags: [.navigation, .speedLoss]),
        Piece(id: PieceID("spiral_down"), name: "Spiral Down", pieceClass: .vertical,
              segments: [
                PieceSegment(length: Fixed(4), pitch: -degrees(24)),
                PieceSegment(length: Fixed(36), yaw: degrees(360), yawAxis: .world),
                PieceSegment(length: Fixed(4), pitch: degrees(24))
              ],
              cost: 24, tags: [.navigation, .speedGain])
    ]

    public static let rolls: [Piece] = {
        let bankLeft = Piece(
            id: PieceID("bank_l"), name: "Bank L", pieceClass: .roll,
            segments: [PieceSegment(length: Fixed(14), roll: -degrees(25))],
            cost: 8, tags: [.forgiving])
        let corkscrewLeft = Piece(
            id: PieceID("corkscrew_l"), name: "Corkscrew L", pieceClass: .roll,
            segments: [PieceSegment(length: Fixed(40), roll: -degrees(360))],
            cost: 28, tags: [.runwayBuy])
        return [
            bankLeft,
            bankLeft.mirrored(id: PieceID("bank_r"), name: "Bank R"),
            corkscrewLeft,
            corkscrewLeft.mirrored(id: PieceID("corkscrew_r"), name: "Corkscrew R")
        ]
    }()

    public static let air: [Piece] = [
        Piece(id: PieceID("kicker"), name: "Kicker", pieceClass: .air,
              segments: [PieceSegment(length: Fixed(10), pitch: degrees(15))],
              cost: 12, tags: [.navigation], gapLength: Fixed(18), landingTolerance: degrees(18)),
        Piece(id: PieceID("long_gap"), name: "Long Gap", pieceClass: .air,
              segments: [PieceSegment(length: Fixed(6))],
              cost: 20, tags: [.navigation, .fragile],
              gapLength: Fixed(45), landingTolerance: degrees(15)),
        Piece(id: PieceID("landing_pad"), name: "Landing Pad", pieceClass: .air,
              segments: [.straight(Fixed(20))], width: wideWidth, cost: 14,
              tags: [.forgiving], landingTolerance: degrees(25)),
        Piece(id: PieceID("loop"), name: "Loop", pieceClass: .air,
              segments: [PieceSegment(length: Fixed(56), pitch: degrees(360))],
              cost: 34, tags: [.runwayBuy]),
        Piece(id: PieceID("launch_rail"), name: "Launch Rail", pieceClass: .air,
              segments: [PieceSegment(length: Fixed(18), pitch: degrees(25))],
              cost: 24, surface: .boost, tags: [.speedGain],
              gapLength: Fixed(30), landingTolerance: degrees(20))
    ]

    public static let surfaces: [Piece] = [
        Piece(id: PieceID("booster_strip"), name: "Booster Strip", pieceClass: .surface,
              segments: [.straight(Fixed(16))], cost: 15, surface: .boost, tags: [.speedGain]),
        Piece(id: PieceID("brake_strip"), name: "Brake Strip", pieceClass: .surface,
              segments: [.straight(Fixed(16))], cost: 9, surface: .brake, tags: [.speedLoss]),
        Piece(id: PieceID("rumble_strip"), name: "Rumble Strip", pieceClass: .surface,
              segments: [.straight(Fixed(20))], cost: 2, surface: .rumble,
              tags: [.speedLoss, .fragile]),
        Piece(id: PieceID("wide_plate"), name: "Wide Plate", pieceClass: .surface,
              segments: [.straight(Fixed(24))], width: wideWidth, cost: 16, tags: [.forgiving])
    ]

    public static let structural: [Piece] = [
        Piece(id: PieceID("junction"), name: "Junction", pieceClass: .structural,
              segments: [.straight(Fixed(18))], cost: 22, tags: [.branching], branches: true),
        Piece(id: PieceID("merge"), name: "Merge", pieceClass: .structural,
              segments: [.straight(Fixed(18))], cost: 18, tags: [.branching]),
        Piece(id: PieceID("scaffold"), name: "Scaffold", pieceClass: .structural,
              segments: [.straight(Fixed(30))], cost: 0, surface: .scaffold,
              tags: [.runwayBuy, .fragile]),
        Piece(id: PieceID("repair_plate"), name: "Repair Plate", pieceClass: .structural,
              segments: [.straight(Fixed(20))], cost: 26, tags: [.utility]),
        Piece(id: PieceID("adjustable_curve"), name: "Adjustable Curve", pieceClass: .structural,
              segments: [PieceSegment(length: Fixed(16), yaw: degrees(45))],
              cost: 30, tags: [.navigation, .utility])
    ]

    public static let worldLocked: [Piece] = [
        Piece(id: PieceID("magnet_strip"), name: "Magnet Strip", pieceClass: .surface,
              segments: [.straight(Fixed(24))], cost: 18, surface: .magnet,
              tags: [.worldLocked, .forgiving]),
        Piece(id: PieceID("wall_transition"), name: "Wall Transition", pieceClass: .roll,
              segments: [PieceSegment(length: Fixed(20), roll: degrees(90))],
              cost: 24, surface: .magnet, tags: [.worldLocked, .navigation]),
        Piece(id: PieceID("ceiling_transition"), name: "Ceiling Transition", pieceClass: .roll,
              segments: [PieceSegment(length: Fixed(20), roll: degrees(180))],
              cost: 28, surface: .magnet, tags: [.worldLocked, .navigation]),
        Piece(id: PieceID("beacon"), name: "Beacon", pieceClass: .structural,
              segments: [.straight(Fixed(16))], cost: 14, tags: [.worldLocked, .utility]),
        Piece(id: PieceID("anchor"), name: "Anchor", pieceClass: .structural,
              segments: [.straight(Fixed(12))], cost: 16, tags: [.worldLocked, .utility]),
        Piece(id: PieceID("lift"), name: "Lift", pieceClass: .vertical,
              segments: [
                PieceSegment(length: Fixed(6), pitch: degrees(90)),
                PieceSegment(length: Fixed(18)),
                PieceSegment(length: Fixed(6), pitch: -degrees(90))
              ],
              cost: 26, tags: [.worldLocked, .navigation, .speedLoss])
    ]
}
