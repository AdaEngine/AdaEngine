//
//  Helpers.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

// TODO: Think about it later. Maybe we should use some namespace

/// Call fatal if method not implemented
func fatalErrorMethodNotImplemented(
    functionName: String = #function,
    line: Int = #line,
    file: String = #fileID
) -> Never {
    fatalError("Method \(functionName):\(line) not implemented in \(file).")
}

@inlinable public func assert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    Swift.assert(condition(), message(), file: file, line: line)
}

@inlinable public func assertionFailure(_ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    Swift.assertionFailure(message(), file: file, line: line)
}

@inlinable public func preconditionMainThreadOnly(_ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    assert(Thread.isMainThread, message(), file: file, line: line)
}
