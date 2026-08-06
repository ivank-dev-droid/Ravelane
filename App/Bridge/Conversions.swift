import Foundation
import simd
import RavelinCore

extension Fixed {
    var float: Float { Float(approximateDouble) }
}

extension Vec3 {
    var simd: SIMD3<Float> { SIMD3<Float>(x.float, y.float, z.float) }
}

extension Quat {
    var simd: simd_quatf {
        simd_quatf(ix: x.float, iy: y.float, iz: z.float, r: w.float)
    }
}

extension Transform3 {
    var simdTranslation: SIMD3<Float> { position.simd }
    var simdRotation: simd_quatf { rotation.simd }
}

extension Fixed {
    var oneDecimal: String {
        let scaled = (approximateDouble * 10).rounded() / 10
        return String(format: "%.1f", scaled)
    }
}
