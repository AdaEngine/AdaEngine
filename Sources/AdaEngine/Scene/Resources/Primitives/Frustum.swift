//
//  Frustum.swift
//  
//
//  Created by v.prusakov on 2/7/23.
//

public struct Frustum: Hashable, Codable {
    var planes: FixedArray<Plane> = FixedArray(repeating: Plane(normal: .zero, d: 0), count: 6)
}

public extension Frustum {
    static func make(from viewProjection: Transform3D) -> Frustum {
        var frustum = Self.makeWithoutFar(from: viewProjection)
        frustum.planes[5] = Plane(normal_d: viewProjection.row(at: 2))
        return frustum
    }
    
    static func makeWithoutFar(from viewProjection: Transform3D) -> Frustum {
        let row3 = viewProjection.row(at: 3)
        var frustum = Frustum()
        
        for index in 0 ..< frustum.planes.count - 1 {
            let row = viewProjection.row(at: index / 2)
            
            let plane: Plane
            
            if (index & 1) == 0 && index != 4 {
                plane = Plane(normal_d: row3 + row)
            } else {
                plane = Plane(normal_d: row3 - row)
            }
            
            frustum.planes[index] = plane
        }
        
        return frustum
    }
}
