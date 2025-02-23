//
//  Macro.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/14/24.
//

#if swift(>=5.9)

// TODO: Add reflrection support

@attached(member)
@attached(extension, names: arbitrary, conformances: Component)
public macro Component() = #externalMacro(module: "AdaEngineMacros", type: "ComponentMacro")

@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro Entry() = #externalMacro(module: "AdaEngineMacros", type: "EntryMacro")
#endif
