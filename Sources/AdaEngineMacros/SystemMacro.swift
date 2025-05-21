//
//  SystemMacro.swift
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

// FIXME: We should avoid comparising `attributeName == "EntityQuery"` because user can have alias.
public struct SystemMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Find all properties with @EntityQuery attribute
        let entityQueries = declaration.memberBlock.members.compactMap { member -> String? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { return nil }
            
            // Check if property has @EntityQuery attribute
            let hasEntityQueryAttribute = varDecl.attributes.contains { attribute in
                guard let attributeName = attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text else {
                    return false
                }
                return attributeName == "EntityQuery" || attributeName == "AdaECS.EntityQuery"
            }
            
            guard hasEntityQueryAttribute,
                  let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                return nil
            }
            
            return "_\(identifier)"
        }
        
        let availability = declaration.modifiers
        
        // Get dependencies from macro arguments
        var dependencies: [String] = []
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments where argument.label?.text == "dependencies" {
                if let arrayExpr = argument.expression.as(ArrayExprSyntax.self) {
                    for element in arrayExpr.elements {
                        if let functionCall = element.expression.as(FunctionCallExprSyntax.self),
                           let memberAccess = functionCall.calledExpression.as(
                            MemberAccessExprSyntax.self),
                            let argument = functionCall.arguments.first
                        {
                            let dependencyType = memberAccess.declName.baseName.text
                            let systemType = argument.expression.trimmedDescription
                            dependencies.append(".\(dependencyType)(\(systemType))")
                        }
                    }
                }
            }
        }
        
        var declarations: [DeclSyntax] = []
        
        // Generate queries property if there are any EntityQuery properties
        if !entityQueries.isEmpty {
            let queriesProperty: DeclSyntax = """
            \(availability)var queries: SystemQueries {
                return SystemQueries(queries: [\(raw: entityQueries.joined(separator: ", "))])
            }
            """
            declarations.append(queriesProperty)
        }
        
        // Generate dependencies property if there are any dependencies
        if !dependencies.isEmpty {
            let dependenciesProperty: DeclSyntax = """
            \(availability)static var dependencies: [SystemDependency] {
                return [\(raw: dependencies.joined(separator: ", "))]
            }
            """
            declarations.append(dependenciesProperty)
        }
        
        return declarations
    }
}

extension SystemMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Check if the type already conforms to System
        if let inheritanceClause = declaration.as(StructDeclSyntax.self)?.inheritanceClause,
           inheritanceClause.inheritedTypes.contains(where: {
               ["System"].withQualified.contains($0.type.trimmedDescription)
           }) {
            return []
        }
        
        let proto = "AdaECS.System"
        let ext: DeclSyntax = """
        extension \(type.trimmed): \(raw: proto) { }
        """
        return [ext.cast(ExtensionDeclSyntax.self)]
    }
}
