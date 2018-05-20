//
//  Generator.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 3/2/18.
//

import Foundation
import Stencil
import PathKit
import Weaver

public final class Generator {

    private let templateDirPath: Path
    private let templateName: String
    
    private let graph = Graph()
    
    public init(asts: [Expr], template path: Path? = nil) throws {

        if let path = path {
            var components = path.components
            guard let templateName = components.popLast() else {
                throw GeneratorError.invalidTemplatePath(path: path.description)
            }
            self.templateName = templateName
            templateDirPath = Path(components: components)
        } else {
            templateName = "Resources/dependency_resolver.stencil"
            templateDirPath = Path("/usr/local/share/weaver")
        }
        
        buildResolvers(asts: asts)
        
        linkParameters()
    }
    
    public func generate() throws -> [(file: String, data: String?)] {

        return try graph.resolversByFile.map { file, resolvers in

            guard !resolvers.isEmpty else {
                return (file: file, data: nil)
            }
            
            let fileLoader = FileSystemLoader(paths: [templateDirPath])
            let environment = Environment(loader: fileLoader)
            let context = ["resolvers": resolvers]
            let string = try environment.renderTemplate(name: templateName, context: context)
            
            return (file: file, data: string.compacted())
        }
    }
}

// MAKR: - Graph

private final class Graph {

    private(set) var resolversByType = [String: ResolverData]()
    private(set) var typesByName = [String: [String]]()

    var resolversByFile = [String: [ResolverData]]()
    
    func insertResolver(_ resolver: ResolverData) {
        resolversByType[resolver.targetTypeName] = resolver
    }
    
    func insertVariable(_ variable: VariableData) {
        var types = typesByName[variable.name] ?? []
        types.append(variable.typeName)
        variable.abstractTypeName.flatMap { types.append($0) }
        typesByName[variable.name] = types
    }
}

// MARK: - Template Data

private final class RegisterData {
    let name: String
    let typeName: String
    let abstractTypeName: String
    let scope: String
    let isCustom: Bool
    var parameters: [VariableData] = []
    
    init(name: String,
         typeName: String,
         abstractTypeName: String,
         scope: String,
         isCustom: Bool) {
        self.name = name
        self.typeName = typeName
        self.abstractTypeName = abstractTypeName
        self.scope = scope
        self.isCustom = isCustom
    }
}

private final class VariableData {
    let name: String
    let typeName: String
    let abstractTypeName: String?

    var parameters: [VariableData] = []
    let resolvedTypeName: String
    
    init(name: String,
         typeName: String,
         abstractTypeName: String?) {
        self.name = name
        self.typeName = typeName
        self.abstractTypeName = abstractTypeName
        resolvedTypeName = abstractTypeName ?? typeName
    }
}

private final class ResolverData {
    let targetTypeName: String
    let registrations: [RegisterData]
    let references: [VariableData]
    let parameters: [VariableData]
    let enclosingTypeNames: [String]?
    let isRoot: Bool
    let isPublic: Bool
    let doesSupportObjc: Bool
    let isIsolated: Bool
    
    init(targetTypeName: String,
         registrations: [RegisterData],
         references: [VariableData],
         parameters: [VariableData],
         enclosingTypeNames: [String]?,
         isRoot: Bool,
         doesSupportObjc: Bool,
         accessLevel: AccessLevel,
         config: Set<ConfigurationAttribute>) {
        self.targetTypeName = targetTypeName
        self.registrations = registrations
        self.references = references
        self.parameters = parameters
        self.enclosingTypeNames = enclosingTypeNames
        self.isRoot = isRoot
        self.doesSupportObjc = doesSupportObjc
        
        switch accessLevel {
        case .`public`:
            isPublic = true
        case .`internal`:
            isPublic = false
        }
        
        isIsolated = config.isIsolated
    }
}

// MARK: - Conversion

extension RegisterData {
    
    convenience init(registerAnnotation: RegisterAnnotation,
                     scopeAnnotation: ScopeAnnotation?,
                     customRefAnnotation: CustomRefAnnotation?) {
       
        let optionChars = CharacterSet(charactersIn: "?")
        let scope = scopeAnnotation?.scope ?? .`default`

        self.init(name: registerAnnotation.name,
                  typeName: registerAnnotation.typeName.trimmingCharacters(in: optionChars),
                  abstractTypeName: registerAnnotation.protocolName ?? registerAnnotation.typeName,
                  scope: scope.stringValue,
                  isCustom: customRefAnnotation?.value ?? CustomRefAnnotation.defaultValue)
    }
    
    convenience init(referenceAnnotation: ReferenceAnnotation,
                     scopeAnnotation: ScopeAnnotation?,
                     customRefAnnotation: CustomRefAnnotation?) {
        
        let optionChars = CharacterSet(charactersIn: "?")
        let scope = scopeAnnotation?.scope ?? .`default`
        
        self.init(name: referenceAnnotation.name,
                  typeName: referenceAnnotation.typeName.trimmingCharacters(in: optionChars),
                  abstractTypeName: referenceAnnotation.typeName,
                  scope: scope.stringValue,
                  isCustom: customRefAnnotation?.value ?? CustomRefAnnotation.defaultValue)
    }
}

extension VariableData {
    
    convenience init(referenceAnnotation: ReferenceAnnotation) {
        
        self.init(name: referenceAnnotation.name,
                  typeName: referenceAnnotation.typeName,
                  abstractTypeName: nil)
    }
    
    convenience init(registerAnnotation: RegisterAnnotation) {
        
        self.init(name: registerAnnotation.name,
                  typeName: registerAnnotation.typeName,
                  abstractTypeName: registerAnnotation.protocolName)
    }
    
