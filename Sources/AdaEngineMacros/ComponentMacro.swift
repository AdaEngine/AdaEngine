//
//  ComponentMacro.swift
//
//
//  Created by v.prusakov on 2/14/24.
//

import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public struct ComponentMacro: ExtensionMacro {
    public static func expansion<D: DeclGroupSyntax, T: TypeSyntaxProtocol, C: MacroExpansionContext>(
        of node: SwiftSyntax.AttributeSyntax,
        attachedTo declaration: D,
        providingExtensionsOf type: T,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: C
    ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
        if let inheritanceClause = declaration.inheritanceClause,
           inheritanceClause.inheritedTypes.contains(where: {
               ["Component"].withQualified.contains($0.type.trimmedDescription)
           }) {
            return []
        }
        
        let proto = "AdaEngine.Component"
        
        let ext: DeclSyntax =
      """
      \(declaration.attributes.availability)extension \(type.trimmed): \(raw: proto) { }
      """
        
        return [ext.cast(ExtensionDeclSyntax.self)]
    }
}

extension ComponentMacro: MemberMacro {
    public static func expansion<D: DeclGroupSyntax, C: MacroExpansionContext>(
        of node: AttributeSyntax,
        providingMembersOf declaration: D,
        in context: C
    ) throws -> [DeclSyntax] {
        return []
    }
}
