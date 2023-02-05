//
//  Transform3DTest.swift
//  
//
//  Created by v.prusakov on 5/4/22.
//

import XCTest

@testable import Math
#if canImport(simd)
import simd
#endif

#if canImport(QuartzCore)
import QuartzCore
#endif

class Transform3DTests: XCTestCase {
    
    func test_MatrixScale() {
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
        XCTAssertEqual(a, c)
    }
    
    func test_MatrixMultiply() {
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
        
        XCTAssertEqual(expectedRes, res)
    }

    #if canImport(simd)
    func test_Transform3DMultiplicationAndSimd4x4Multiplication_Equals() {
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
    
    func test_Transform3DInverse_and_Simd4x4Inverse_Equals() {
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
        TestUtils.assertEqual(simdMatrix, transform)
    }
    
    func test_Transform3DMultiplicationAndSimd4x4Multiplication_inTRS_Equals() {
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
    
    func test_QuatFromSimdQuat_AreEquals() {
        // given
        let simdQuat = simd_quatf(ix: 3, iy: 2, iz: 1, r: 1)

        // when
        let quat = Quat(simdQuat)

        // then
        TestUtils.assertEqual(simdQuat, quat)
    }
    
    func test_quatToMatrixAndSimdQuatToMatrix_AreEquals() {
        // given
        let quat = simd_quatf(ix: 3, iy: 2, iz: 1, r: 1)
        
        // when
        let simdMatrix = simd_matrix4x4(quat)
        let transform = Transform3D(quat: Quat(quat))
        
        // then
        TestUtils.assertEqual(simdMatrix, transform)
    }
    
    func test_quatFromMatrixAndSimdQuatFromMatrix_AreEquals() {
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
        TestUtils.assertEqual(simdQuat, quat, accuracy: -1)
    }
    
    func test_quatNormalizedAndSimdQuatNormalized_AreEquals() {
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
    
    func test_Transform3DMultipleVec4_And_SimdMatrix4MultipleVec4_AreEquals() {
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
        
        XCTAssertEqual(simdVec, myVec.simd)
        XCTAssertEqual(invSimdVec, invMyVec.simd)
    }
    
    func test_Transform3DInitializedFromSimd4x4Matrix_AreEquals() {
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
    
    func test_OrthoTransform3DMultipleByVector_isEqual_SimdOrthoMyltiplyByVector() {
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
        XCTAssertEqual(resMyVector.simd, resSimdVector)
    }
    
    func test_Transform3DRowsInit_Equals_SimdRowsInit() {
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
    
    #endif
    
    #if canImport(QuartzCore)
    
    func test_AffineTransformTo3D_Equals_QuartzAffineToTransform3D() {
        // given
        let cgAffine = CGAffineTransform(translationX: 30, y: 4).scaledBy(x: 2, y: 2).rotated(by: 30)
        let myAffine = Transform2D(translation: [30, 4]).scaledBy(x: 2, y: 2).rotated(by: 30)
        
        // when
        let caTransform3D = CATransform3DMakeAffineTransform(cgAffine)
        let myTransform3D = Transform3D(myAffine)
        
        // then
        TestUtils.assertEqual(cgAffine, myAffine)
        TestUtils.assertEqual(caTransform3D, myTransform3D)
    }
    #endif

}

//static SIMD_NOINLINE simd_quatf simd_quaternion(simd_float3x3 matrix) {
//  const simd_float3 *mat = matrix.columns;
//  float trace = mat[0][0] + mat[1][1] + mat[2][2];
//  if (trace >= 0.0) {
//    float r = 2*sqrt(1 + trace);
//    float rinv = simd_recip(r);
//    return simd_quaternion(rinv*(mat[1][2] - mat[2][1]),
//                           rinv*(mat[2][0] - mat[0][2]),
//                           rinv*(mat[0][1] - mat[1][0]),
//                           r/4);
//  } else if (mat[0][0] >= mat[1][1] && mat[0][0] >= mat[2][2]) {
//    float r = 2*sqrt(1 - mat[1][1] - mat[2][2] + mat[0][0]);
//    float rinv = simd_recip(r);
//    return simd_quaternion(r/4,
//                           rinv*(mat[0][1] + mat[1][0]),
//                           rinv*(mat[0][2] + mat[2][0]),
//                           rinv*(mat[1][2] - mat[2][1]));
//  } else if (mat[1][1] >= mat[2][2]) {
//    float r = 2*sqrt(1 - mat[0][0] - mat[2][2] + mat[1][1]);
//    float rinv = simd_recip(r);
//    return simd_quaternion(rinv*(mat[0][1] + mat[1][0]),
//                           r/4,
//                           rinv*(mat[1][2] + mat[2][1]),
//                           rinv*(mat[2][0] - mat[0][2]));
//  } else {
//    float r = 2*sqrt(1 - mat[0][0] - mat[1][1] + mat[2][2]);
//    float rinv = simd_recip(r);
//    return simd_quaternion(rinv*(mat[0][2] + mat[2][0]),
//                           rinv*(mat[1][2] + mat[2][1]),
//                           r/4,
//                           rinv*(mat[0][1] - mat[1][0]));
//  }
//}
//

#if canImport(simd)
import simd

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