    convenience init(parameterAnnotation: ParameterAnnotation) {
        
        self.init(name: parameterAnnotation.name,
                  typeName: parameterAnnotation.typeName,
                  abstractTypeName: nil)
    }
}

// MARK: - Building

extension ResolverData {

    convenience init?(expr: Expr, enclosingTypeNames: [String], graph: Graph) {
        
        switch expr {
        case .typeDeclaration(let typeToken, let configTokens, children: let children):
            let targetTypeName = typeToken.value.name
            
            var scopeAnnotations = [String: ScopeAnnotation]()
            var registerAnnotations = [String: RegisterAnnotation]()
            var referenceAnnotations = [String: ReferenceAnnotation]()
            var customRefAnnotations = [String: CustomRefAnnotation]()
            var parameters = [VariableData]()
            
            for child in children {
                switch child {
                case .scopeAnnotation(let annotation):
                    scopeAnnotations[annotation.value.name] = annotation.value
                
                case .registerAnnotation(let annotation):
                    registerAnnotations[annotation.value.name] = annotation.value

                case .referenceAnnotation(let annotation):
                    referenceAnnotations[annotation.value.name] = annotation.value
                    
                case .customRefAnnotation(let annotation):
                    customRefAnnotations[annotation.value.name] = annotation.value
                    
                case .parameterAnnotation(let annotation):
                    parameters.append(VariableData(parameterAnnotation: annotation.value))
                    
                case .file,
                     .typeDeclaration:
                    break
                }
            }
            
            let registrations = registerAnnotations.map {
                RegisterData(registerAnnotation: $0.value,
                             scopeAnnotation: scopeAnnotations[$0.key],
                             customRefAnnotation: customRefAnnotations[$0.key])
            } + referenceAnnotations.compactMap {
                if let customRefAnnotation = customRefAnnotations[$0.key] {
                    return RegisterData(referenceAnnotation: $0.value,
                                        scopeAnnotation: scopeAnnotations[$0.key],
                                        customRefAnnotation: customRefAnnotation)
                } else {
                    return nil
                }
            }

            let references = registerAnnotations.map { _, register -> VariableData in
                let variable = VariableData(registerAnnotation: register)
                graph.insertVariable(variable)
                return variable
            } + referenceAnnotations.map { _, reference -> VariableData in
                let variable = VariableData(referenceAnnotation: reference)
                graph.insertVariable(variable)
                return variable
            }
            
            let isRoot = referenceAnnotations.filter {
                let isCustom = customRefAnnotations[$0.key]?.value ?? CustomRefAnnotation.defaultValue
                return !isCustom
            }.isEmpty

            self.init(targetTypeName: targetTypeName,
                      registrations: registrations,
                      references: references,
                      parameters: parameters,
                      enclosingTypeNames: enclosingTypeNames,
                      isRoot: isRoot,
                      doesSupportObjc: typeToken.value.doesSupportObjc,
                      accessLevel: typeToken.value.accessLevel,
                      config: Set(configTokens.map { $0.value.attribute }))
            
        case .file,
             .registerAnnotation,
             .scopeAnnotation,
             .referenceAnnotation,
             .customRefAnnotation,
             .parameterAnnotation:
            return nil
        }
    }
}

private extension Generator {
    
    func buildResolvers(asts: [Expr]) {
        for ast in asts {
            if let (file, resolvers) = buildResolvers(ast: ast) {
                graph.resolversByFile[file] = resolvers
            }
        }
    }
    
    private func buildResolvers(ast: Expr) -> (file: String, resolvers: [ResolverData])? {
        switch ast {
        case .file(let types, let name):
            let resolvers = buildResolvers(exprs: types)
            return (name, resolvers)
            
        case .typeDeclaration,
             .registerAnnotation,
             .scopeAnnotation,
             .referenceAnnotation,
             .customRefAnnotation,
             .parameterAnnotation:
            return nil
        }
    }
    
    private func buildResolvers(exprs: [Expr], enclosingTypeNames: [String] = []) -> [ResolverData] {

        return exprs.flatMap { expr -> [ResolverData] in
            switch expr {
            case .typeDeclaration(let typeToken, _, let children):
                guard let resolverData = ResolverData(expr: expr, enclosingTypeNames: enclosingTypeNames, graph: graph) else {
                    return []
                }
                graph.insertResolver(resolverData)
                let enclosingTypeNames = enclosingTypeNames + [typeToken.value.name]
                return [resolverData] + buildResolvers(exprs: children, enclosingTypeNames: enclosingTypeNames)
                
            case .file,
                 .registerAnnotation,
                 .referenceAnnotation,
                 .scopeAnnotation,
                 .customRefAnnotation,
                 .parameterAnnotation:
                return []
            }
        }
    }
}

// MARK: - Linking

private extension Generator {
    
    func linkParameters() {
        let resolvers = graph.resolversByFile.values.flatMap { $0 }
        let registrations = resolvers.flatMap { $0.registrations }
        let references = resolvers.flatMap { $0.references }

        // link parameters to registrations
        for registration in registrations {
            registration.parameters = graph.resolversByType[registration.typeName]?.parameters ?? []
        }

        // link parameters to references
        for reference in references {
            reference.parameters = graph.resolversByType[reference.typeName]?.parameters ?? []
            
            if reference.parameters.isEmpty, let types = graph.typesByName[reference.name] {
                for type in types {
                    if let parameters = graph.resolversByType[type]?.parameters {
                        reference.parameters = parameters
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Utils

private extension String {
    
    func compacted() -> String {
        return split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
    }
}
