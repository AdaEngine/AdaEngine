//
//  Macro.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/14/24.
//

@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro Entry() = #externalMacro(module: "AdaEngineMacros", type: "EntryMacro")
