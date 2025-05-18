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

// TODO: Support Comments for generated methods

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

        return if let structDecl = declaration.as(StructDeclSyntax.self) {
            componentMacroForStruct(structDecl, type: type)
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            generateDeclaration(
                type: type,
                availability: enumDecl.attributes.availability,
                functions: []
            )
        } else {
            throw MacroError.macroUsage("Component macro can be applied only for structs or enums.")
        }
    }
}

private extension ComponentMacro {
    private static func componentMacroForStruct<T: TypeSyntaxProtocol>(
        _ structDecl: StructDeclSyntax,
        type: T
    ) -> [SwiftSyntax.ExtensionDeclSyntax] {
        let properties = structDecl.memberBlock.members.compactMap { member -> (String, TypeSyntax, String)? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { return nil }
            guard let binding = varDecl.bindings.first else { return nil }
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { return nil }
            guard let type = binding.typeAnnotation?.type else { return nil }
            if varDecl.bindingSpecifier.tokenKind == .keyword(.let) { return nil }
            
            // Ignore computed properties that only have a getter
            if let accessors = binding.accessorBlock?.accessors {
                switch accessors {
                case .getter:
                    return nil
                default:
                    break
                }
            }
            
            let accessModifier = varDecl.modifiers.first?.name.text ?? "internal"
            return (identifier, type, accessModifier)
        }
        
        let functions = properties.map { propertyName, propertyType, accessModifier in
        """
        \(accessModifier) func set\(propertyName.capitalizingFirstLetter())(_ value: \(propertyType)) -> Self {
            var newValue = self
            newValue.\(propertyName) = value
            return newValue
        }
        """
        }
        
        return generateDeclaration(
            type: type,
            availability: structDecl.attributes.availability,
            functions: functions
        )
    }
    
    private static func generateDeclaration<T: TypeSyntaxProtocol>(
        type: T,
        availability: AttributeListSyntax?,
        functions: [String]
    ) -> [SwiftSyntax.ExtensionDeclSyntax] {
        let proto = "AdaECS.Component"
        let ext: DeclSyntax =
        """
        \(availability)extension \(type.trimmed): \(raw: proto) { \n\(raw: functions.joined(separator: "\n")) \n}
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

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
}
