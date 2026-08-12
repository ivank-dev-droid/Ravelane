import RavelaneCore

enum PartGlyph {
    static func symbol(for id: PartID) -> String {
        switch id.rawValue {
        case "sixth_slot": return "rectangle.stack.badge.plus"
        case "fast_feed": return "hare.fill"
        case "twin_draw": return "square.on.square"
        case "preview_next": return "eye"
        case "free_discard": return "trash.slash"
        case "rapid_discard": return "arrow.clockwise"
        case "sorter": return "arrow.up.arrow.down"
        case "sticky_hand": return "pin.fill"
        case "thrift": return "percent"
        case "salvage": return "arrow.3.trianglepath"
        case "soft_compound": return "circle.dotted"
        case "ballast_tune": return "scalemass"
        case "wing": return "airplane"
        case "landing_gear": return "arrow.down.to.line"
        case "anti_roll": return "gyroscope"
        case "wide_tyres": return "arrow.left.and.right"
        case "plating": return "shield.lefthalf.filled"
        case "scrape_guard": return "cross.case.fill"
        default: return "bolt"
        }
    }
}
