/**
 Copyright (c) 2006-2014 Erin Catto http://www.box2d.org
 Copyright (c) 2015 - Yohei Yoshihara
 
 This software is provided 'as-is', without any express or implied
 warranty.  In no event will the authors be held liable for any damages
 arising from the use of this software.
 
 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely, subject to the following restrictions:
 
 1. The origin of this software must not be misrepresented; you must not
 claim that you wrote the original software. If you use this software
 in a product, an acknowledgment in the product documentation would be
 appreciated but is not required.
 
 2. Altered source versions must be plainly marked as such, and must not be
 misrepresented as being the original software.
 
 3. This notice may not be removed or altered from any source distribution.
 
 This version of box2d was developed by Yohei Yoshihara. It is based upon
 the original C++ code written by Erin Catto.
 */

public let b2_minFloat = Float.leastNormalMagnitude
public let b2_maxFloat = Float.greatestFiniteMagnitude
public let b2_epsilon = Float.ulpOfOne
public let b2_pi: b2Float = Float.pi

/// @file
/// Global tuning constants based on meters-kilograms-seconds (MKS) units.
///

// Collision

/// The maximum number of contact points between two convex shapes. Do
/// not change this value.
public let b2_maxManifoldPoints = 2

/// The maximum number of vertices on a convex polygon. You cannot increase
/// this too much because b2BlockAllocator has a maximum object size.
public let b2_maxPolygonVertices	= 8

/// This is used to fatten AABBs in the dynamic tree. This allows proxies
/// to move by a small amount without triggering a tree adjustment.
/// This is in meters.
public let b2_aabbExtension: b2Float = 0.1

/// This is used to fatten AABBs in the dynamic tree. This is used to predict
/// the future position based on the current displacement.
/// This is a dimensionless multiplier.
public let b2_aabbMultiplier: b2Float = 2.0

/// A small length used as a collision and constraint tolerance. Usually it is
/// chosen to be numerically significant, but visually insignificant.
public let b2_linearSlop: b2Float = 0.005

/// A small angle used as a collision and constraint tolerance. Usually it is
/// chosen to be numerically significant, but visually insignificant.
public let b2_angularSlop: b2Float = (2.0 / 180.0 * b2_pi)

/// The radius of the polygon/edge shape skin. This should not be modified. Making
/// this smaller means polygons will have an insufficient buffer for continuous collision.
/// Making it larger may create artifacts for vertex collision.
public let b2_polygonRadius: b2Float = (2.0 * b2_linearSlop)

/// Maximum number of sub-steps per contact in continuous physics simulation.
public let b2_maxSubSteps = 8


// Dynamics

/// Maximum number of contacts to be handled to solve a TOI impact.
public let b2_maxTOIContacts = 32

/// A velocity threshold for elastic collisions. Any collision with a relative linear
/// velocity below this threshold will be treated as inelastic.
public let b2_velocityThreshold: b2Float = 1.0

/// The maximum linear position correction used when solving constraints. This helps to
/// prevent overshoot.
public let b2_maxLinearCorrection: b2Float = 0.2

/// The maximum angular position correction used when solving constraints. This helps to
/// prevent overshoot.
public let b2_maxAngularCorrection: b2Float = (8.0 / 180.0 * b2_pi)

/// The maximum linear velocity of a body. This limit is very large and is used
/// to prevent numerical problems. You shouldn't need to adjust this.
public let b2_maxTranslation: b2Float = 2.0
public let b2_maxTranslationSquared: b2Float = (b2_maxTranslation * b2_maxTranslation)

/// The maximum angular velocity of a body. This limit is very large and is used
/// to prevent numerical problems. You shouldn't need to adjust this.
public let b2_maxRotation: b2Float = (0.5 * b2_pi)
public let b2_maxRotationSquared: b2Float = (b2_maxRotation * b2_maxRotation)

/// This scale factor controls how fast overlap is resolved. Ideally this would be 1 so
/// that overlap is removed in one time step. However using values close to 1 often lead
/// to overshoot.
public let b2_baumgarte: b2Float = 0.2
public let b2_toiBaugarte: b2Float = 0.75


// Sleep

/// The time that a body must be still before it will go to sleep.
public let b2_timeToSleep: b2Float = 0.5

/// A body cannot sleep if its linear velocity is above this tolerance.
public let b2_linearSleepTolerance: b2Float = 0.01

/// A body cannot sleep if its angular velocity is above this tolerance.
public let b2_angularSleepTolerance: b2Float = (2.0 / 180.0 * b2_pi)

/// Version numbering scheme.
/// See http://en.wikipedia.org/wiki/Software_versioning
public struct b2Version
{
    var major : Int		///< significant changes
    var minor : Int		///< incremental changes
    var revision : Int		///< bug fixes
}

/// Current version.
public let b2_version = b2Version(major: 2, minor: 3, revision: 0)



