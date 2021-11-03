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

public typealias TimeInterval = Float

public struct Time {
    public static var deltaTime: TimeInterval = 0
    
    public static var absolute: TimeInterval {
        #if os(iOS) || os(tvOS) || os(OSX) || os(watchOS)
        return TimeInterval(CACurrentMediaTime())
        #else
        var t = timespec()
        clock_gettime(CLOCK_MONOTONIC, &t)

        return TimeInterval(t.tv_sec) + TimeInterval(t.tv_nsec) / TimeInterval(1.0e-9)
        #endif
    }
}
