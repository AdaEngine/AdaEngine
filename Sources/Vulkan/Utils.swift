//
//  Utils.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

#if os(macOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

func convertTupleToUnsafePointer<T, U>(tuple: T, type: U.Type) -> UnsafePointer<U> {
    return withUnsafePointer(to: tuple) { pointer in
        pointer.withMemoryRebound(to: type, capacity: 1) { $0 }
    }
}

import Foundation

extension String {
    func asCString() -> UnsafePointer<CChar>? {
//        let cString = self.withCString { $0 }
        let cString = (self as NSString).utf8String
        print("Convert", self, "as", String(cString: cString!, encoding: .utf8))
        return cString
    }
}
