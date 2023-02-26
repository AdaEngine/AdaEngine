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

// TODO: (Vlad) Time for Windows OS

/// Represent time interval in system.
public typealias TimeInterval = Float
public typealias LongTimeInterval = Double

public struct Time {
    /// Return current time in system.
    public static var absolute: LongTimeInterval {
        #if os(iOS) || os(tvOS) || os(OSX) || os(watchOS)
        return LongTimeInterval(CACurrentMediaTime())
        #else
        var time = timespec()
        clock_gettime(CLOCK_MONOTONIC, &time)

        return LongTimeInterval(time.tv_sec) + LongTimeInterval(time.tv_nsec) / LongTimeInterval(1.0e-9)
        #endif
    }
}
