//
//  MacroError.swift
//  AdaEngineMacro
//
//  Created by Vladislav Prusakov on 06.07.2024.
//

import SwiftSyntax
import SwiftDiagnostics

enum MacroError: Error, CustomStringConvertible {

    case macroUsage(String)

    var description: String {
        switch self {
        case .macroUsage(let text):
            return text
        }
    }
}
