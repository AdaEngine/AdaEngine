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

public struct SystemMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Find all properties with SystemQuery attribute
        let entityQueries = declaration.memberBlock.members.compactMap { member -> String? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { return nil }
            let hasEntityQueryAttribute = varDecl.attributes.contains { attribute in
                guard let attributeName = attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text else {
                    return false
                }
                return attributeName.hasSuffix("Query") || attributeName == "Extract"
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
            \(availability)var queries: AdaECS.SystemQueries {
                return AdaECS.SystemQueries(queries: [\(raw: entityQueries.joined(separator: ", "))])
            }
            """
            declarations.append(queriesProperty)
        }
        
        // Generate dependencies property if there are any dependencies
        if !dependencies.isEmpty {
            let dependenciesProperty: DeclSyntax = """
            \(availability)static var dependencies: [AdaECS.SystemDependency] {
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

extension SystemMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            // Only handle function declarations
            return []
        }
        
        let funcName = funcDecl.name.text
        let params = funcDecl.signature.parameterClause.parameters
        let availability = funcDecl.modifiers
        
        // Check if function is async or has actor attributes
        let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let hasActorAttribute = funcDecl.attributes.contains { attribute in
            guard let attributeName = attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text else {
                return false
            }
            return attributeName.hasSuffix("Actor") || attributeName == "MainActor"
        }
        
        let needsAwait = isAsync || hasActorAttribute

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
        
        // Generate property declarations and type list for queries
        var propertyDecls: [String] = []
        var queryVars: [String] = []
        var paramNames: [SystemInputParameter] = []

        for param in params {
            let isAnonymosParam = param.firstName.text == "_"
            let paramName = if isAnonymosParam {
                param.secondName!.text
            } else {
                param.firstName.text
            }

            let defaultValue = param.defaultValue?.value.description
            let typeString = param.type.trimmedDescription
            
            // Check for inout parameter
            let isInoutParam = typeString.hasPrefix("inout ")
            
            // Check for special types that shouldn't be added to propertyDecls
            var specialType: SystemInputParameter.SpecialType = .none
            if typeString.hasSuffix("WorldUpdateContext") || typeString.hasSuffix("UpdateContext") {
                specialType = .context
            }
            if typeString.hasSuffix("World") || typeString.hasSuffix(".World") {
                specialType = .world
            }

            if specialType == .none {
                propertyDecls.append("@\(typeString)\nprivate var \(paramName)\(defaultValue != nil ? " = \(defaultValue!)" : "")")
                queryVars.append("_\(paramName)")
            }
            paramNames.append(
                SystemInputParameter(
                    isAnonymosParam: isAnonymosParam, 
                    isInoutParam: isInoutParam, 
                    paramName: paramName,
                    specialType: specialType
                )
            )
        }
        
        // Generate struct body
        let structDecl: DeclSyntax = """
        \(availability)struct \(raw: funcName)System: AdaECS.System {
        \(raw: propertyDecls.joined(separator: "\n\n"))
        
        \(availability)init(world: AdaECS.World) { }
        
        \(availability)func update(context: inout UpdateContext)\(raw: needsAwait ? " async" : "") {
            \(raw: needsAwait ? "await " : "")\(raw: funcName)(\(raw: paramNames.map { $0.buildParameter() }.joined(separator: ", ")))
        }
        
        \(availability) var queries: AdaECS.SystemQueries {
            return AdaECS.SystemQueries(queries: [\(raw: queryVars.joined(separator: ", "))])
        }
        
        \(raw: dependencies.isEmpty ? "" : "\(availability)var dependencies: [AdaECS.SystemDependency] { [\(dependencies.joined(separator: ", "))] }")
        }
        """
        return [structDecl]
    }

    struct SystemInputParameter {
        enum SpecialType {
            case world
            case context
            case none
        }

        let isAnonymosParam: Bool
        let isInoutParam: Bool
        let paramName: String
        let specialType: SpecialType

        func buildParameter() -> String {
            let functionParam = if isAnonymosParam {
                ""
            } else {
                "\(paramName): "
            }
            let propertyParam = if isInoutParam {
                "&\(paramName)"
            } else {
                specialType == .world ? "context.\(paramName)" : "_\(paramName)"
            }

            return "\(functionParam)\(propertyParam)"
        }
    }
}
