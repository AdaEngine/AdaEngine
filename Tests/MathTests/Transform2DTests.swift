//
//  Transform2DTests.swift
//  
//
//  Created by v.prusakov on 5/22/22.
//

import XCTest
@testable import Math

#if canImport(simd)
import simd
#endif

#if canImport(QuartzCore)
import QuartzCore
#endif

class Transform2DTests: XCTestCase {
    
    #if canImport(QuartzCore)
    func test_transform3DToAffineTransform_Equals_QuartzAnalog() {
        // given
        let caTranslation = CATransform3DMakeTranslation(30, 4, 30)
        let caRotation = CATransform3DMakeRotation(54, 0, 1, 0)
        let caScale = CATransform3DMakeScale(2, 2, 2)
        let caTransform = CATransform3DConcat(CATransform3DConcat(caTranslation, caRotation), caScale)
        
        let myTransform = Transform3D(
            translation: [30, 4, 30],
            rotation: Quat(axis: [0, 1, 0], angle: 54),
            scale: [2, 2, 2])
        
        // when
        let cgAffine = CATransform3DGetAffineTransform(caTransform)
        let myAffine = Transform2D(transform: myTransform)
        
        // then
        TestUtils.assertEqual(cgAffine, myAffine)
    }
    
    func test_applyingTransformOnPoint_Equals_QuartzAnalog() {
        // given
        let cgPoint = CGPoint(x: 54, y: 21)
        let point = Point(x: 54, y: 21)
        
        let affine = CGAffineTransform(translationX: 32, y: 2).rotated(by: 20)
        let myAffine = Transform2D(translation: [32, 2]).rotated(by: 20)
        
        // when
        
        let newCGPoint = cgPoint.applying(affine)
        let myAffinePoint = point.applying(myAffine)
        
        // then
        
        TestUtils.assertEqual(newCGPoint, myAffinePoint)
    }
    
    func test_RectApplyingMatrix_Equals_QuartzAnalog() {
        // given
        let rect = Rect(x: 59, y: 43, width: 200, height: 110)
        let cgRect = CGRect(x: 59, y: 43, width: 200, height: 110)
        
        let affine = CGAffineTransform(translationX: 32, y: 2)//.rotated(by: 20)
        let myAffine = Transform2D(translation: [32, 2])//.rotated(by: 20)
        
        // when
        
        let newCGRect = cgRect.applying(affine)
        let newRect = rect.applying(myAffine)
        
        // then
        
        TestUtils.assertEqual(newCGRect, newRect)
    }
    
    
    #endif
}
