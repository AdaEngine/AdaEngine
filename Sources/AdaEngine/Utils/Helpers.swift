//
//  File.swift
//  
//
//  Created by v.prusakov on 5/31/22.
//

/// Call fatal if method not implemented
func fatalErrorMethodNotImplemented(
    functionName: String = #function,
    line: Int = #line,
    file: String = #fileID
) -> Never {
    fatalError("Method \(functionName):\(line) not implemented in \(file).")
}
