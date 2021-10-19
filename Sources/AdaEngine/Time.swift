//
//  Time.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//


#if os(iOS) || os(tvOS)
import QuartzCore
#endif
#if os(macOS)
import Quartz
#endif
#if os(Android) || os(Linux)
import Glibc
#endif

public struct Time {
    public static var deltaTime: Float = 0
    
    public static var absolute: Float {
        #if os(iOS) || os(tvOS) || os(OSX) || os(watchOS)
        return Float(CACurrentMediaTime())
        #else
        var t = timespec()
        clock_gettime(CLOCK_MONOTONIC, &t)

        return Float(t.tv_sec) + Float(t.tv_nsec) / Float(1.0e-9)
        #endif
    }
}
