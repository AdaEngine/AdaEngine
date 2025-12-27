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

        // Get dependencies from macro arguments
        var dependencies: [String] = []
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments where argument.label?.text == "required" {
                if let arrayExpr = argument.expression.as(ArrayExprSyntax.self) {
                    for element in arrayExpr.elements {
                        if let typeName = extractTypeName(from: element.expression) {
                            dependencies.append(typeName)
                        }
                    }
                }
            }
        }

        return if let structDecl = declaration.as(StructDeclSyntax.self) {
            componentMacroForStruct(structDecl, type: type, requiredComponents: dependencies)
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            generateDeclaration(
                type: type,
                availability: enumDecl.modifiers,
                functions: [],
                requiredComponents: dependencies
            )
        } else {
            throw MacroError.macroUsage("Component macro can be applied only for structs or enums.")
        }
    }
}

private extension ComponentMacro {
    /// Extracts type name from expression like Transform.self or AdaTransform.Transform.self
    private static func extractTypeName(from expression: ExprSyntax) -> String? {
        // Handle cases like Transform.self or AdaTransform.Transform.self
        if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
            // Check if it's a .self access
            if memberAccess.declName.baseName.text == "self" {
                // Recursively build the full type name
                var typeParts: [String] = []
                var current: ExprSyntax? = memberAccess.base
                
                while let expr = current {
                    if let declRef = expr.as(DeclReferenceExprSyntax.self) {
                        typeParts.insert(declRef.baseName.text, at: 0)
                        break
                    } else if let nestedMember = expr.as(MemberAccessExprSyntax.self) {
                        typeParts.insert(nestedMember.declName.baseName.text, at: 0)
                        current = nestedMember.base
                    } else {
                        break
                    }
                }
                
                if !typeParts.isEmpty {
                    let fullTypeName = typeParts.joined(separator: ".")
                    return "\(fullTypeName).self"
                }
            }
        }
        // Handle cases where it might be just a type reference (shouldn't happen, but handle it)
        else if let declRef = expression.as(DeclReferenceExprSyntax.self) {
            return "\(declRef.baseName.text).self"
        }
        
        return nil
    }
    private static func componentMacroForStruct<T: TypeSyntaxProtocol>(
        _ structDecl: StructDeclSyntax,
        type: T,
        requiredComponents: [String]
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
            availability: structDecl.modifiers,
            functions: functions,
            requiredComponents: requiredComponents
        )
    }
    
    private static func generateDeclaration<T: TypeSyntaxProtocol>(
        type: T,
        availability: DeclModifierListSyntax?,
        functions: [String],
        requiredComponents: [String] = []
    ) -> [SwiftSyntax.ExtensionDeclSyntax] {
        // Process modifiers: if private or fileprivate, change to internal
        let processedAvailability = processModifiers(availability)
        
        let proto = "AdaECS.Component"
        let ext: DeclSyntax =
        """
        extension \(type.trimmed): \(raw: proto) { 
            \(raw: functions.joined(separator: "\n"))
            \(processedAvailability) static var requiredComponents: RequiredComponents {
                RequiredComponents(components: [\(raw: requiredComponents.joined(separator: ", "))])
            }
        }
        """
        return [ext.cast(ExtensionDeclSyntax.self)]
    }
    
    private static func processModifiers(_ modifiers: DeclModifierListSyntax?) -> DeclModifierListSyntax? {
        guard let modifiers = modifiers, !modifiers.isEmpty else {
            return nil
        }
        
        // Check if we have private or fileprivate modifiers that need to be changed to internal
        var needsReplacement = false
        for modifier in modifiers {
            let name = modifier.name.text
            if name == "private" || name == "fileprivate" {
                needsReplacement = true
                break
            }
        }
        
        // If we found private or fileprivate, replace it with internal
        if needsReplacement {
            var newModifiers: [DeclModifierSyntax] = []
            for modifier in modifiers {
                let name = modifier.name.text
                if name == "private" || name == "fileprivate" {
                    // Replace with internal modifier using with method
                    let internalModifier = modifier.with(\.name, .keyword(.internal))
                    newModifiers.append(internalModifier)
                } else {
                    newModifiers.append(modifier)
                }
            }
            return DeclModifierListSyntax(newModifiers)
        }
        
        // Otherwise return original modifiers
        return modifiers
    }
}

extension ComponentMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
      ) throws -> [DeclSyntax] {
        return []
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
}
