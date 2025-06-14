//
//  ComponentMacro.swift
//  AdaEngineMacros
//
//  Created by v.prusakov on 2/14/24.
//

import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public struct BundleMacro: MemberMacro, ExtensionMacro {
    // Generate the 'components' property
    public static func expansion<
        D: DeclGroupSyntax,
        C: MacroExpansionContext
    >(
        of node: AttributeSyntax,
        providingMembersOf declaration: D,
        in context: C
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.macroUsage("Bundle macro can be applied only to structs.")
        }
        let availability = declaration.modifiers
        // Collect all stored property names
        let propertyNames: [String] = structDecl.memberBlock.members.compactMap { member in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { return nil }
            guard let binding = varDecl.bindings.first else { return nil }
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { return nil }
            // Only stored properties (not computed)
            if binding.accessorBlock != nil { return nil }
            return identifier
        }

        // Generate the components property
        let componentsProperty: DeclSyntax = """
        \(availability)var components: [any Component] {
            [\(raw: propertyNames.joined(separator: ", "))]
        }
        """
        return [componentsProperty]
    }

    // Generate the extension to conform to Bundle
    public static func expansion<
        D: DeclGroupSyntax,
        T: TypeSyntaxProtocol,
        C: MacroExpansionContext
    >(
        of node: AttributeSyntax,
        attachedTo declaration: D,
        providingExtensionsOf type: T,
        conformingTo protocols: [TypeSyntax],
        in context: C
    ) throws -> [ExtensionDeclSyntax] {
        // Only add conformance if not already present
        if let inheritanceClause = declaration.inheritanceClause,
           inheritanceClause.inheritedTypes.contains(where: {
               ["Bundle", "AdaECS.Bundle"].contains($0.type.trimmedDescription)
           }) {
            return []
        }

        let ext: DeclSyntax = """
        extension \(type.trimmed): AdaECS.Bundle { }
        """
        return [ext.cast(ExtensionDeclSyntax.self)]
    }
}

