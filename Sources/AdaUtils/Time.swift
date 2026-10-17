//
//  Time.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/9/21.
//

import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
    import QuartzCore
#endif
#if os(macOS)
    import Quartz
#endif
#if os(Android)
    import Android
#elseif os(Linux)
    import Glibc
#elseif os(Windows)
    import WinSDK
#endif

/// Represent time interval in system.
public typealias TimeInterval = Float
public typealias LongTimeInterval = Double

/// A helper for works with time.
public struct Time {
    /// Return current time in system.
    public static var absolute: LongTimeInterval {
        #if os(iOS) || os(tvOS) || os(visionOS) || os(OSX) || os(watchOS)
            return LongTimeInterval(CACurrentMediaTime())
        #elseif os(Windows)
            // Foundation's Windows uptime clock advances in ~15 ms steps. Frame
            // deltas and pacing need the monotonic, high-resolution QPC clock.
            var counter = LARGE_INTEGER()
            if let secondsPerTick, unsafe QueryPerformanceCounter(&counter) {
                return unsafe LongTimeInterval(counter.QuadPart) * secondsPerTick
            }
            return ProcessInfo.processInfo.systemUptime
        #elseif os(Android)
            return ProcessInfo.processInfo.systemUptime
        #elseif os(WASI)
            return LongTimeInterval(Date().timeIntervalSince1970)
        #else
            var time = timespec()
            guard unsafe clock_gettime(CLOCK_MONOTONIC, &time) == 0 else {
                return ProcessInfo.processInfo.systemUptime
            }

            return LongTimeInterval(time.tv_sec) + LongTimeInterval(time.tv_nsec) * 1.0e-9
        #endif
    }

    #if os(Windows)
    // QPC's frequency is fixed at boot and shared across processors. Cache only
    // this immutable conversion factor; each read obtains a fresh counter.
    private static let secondsPerTick: LongTimeInterval? = {
        var frequency = LARGE_INTEGER()
        guard unsafe QueryPerformanceFrequency(&frequency), unsafe frequency.QuadPart > 0 else {
            return nil
        }
        return unsafe 1 / LongTimeInterval(frequency.QuadPart)
    }()
    #endif
}
