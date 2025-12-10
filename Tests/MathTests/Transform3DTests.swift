//
//  Transform3DTest.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/4/22.
//

import Testing

@testable import Math
#if canImport(simd)
import simd
#endif

#if canImport(QuartzCore)
import QuartzCore
#endif

@Suite("Transform 3D Tests")
struct Transform3DTests {
    @Test func `matrix scale`() {
        // given
        var a = Transform3D(columns: [
            [1, 2, 3, 4],
            [5, 6, 7, 8],
            [9, 10, 11, 12],
            [13, 14, 15, 16]
        ])
        let b = Vector3(2, 3, 4)
        let c = Transform3D(columns: [
            [2, 6, 12, 4],
            [10, 18, 28, 8],
            [18, 30, 44, 12],
            [26, 42, 60, 16]
        ])
        
        // then
        a.scale = b
        
        // when
        #expect(a == c)
    }
    
    @Test func `matrix multiply`() {
        // given
        let matA = Transform3D(
            [5, 7, 9, 10],
            [2, 3, 3, 8],
            [8, 10, 2, 3],
            [3, 3, 4, 8]
        )
        
        let matB = Transform3D(
            [3, 10, 12, 18],
            [12, 1, 4, 9],
            [9, 10, 12, 2],
            [3, 12, 4, 10]
        )
        
        let expectedRes = Transform3D(
            [210, 267, 236, 271],
            [93, 149, 104, 149],
            [171, 146, 172, 268],
            [105, 169, 128, 169]
        )
        
        // when
        let res = matB * matA
        
        // then
        #expect(expectedRes == res)
    }
    
    #if canImport(QuartzCore)
    @Test
    func `affine Transform To 3D equals Quartz affine to Transform3D`() {
        // given
        let cgAffine = CGAffineTransform(translationX: 30, y: 4).scaledBy(x: 2, y: 2).rotated(by: 30)
        let myAffine = Transform2D(translation: [30, 4]).scaledBy(x: 2, y: 2).rotated(by: 30)
        
        // when
        let caTransform3D = CATransform3DMakeAffineTransform(cgAffine)
        let myTransform3D = Transform3D(fromAffineTransform: myAffine)
        
        // then
        TestUtils.assertEqual(cgAffine, myAffine)
        TestUtils.assertEqual(caTransform3D, myTransform3D)
    }
    #endif
}

#if canImport(simd)
extension Transform3DTests {
    @Test func `transform3D multiplication and simd4x4 multiplication equals`() {
        // given
        let columns1 = [
            Vector4(1, 2, 0, 4),
            Vector4(0, 1, 3, 4),
            Vector4(5, 0, 1, 9),
            Vector4(4, 0, 0, 1)
        ]

        let columns2 = [
            Vector4(1, 0, 0, 6),
            Vector4(0, 1, 0, 5),
            Vector4(0, 0, 1, 0),
            Vector4(0, 0, 0, 1)
        ]

        // when
        let simdMatrix = matrix_float4x4(columnsVector4: columns1) * matrix_float4x4(columnsVector4: columns2)
        let transform = Transform3D(columns: columns1) * Transform3D(columns: columns2)

        // then
        TestUtils.assertEqual(simdMatrix, transform)
    }

    @Test func `transform3D inverse and simd4x4 inverse equals`() {
        // given
        let columns1 = [
            Vector4(1, 2, 5, 4),
            Vector4(3, 1, 3, 4),
            Vector4(5, 1, 1, 9),
            Vector4(4, 2, 5, 1)
        ]

        // when
        let simdMatrix = matrix_float4x4(columnsVector4: columns1).inverse
        let transform = Transform3D(columns: columns1).inverse

        // then
        TestUtils.assertEqual(simdMatrix, transform, accuracy: 1)
    }

    @Test func `transform3D multiplication and simd4x4 multiplication in TRS equals`() {
        // given
        let translation: Vector3 = [3, 10, 3]
        let rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        let scale: Vector3 = [1, 1, 1]

        // when

        let simdMatrix = simd_float4x4([
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [translation.x, translation.y, translation.z, 1],
        ])
        * simd_float4x4(rotation)
        * simd_float4x4(diagonal: Vector4(scale, 1).simd)

        let transform = Transform3D(translation: translation, rotation: Quat(rotation), scale: scale)

        // then
        TestUtils.assertEqual(simdMatrix, transform)
    }

    @Test func `quat from simd quat are equals`() {
        // given
        let simdQuat = simd_quatf(ix: 3, iy: 2, iz: 1, r: 1)

        // when
        let quat = Quat(simdQuat)

        // then
        TestUtils.assertEqual(simdQuat, quat)
    }

