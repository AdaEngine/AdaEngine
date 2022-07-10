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

#if os(iOS) || os(tvOS)
import QuartzCore
#endif
#if os(macOS)
import Quartz
#endif
#if os(Android) || os(Linux)
import Glibc
#endif

/// Timer for profiling. This has platform specific code and may
/// not work on every platform.
open class b2Timer {
    /// Constructor
    public init() {
        m_start = Self.absolute
    }
    
    /// Reset the timer.
    open func reset() {
        m_start = Self.absolute
    }
    
    /// Get the time since construction or the last reset.
    open var milliseconds: b2Float {
        return b2Float(Self.absolute - m_start) * b2Float(1000.0)
    }
    
    var m_start: Float
    
    /// Return current time in system.
    private static var absolute: Float {
        #if os(iOS) || os(tvOS) || os(OSX) || os(watchOS)
        return Float(CACurrentMediaTime())
        #else
        var time = timespec()
        clock_gettime(CLOCK_MONOTONIC, &time)

        return Float(time.tv_sec) + Float(time.tv_nsec) / Float(1.0e-9)
        #endif
    }
}
