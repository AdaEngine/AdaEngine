//
//  ECSMacros.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/18/25.
//

#if swift(>=5.9)

// TODO: Add reflrection support

@attached(member)
@attached(extension, names: arbitrary, conformances: Component)
public macro Component() = #externalMacro(module: "AdaEngineMacros", type: "ComponentMacro")

#endif