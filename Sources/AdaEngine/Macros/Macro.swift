//
//  Macro.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/14/24.
//

#if swift(>=5.9)

@attached(member)
@attached(extension, conformances: Component)
public macro Component() = #externalMacro(module: "AdaEngineMacros", type: "ComponentMacro")

#endif
