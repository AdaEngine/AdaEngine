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

@attached(member, names: named(queries), named(dependencies))
@attached(extension, names: arbitrary, conformances: System)
public macro System(dependencies: [SystemDependency] = []) = #externalMacro(module: "AdaEngineMacros", type: "SystemMacro")

@attached(peer, names: suffixed(SystemFunc), conformances: System)
public macro SystemFunc(dependencies: [SystemDependency] = []) = #externalMacro(module: "AdaEngineMacros", type: "SystemMacro")

#endif

