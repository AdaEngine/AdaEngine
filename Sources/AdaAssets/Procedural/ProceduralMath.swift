//
//  ProceduralMath.swift
//  AdaEngine
//

#if os(Android)
import Android
#endif
import Foundation

// Small vector helpers so procedural geometry builds without `simd`, which is not available on every platform.

public enum ProceduralMath {
    /// Quaternion `(x, y, z, w)` for angles in degrees: roll about Z first, then pitch about X, then yaw about Y.
    public static func quaternion(eulerDegrees angles: SIMD3<Float>) -> SIMD4<Float> {
        func axis(_ index: Int) -> SIMD4<Float> {
            let half = angles[index] * .pi / 360
            var result = SIMD4<Float>(0, 0, 0, cos(half))
            result[index] = sin(half)
            return result
        }
        func multiply(_ a: SIMD4<Float>, _ b: SIMD4<Float>) -> SIMD4<Float> {
            let (va, vb) = (SIMD3(a.x, a.y, a.z), SIMD3(b.x, b.y, b.z))
            let vector = va * b.w + vb * a.w + vecCross(va, vb)
            return SIMD4(vector.x, vector.y, vector.z, a.w * b.w - (va * vb).sum())
        }
        let result = multiply(multiply(axis(1), axis(0)), axis(2))
        return result / (result * result).sum().squareRoot()
    }
}

func doubles(_ values: [Float]) -> [Double] { values.map(Double.init) }

func doubles<Vector: SIMD>(_ vector: Vector) -> [Double] where Vector.Scalar == Float { vector.indices.map { Double(vector[$0]) } }

func vecDot(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float { (a * b).sum() }

func vecDistance(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float { vecDot(a - b, a - b).squareRoot() }

func vecNormalize(_ a: SIMD2<Float>) -> SIMD2<Float> { a / max(vecDot(a, a).squareRoot(), 1e-12) }

func vecLength(_ a: SIMD3<Float>) -> Float { (a * a).sum().squareRoot() }

func vecNormalize(_ a: SIMD3<Float>) -> SIMD3<Float> { a / max(vecLength(a), 1e-12) }

func vecCross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}
