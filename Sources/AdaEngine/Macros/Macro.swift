//
//  Macro.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/14/24.
//

#if swift(>=5.9)

// TODO: Add reflrection support

@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro Entry() = #externalMacro(module: "AdaEngineMacros", type: "EntryMacro")
#endif
