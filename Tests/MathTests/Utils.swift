//
//  Utils.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/22/22.
//

import Numerics
import Testing

@testable import Math

#if canImport(simd)
    import simd
#endif

#if canImport(QuartzCore)
    import QuartzCore
#endif

enum TestUtils {

    #if canImport(simd)

        static func assertEqual(
            _ simd_matrix: matrix_float4x4, _ transform: Transform3D, accuracy: Float = 0.00001
        ) {
            #expect(
                simd_matrix[0, 0].isApproximatelyEqual(
                    to: transform[0, 0], absoluteTolerance: accuracy))
            #expect(simd_matrix[0, 1] == transform[0, 1])
            #expect(simd_matrix[0, 2] == transform[0, 2])
            #expect(simd_matrix[0, 3] == transform[0, 3])

            #expect(simd_matrix[1, 0] == transform[1, 0])
            #expect(simd_matrix[1, 1] == transform[1, 1])
            #expect(simd_matrix[1, 2] == transform[1, 2])
            #expect(simd_matrix[1, 3] == transform[1, 3])

            #expect(simd_matrix[2, 0] == transform[2, 0])
            #expect(simd_matrix[2, 1] == transform[2, 1])
            #expect(simd_matrix[2, 2] == transform[2, 2])
            #expect(simd_matrix[2, 3] == transform[2, 3])

            #expect(simd_matrix[3, 0] == transform[3, 0])
            #expect(simd_matrix[3, 1] == transform[3, 1])
            #expect(simd_matrix[3, 2] == transform[3, 2])
            #expect(simd_matrix[3, 3] == transform[3, 3])
        }

        static func assertEqual(_ simd_quat: simd_quatf, _ quat: Quat, accuracy: Float = 0.00001) {
            #expect(
                simd_quat.vector.x.isApproximatelyEqual(to: quat.x, absoluteTolerance: accuracy))
            #expect(
                simd_quat.vector.y.isApproximatelyEqual(to: quat.y, absoluteTolerance: accuracy))
            #expect(
                simd_quat.vector.z.isApproximatelyEqual(to: quat.z, absoluteTolerance: accuracy))
            #expect(
                simd_quat.vector.w.isApproximatelyEqual(to: quat.w, absoluteTolerance: accuracy))
        }

    #endif

    #if canImport(QuartzCore)

        static func assertEqual(_ caTransform3D: CATransform3D, _ transform: Transform3D) {
            #expect(Float(caTransform3D.m11) == transform[0, 0])
            #expect(Float(caTransform3D.m12) == transform[1, 0])
            #expect(Float(caTransform3D.m13) == transform[2, 0])
            #expect(Float(caTransform3D.m14) == transform[3, 0])

            #expect(Float(caTransform3D.m21) == transform[0, 1])
            #expect(Float(caTransform3D.m22) == transform[1, 1])
            #expect(Float(caTransform3D.m23) == transform[2, 1])
            #expect(Float(caTransform3D.m24) == transform[3, 1])

            #expect(Float(caTransform3D.m31) == transform[0, 2])
            #expect(Float(caTransform3D.m32) == transform[1, 2])
            #expect(Float(caTransform3D.m33) == transform[2, 2])
            #expect(Float(caTransform3D.m34) == transform[3, 2])

            #expect(Float(caTransform3D.m41) == transform[0, 3])
            #expect(Float(caTransform3D.m42) == transform[1, 3])
            #expect(Float(caTransform3D.m43) == transform[2, 3])
            #expect(Float(caTransform3D.m44) == transform[3, 3])
        }

        static func assertEqual(
            _ cgAffineTransform: CGAffineTransform,
            _ transform: Transform2D,
            accuracy: Float = 0.00001
        ) {
            #expect(
                cgAffineTransform.a.isApproximatelyEqual(
                    to: CGFloat(transform[0, 0]),
                    absoluteTolerance: CGFloat(accuracy)
                )
            )
            #expect(
                cgAffineTransform.b.isApproximatelyEqual(
                    to: CGFloat(transform[0, 1]), absoluteTolerance: CGFloat(accuracy)))
            #expect(
                cgAffineTransform.c.isApproximatelyEqual(
                    to: CGFloat(transform[1, 0]), absoluteTolerance: CGFloat(accuracy)))
            #expect(
                cgAffineTransform.d.isApproximatelyEqual(
                    to: CGFloat(transform[1, 1]), absoluteTolerance: CGFloat(accuracy)))

            #expect(
                cgAffineTransform.tx.isApproximatelyEqual(
                    to: CGFloat(transform[2, 0]), absoluteTolerance: CGFloat(accuracy)))
            #expect(
                cgAffineTransform.ty.isApproximatelyEqual(
                    to: CGFloat(transform[2, 1]), absoluteTolerance: CGFloat(accuracy)))
        }

        static func assertEqual(
            _ cgPoint: CGPoint,
            _ point: Point,
            accuracy: Float = 0.00001
        ) {
            #expect(
                cgPoint.x.isApproximatelyEqual(
                    to: CGFloat(point.x), absoluteTolerance: CGFloat(accuracy)))
            #expect(
                cgPoint.y.isApproximatelyEqual(
                    to: CGFloat(point.y), absoluteTolerance: CGFloat(accuracy)))
        }

        static func assertEqual(
            _ cgRect: CGRect,
            _ rect: Rect,
            accuracy: Float = 0.00001
        ) {
            #expect(
                cgRect.minX.isApproximatelyEqual(
                    to: CGFloat(rect.minX), absoluteTolerance: CGFloat(accuracy)))
            #expect(
                cgRect.minY.isApproximatelyEqual(
                    to: CGFloat(rect.minY), absoluteTolerance: CGFloat(accuracy)))
            #expect(
                cgRect.maxX.isApproximatelyEqual(
                    to: CGFloat(rect.maxX), absoluteTolerance: CGFloat(accuracy)))
            #expect(
                cgRect.maxY.isApproximatelyEqual(
                    to: CGFloat(rect.maxY), absoluteTolerance: CGFloat(accuracy)))
        }

    #endif

}

#if canImport(simd)

    extension Math.Vector2 {
        var simd: SIMD2<Float> {
            return [x, y]
        }
    }

    extension Math.Vector3 {
        var simd: SIMD3<Float> {
            return [x, y, z]
        }
    }

    extension Math.Vector4 {
        var simd: SIMD4<Float> {
            return [x, y, z, w]
        }
    }

    extension simd_float4x4 {
        init(columnsVector4: [Math.Vector4]) {
            self.init(columnsVector4.map { $0.simd })
        }
    }

    extension SIMD3 where Scalar == Float {
        var vec: Math.Vector3 {
            return [x, y, z]
        }
    }

    extension SIMD2 where Scalar == Float {
        var vec: Math.Vector2 {
            return [x, y]
        }
    }

    extension SIMD4 where Scalar == Float {
        var vec: Math.Vector4 {
            return [x, y, z, w]
        }
    }
#endif
