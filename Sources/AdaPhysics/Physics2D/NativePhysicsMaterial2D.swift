import box2d
import Math

extension PhysicsMaterial {
    var nativeSurface: b2SurfaceMaterial {
        var surface = b2DefaultSurfaceMaterial()
        surface.friction = friction
        surface.restitution = restitution
        surface.rollingResistance = rollingResistance
        surface.tangentSpeed = surfaceSpeed
        return surface
    }
}

extension Body2D {
    func updateMaterial(_ material: PhysicsMaterial, massProperties: PhysicsMassProperties? = nil) {
        guard appliedMaterial !== material else {
            return
        }
        // Initial shapes already received the complete material; don't wake initially sleeping bodies.
        guard appliedMaterial != nil else {
            appliedMaterial = material
            return
        }
        var changedDensity = false
        for shape in getShapes() where shape.isValid {
            var surface = material.nativeSurface
            surface.customColor = b2Shape_GetSurfaceMaterial(shape.nativeID).customColor
            unsafe b2Shape_SetSurfaceMaterial(shape.nativeID, &surface)
            if b2Shape_GetDensity(shape.nativeID) != material.density {
                b2Shape_SetDensity(shape.nativeID, material.density, false)
                changedDensity = true
            }
        }
        if changedDensity, let massProperties, b2Body_GetType(bodyId) == b2_dynamicBody {
            b2Body_UpdateMassFromShapes(bodyId)
            var mass = b2Body_GetMassData(bodyId)
            mass.mass = massProperties.mass
            if massProperties.inertia.z > 0 { mass.rotationalInertia = massProperties.inertia.z }
            b2Body_SetMassData(bodyId, mass)
        }
        appliedMaterial = material
        if b2Body_GetType(bodyId) == b2_dynamicBody { b2Body_SetAwake(bodyId, true) }
        b2Body_WakeTouching(bodyId)
    }
}
