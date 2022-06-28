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

/// Represent time interval in system.
public typealias TimeInterval = Float

public struct Time {
    /// Return current time in system.
    public static var absolute: TimeInterval {
        #if os(iOS) || os(tvOS) || os(OSX) || os(watchOS)
        return TimeInterval(CACurrentMediaTime())
        #else
        var time = timespec()
        clock_gettime(CLOCK_MONOTONIC, &time)

        return TimeInterval(time.tv_sec) + TimeInterval(time.tv_nsec) / TimeInterval(1.0e-9)
        #endif
    }
}
