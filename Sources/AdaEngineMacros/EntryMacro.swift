//
//  EntryMacro.swift
//  AdaEngineMacros
//
//  Created by Vladislav Prusakov on 15.07.2024.
//

import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public struct EntryMacro { }

extension EntryMacro: AccessorMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingAccessorsOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.AccessorDeclSyntax] {
        guard let binding = declaration.as(VariableDeclSyntax.self)?.bindings.first else {
            throw MacroError.macroUsage("Entry macro can be applied only for properties.")
        }
        
        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            throw MacroError.macroUsage("Can't get property name.")
        }
        
        let getAccessor: AccessorDeclSyntax = "get { self[__Key_\(raw: identifier).self] }"
        let setAccessor: AccessorDeclSyntax = "set { self[__Key_\(raw: identifier).self] = newValue }"
        
        return [getAccessor, setAccessor]
    }
}

// TODO: Modifiers as `any ButtonStyle` doesn't works
// TODO: Can't create macro if we not defined type `@Entry var myObject = MyObject()`

extension EntryMacro: PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let binding = declaration.as(VariableDeclSyntax.self)?.bindings.first else {
            throw MacroError.macroUsage("Entry macro can be applied only for properties.")
        }
        
        guard let identifierSyntax = binding.pattern.as(IdentifierPatternSyntax.self) else {
            throw MacroError.macroUsage("Can't get property name.")
        }
        
        let identifier = identifierSyntax.identifier.text
        
        guard let typeSyntax = binding.typeAnnotation?.type else {
            throw MacroError.macroUsage("Can't get a property type.")
        }
        
        let isOptional = typeSyntax.is(OptionalTypeSyntax.self)
        
        var defaultValue = ""
        if let value = binding.initializer?.value {
            defaultValue = " = \(value)"
        } else if isOptional {
            defaultValue = " = nil"
        }
        
        if defaultValue.isEmpty && !isOptional {
            throw MacroError.macroUsage("Value couldn't be nil if type isn't optional.")
        }
        
        guard let type = typeSyntax.identifier else {
            throw MacroError.macroUsage("Can't detect a property type.")
        }
        
        let typeString = "\(type)" + (isOptional ? "?" : "")
        
        let newKeyStruct: DeclSyntax =
        """
        private struct __Key_\(raw: identifier): EnvironmentKey {
            typealias Value = \(raw: typeString)
            static let defaultValue: Value\(raw: defaultValue)
        }
        """
        
        return [newKeyStruct]
    }
}
