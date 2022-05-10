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
        let simdMatrix = matrix_float4x4(columns1) * matrix_float4x4(columns2)
        let transform = Transform3D(columns: columns1) * Transform3D(columns: columns2)
        
        // then
        assertMatrixEquals(simdMatrix, transform)
    }
    
    func test_QuatFromSimdQuat_AreEquals() {
        // given
        let simdQuat = simd_quatf(ix: 3, iy: 2, iz: 1, r: 1)
        
        // when
        let quat = Quat(simdQuat)
        
        // then
        assertQuatEquals(simdQuat, quat)
        
    }
    
    func test_quatToMatrixAndSimdQuatToMatrix_AreEquals() {
        // given
        let quat = simd_quatf(ix: 3, iy: 2, iz: 1, r: 1)
        
        // when
        let simdMatrix = simd_matrix4x4(quat)
        let transform = Transform3D(quat: Quat(quat))
        
        // then
        assertMatrixEquals(simdMatrix, transform)
    }
    
    func test_quatFromMatrixAndSimdQuatFromMatrix_AreEquals() {
        // given
        let columns = [
            Vector4(1, 2, 0, 4),
            Vector4(0, 1, 3, 4),
            Vector4(5, 0, 1, 9),
            Vector4(4, 0, 0, 1)
        ]
        
        let matrix = matrix_float4x4(columns)
        let transform = Transform3D(columns: columns)
        
        // when
        let simdQuat = simd_quatf(matrix)
        let quat = transform.rotation
        
        // then
        assertQuatEquals(simdQuat, quat, accuracy: 0.1)
    }
    
    func test_quatNormalizedAndSimdQuatNormalized_AreEquals() {
        // given
        
        let quatVector = Vector4(3, 2, 1, 1)
        
        let quat = Quat(x: quatVector.x, y: quatVector.y, z: quatVector.z, w: quatVector.w)
        let simdQuat = simd_quatf(vector: quatVector)
        
        // when
        
        let quatNormalized = quat.normalized
        let simdQuatNormalized = simdQuat.normalized
        
        // then
        
        assertQuatEquals(simdQuatNormalized, quatNormalized)
    }
    
    func test_Transform3DMultipleVec4_And_SimdMatrix4MultipleVec4_AreEquals() {
        // given
        let columns = [
            Vector4(1, 2, 0, 4),
            Vector4(0, 1, 3, 4),
            Vector4(5, 0, 1, 9),
            Vector4(4, 0, 0, 1)
        ]
        
        var simdMat = simd_float4x4(columns)
        var transform = Transform3D(columns: columns)
        
        let vec4: Vector4 = [1, 2, 1, 2]
        
        // when
        
        let simdVec = simdMat * vec4
        let myVec = transform * vec4
        
        // then
        
        XCTAssertEqual(simdVec, myVec)
    }
    
    func test_Transform3DInitializedFromSimd4x4Matrix_AreEquals() {
        // given
        let simdMatrix = matrix_float4x4([1, 2, 3, 4], [5, 6, 7, 8], [9, 7, 6, 5], [2, 3, 5, 7])
        let columns = simdMatrix.columns
        
        // when
        let transform = Transform3D(columns: [columns.0, columns.1, columns.2, columns.3])
        
        // then
        
        assertMatrixEquals(simdMatrix, transform)
    }
    
    private func assertMatrixEquals(_ simd_matrix: matrix_float4x4, _ transform: Transform3D) {
        XCTAssertEqual(simd_matrix[0, 0], transform[0, 0])
        XCTAssertEqual(simd_matrix[0, 1], transform[0, 1])
        XCTAssertEqual(simd_matrix[0, 2], transform[0, 2])
        XCTAssertEqual(simd_matrix[0, 3], transform[0, 3])
        
        XCTAssertEqual(simd_matrix[1, 0], transform[1, 0])
        XCTAssertEqual(simd_matrix[1, 1], transform[1, 1])
        XCTAssertEqual(simd_matrix[1, 2], transform[1, 2])
        XCTAssertEqual(simd_matrix[1, 3], transform[1, 3])
        
        XCTAssertEqual(simd_matrix[2, 0], transform[2, 0])
        XCTAssertEqual(simd_matrix[2, 1], transform[2, 1])
        XCTAssertEqual(simd_matrix[2, 2], transform[2, 2])
        XCTAssertEqual(simd_matrix[2, 3], transform[2, 3])
        
        XCTAssertEqual(simd_matrix[3, 0], transform[3, 0])
        XCTAssertEqual(simd_matrix[3, 1], transform[3, 1])
        XCTAssertEqual(simd_matrix[3, 2], transform[3, 2])
        XCTAssertEqual(simd_matrix[3, 3], transform[3, 3])
    }
    
    private func assertQuatEquals(_ simd_quat: simd_quatf, _ quat: Quat, accuracy: Float = 0.0000001) {
        XCTAssertEqual(simd_quat.vector.x, quat.x, accuracy: accuracy)
        XCTAssertEqual(simd_quat.vector.y, quat.y, accuracy: accuracy)
        XCTAssertEqual(simd_quat.vector.z, quat.z, accuracy: accuracy)
        XCTAssertEqual(simd_quat.vector.w, quat.w, accuracy: accuracy)
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