    @Test func `quat to matrix and simd quat to matrix are equals`() {
        // given
        let quat = simd_quatf(ix: 3, iy: 2, iz: 1, r: 1)

        // when
        let simdMatrix = simd_matrix4x4(quat)
        let transform = Transform3D(quat: Quat(quat))

        // then
        TestUtils.assertEqual(simdMatrix, transform)
    }

    @Test func `quat from matrix and simd quat from matrix are equals`() {
        // given
        let columns = [
            Vector4(1, 2, 0, 4),
            Vector4(0, 1, 3, 4),
            Vector4(5, 0, 1, 9),
            Vector4(4, 0, 0, 1)
        ]

        let matrix = matrix_float4x4(columnsVector4: columns)
        let transform = Transform3D(columns: columns)

        // when
        let simdQuat = simd_quatf(matrix)
        let quat = transform.rotation

        // then
        TestUtils.assertEqual(simdQuat, quat)
    }

    @Test func `quat normalized and simd quat normalized are equals`() {
        // given

        let quatVector = Vector4(3, 2, 1, 1)

        let quat = Quat(x: quatVector.x, y: quatVector.y, z: quatVector.z, w: quatVector.w)
        let simdQuat = simd_quatf(vector: quatVector.simd)

        // when

        let quatNormalized = quat.normalized
        let simdQuatNormalized = simdQuat.normalized

        // then

        TestUtils.assertEqual(simdQuatNormalized, quatNormalized)
    }

    @Test func `transform3D multiple vec4 and simd matrix4 multiple vec4 are equals`() {
        // given
        let columns = [
            Vector4(43, 2, 12, 4),
            Vector4(52, 12, 3, 4),
            Vector4(5, 32, 43, 9),
            Vector4(4, 55, 2, 92)
        ]

        let simdMat = simd_float4x4(columnsVector4: columns)
        let transform = Transform3D(columns: columns)

        let vec4: Vector4 = [3, 2, 6, 2]

        // when

        let simdVec = simdMat * vec4.simd
        let myVec = transform * vec4

        let invSimdVec = vec4.simd * simdMat
        let invMyVec = vec4 * transform

        // then

        #expect(simdVec == myVec.simd)
        #expect(invSimdVec == invMyVec.simd)
    }

    @Test func `transform3D initialized from simd4x4 matrix are equals`() {
        // given
        let simdMatrix = matrix_float4x4([1, 2, 3, 4], [5, 6, 7, 8], [9, 7, 6, 5], [2, 3, 5, 7])
        let columns = simdMatrix.columns

        // when
        let transform = Transform3D(columns: [
            columns.0.vec,
            columns.1.vec,
            columns.2.vec,
            columns.3.vec
        ])

        // then

        TestUtils.assertEqual(simdMatrix, transform)
    }

    @Test func `ortho transform3D multiple by vector is equal simd ortho multiply by vector`() {
        // given
        let aspectRation: Float = 800.0/600.0
        let scale: Float = 1.0

        let myTransform = Transform3D.orthographic(left: -aspectRation * scale, right: aspectRation * scale, top: scale, bottom: -scale, zNear: 0, zFar: 1)
        let simdTransform = makeOrthoSimd(left: -aspectRation * scale, right: aspectRation * scale, top: scale, bottom: -scale, zNear: 0, zFar: 1)

        let vector: Vector4 = [12, 5, 8, 1]

        // when
        let resMyVector = vector * myTransform
        let resSimdVector = vector.simd * simdTransform

        // then
        #expect(resMyVector.simd == resSimdVector)
    }

    @Test func `transform3D rows init equals simd rows init`() {
        // given
        let rows: [Vector4] = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 7, 6, 5], [2, 3, 5, 7]]
        let simdRows = unsafeBitCast(rows, to: [SIMD4<Float>].self)

        // when
        let transform = Transform3D(rows: rows)
        let simd = simd_float4x4.init(rows: simdRows)

        // then
        TestUtils.assertEqual(simd, transform)
    }

    private func makeOrthoSimd(left: Float, right: Float, top: Float, bottom: Float, zNear: Float, zFar: Float) -> float4x4 {
        let m00 = 2 / (right - left)
        let m11 = 2 / (top - bottom)
        let m22 = 1 / (zFar - zNear)
        let m03 = (left + right) / (left - right)
        let m13 = (top + bottom) / (bottom - top)
        let m23 = zNear / (zNear - zFar)

        return float4x4(
            [m00, 0,   0,   m03],
            [0,   m11, 0,   m13],
            [0,   0,   m22, m23],
            [0,   0,   0,   1]
        )
    }
}
#endif

#if canImport(simd)
public extension Quat {
    init(_ simd_quat: simd_quatf) {
        let x = simd_quat.vector.x
        let y = simd_quat.vector.y
        let z = simd_quat.vector.z
        let w = simd_quat.vector.w
        self.init(x: x, y: y, z: z, w: w)
    }
}
#endif
