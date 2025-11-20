//
//  StorageMacro.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro for generating KeyValueStoring implementations for protocol conformances
///
/// This macro adds protocol conformance and generates @objc dynamic property implementations.
///
/// ## Type Handling Strategy:
/// - **Explicitly rejected during macro expansion**: Tuples and closures (produce macro diagnostic errors)
/// - **Treated as basic types**: Bool, Int, Double, Float, String, Data, Date, URL, Array, Dictionary
/// - **All other types**: Generated as potentially RawRepresentable, will fail at Swift compile-time if they:
///   - Don't conform to RawRepresentable
///   - Have a RawValue that isn't storable in UserDefaults
///   - Can't be serialized by KeyValueStoring implementation
///
/// This permissive approach lets Swift's type system provide better error messages than macro diagnostics.
///
public struct StorageMacro {}

// MARK: - Helper Functions

/// Builds a fully qualified name for a protocol, including parent types for nested protocols
///
/// Walks up the syntax tree to find all parent types (struct, class, enum, actor, extension)
/// and builds the fully qualified name (e.g., "AppConfig.Settings").
///
/// The ExtensionMacro also receives this qualified name via the `type` parameter.
private func buildQualifiedName(for protocolDecl: ProtocolDeclSyntax, in context: some MacroExpansionContext) -> String {
    var names: [String] = [protocolDecl.name.text]
    
    // Walk up the entire parent chain
    var currentNode: Syntax? = Syntax(protocolDecl).parent
    var visitedTypes: Set<String> = []
    
    while let node = currentNode {
        defer { currentNode = node.parent }
        
        // Extract type names from various parent nodes
        if let structDecl = node.as(StructDeclSyntax.self), !visitedTypes.contains(structDecl.name.text) {
            visitedTypes.insert(structDecl.name.text)
            names.insert(structDecl.name.text, at: 0)
            #if DEBUG
            print("buildQualifiedName - Found struct: \(structDecl.name.text)")
            #endif
        } else if let classDecl = node.as(ClassDeclSyntax.self), !visitedTypes.contains(classDecl.name.text) {
            visitedTypes.insert(classDecl.name.text)
            names.insert(classDecl.name.text, at: 0)
        } else if let enumDecl = node.as(EnumDeclSyntax.self), !visitedTypes.contains(enumDecl.name.text) {
            visitedTypes.insert(enumDecl.name.text)
            names.insert(enumDecl.name.text, at: 0)
        } else if let actorDecl = node.as(ActorDeclSyntax.self), !visitedTypes.contains(actorDecl.name.text) {
            visitedTypes.insert(actorDecl.name.text)
            names.insert(actorDecl.name.text, at: 0)
        } else if let extensionDecl = node.as(ExtensionDeclSyntax.self) {
            // For extensions, get the extended type name
            let extendedTypeName: String
            if let identType = extensionDecl.extendedType.as(IdentifierTypeSyntax.self) {
                extendedTypeName = identType.name.text
            } else if let memberType = extensionDecl.extendedType.as(MemberTypeSyntax.self) {
                extendedTypeName = memberType.trimmedDescription
            } else {
                continue
            }
            
            if !visitedTypes.contains(extendedTypeName) {
                visitedTypes.insert(extendedTypeName)
                names.insert(extendedTypeName, at: 0)
            }
        }
    }
    
    return names.joined(separator: ".")
}

extension StorageMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            return []
        }
        
        // Build fully qualified name for nested protocols
        let protocolName = buildQualifiedName(for: protocolDecl, in: context)
        let helperEnumName = protocolName + "KeyPathMapping"
        
        var keyPathMappings: [(propertyName: String, storageKey: String, typeString: String)] = []
        
        // Read property declarations from the protocol
        for member in protocolDecl.memberBlock.members {
            // Skip if marked with @StorageIgnored
            if let decl = member.decl.asProtocol(WithAttributesSyntax.self),
               decl.attributes.contains(where: { attr in
                   guard let attr = attr.as(AttributeSyntax.self),
                         let identType = attr.attributeName.as(IdentifierTypeSyntax.self) else {
                       return false
                   }
                   return identType.name.text == "StorageIgnored"
               }) {
                continue
            }
            
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation else {
                continue
            }
            
            let propertyName = identifier.identifier.text
            let typeString = typeAnnotation.type.trimmedDescription
            let (storageKey, _) = extractStorageKeys(from: varDecl, propertyName: propertyName)
            
            keyPathMappings.append((propertyName: propertyName, storageKey: storageKey, typeString: typeString))
        }
        
        // Generate static dictionary mapping keypaths to storage keys
        let dictEntries = keyPathMappings.map { mapping in
            "\\\(protocolName).\(mapping.propertyName): \"\(mapping.storageKey)\""
        }.joined(separator: ",\n        ")
        
        // Generate helper enum as peer declaration with qualified name
        let helperEnum: DeclSyntax =
        """
        private enum \(raw: helperEnumName) {
            static let keyPathToStorageKey: [AnyKeyPath: String] = [
                \(raw: dictEntries)
            ]
        }
        """
        
        return [helperEnum]
    }
}

extension StorageMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            throw MacroError.message("@Storage can only be applied to protocol declarations")
        }
        
        // Use the 'type' parameter which already contains the qualified name for nested types
        let protocolName = type.trimmedDescription
        let helperEnumName = protocolName + "KeyPathMapping"
        
        // Check which storage protocol is being used
        let inheritedTypes = protocolDecl.inheritanceClause?.inheritedTypes.map { $0.type.trimmedDescription } ?? []
        let isObservableKeyValueStoring = inheritedTypes.contains(where: { $0.contains("ObservableKeyValueStoring") && !$0.contains("ObservableThrowingKeyValueStoring") })
        let isObservableThrowingKeyValueStoring = inheritedTypes.contains(where: { $0.contains("ObservableThrowingKeyValueStoring") })
        let isThrowingKeyValueStoring = inheritedTypes.contains(where: { $0.contains("ThrowingKeyValueStoring") && !$0.contains("ObservableThrowingKeyValueStoring") })
        let isKeyValueStoring = inheritedTypes.contains(where: { $0.contains("KeyValueStoring") && !$0.contains("ObservableKeyValueStoring") && !$0.contains("ThrowingKeyValueStoring") })
        
        // Count how many storage protocols are inherited
        let storageProtocolCount = [isObservableKeyValueStoring, isObservableThrowingKeyValueStoring, isThrowingKeyValueStoring, isKeyValueStoring].filter { $0 }.count
        
        // Validate exactly one storage protocol is inherited
        guard storageProtocolCount > 0 else {
            throw MacroError.message("@Storage requires the protocol to inherit from exactly one of: KeyValueStoring, ThrowingKeyValueStoring, ObservableKeyValueStoring, or ObservableThrowingKeyValueStoring")
        }
        
        guard storageProtocolCount == 1 else {
            let inherited = inheritedTypes.filter { type in
                type.contains("KeyValueStoring") || type.contains("ThrowingKeyValueStoring") || 
                type.contains("ObservableKeyValueStoring") || type.contains("ObservableThrowingKeyValueStoring")
            }
            throw MacroError.message("@Storage protocol cannot inherit from multiple storage protocols. Found: \(inherited.joined(separator: ", ")). Choose exactly one.")
        }
        
        // Extract access level from protocol declaration
        let accessLevel = protocolDecl.modifiers.first(where: { modifier in
            ["public", "internal", "private", "fileprivate", "open"].contains(modifier.name.text)
        })?.name.text ?? "internal"
        
        // Generate access modifier string (empty for internal)
        let accessModifier = accessLevel == "internal" ? "" : "\(accessLevel) "
        
        var generatedProperties: [DeclSyntax] = []
        var observableProperties: [DeclSyntax] = []
        var allStorageKeys: [String] = []

        // Read property declarations from the protocol
        for member in protocolDecl.memberBlock.members {
            // Skip if marked with @StorageIgnored
            if let decl = member.decl.asProtocol(WithAttributesSyntax.self),
               decl.attributes.contains(where: { attr in
                   guard let attr = attr.as(AttributeSyntax.self),
                         let identType = attr.attributeName.as(IdentifierTypeSyntax.self) else {
                       return false
                   }
                   return identType.name.text == "StorageIgnored"
               }) {
                continue
            }
            
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation else {
                continue
            }
            
            let propertyName = identifier.identifier.text
            let typeString = typeAnnotation.type.trimmedDescription
            let baseType = typeString.replacingOccurrences(of: "?", with: "")
            let isOptional = typeAnnotation.type.is(OptionalTypeSyntax.self)
            
            // Check if this is a ThrowingValue<T> or ThrowingGetter<T> type
            let isThrowingValue = typeString.hasPrefix("ThrowingValue<")
            let isThrowingGetter = typeString.hasPrefix("ThrowingGetter<")
            let isThrowingType = isThrowingValue || isThrowingGetter
            
            // Validate that Throwing protocols require ThrowingValue/ThrowingGetter types
            if (isThrowingKeyValueStoring || isObservableThrowingKeyValueStoring) && !isThrowingType {
                throw MacroError.message("@Storage with ThrowingKeyValueStoring requires properties to use ThrowingValue<T> or ThrowingGetter<T>. Property '\(propertyName)' has type '\(typeString)'. Use 'var \(propertyName): ThrowingValue<\(baseType)> { get }' for read-write or 'var \(propertyName): ThrowingGetter<\(baseType)> { get }' for read-only.")
            }
            
            // Validate that ThrowingValue/ThrowingGetter can only be used with Throwing protocols
            if isThrowingType && !isThrowingKeyValueStoring && !isObservableThrowingKeyValueStoring {
                throw MacroError.message("@Storage property '\(propertyName)' uses \(isThrowingValue ? "ThrowingValue<T>" : "ThrowingGetter<T>") but the protocol '\(protocolName)' does not conform to ThrowingKeyValueStoring or ObservableThrowingKeyValueStoring. Either change the property to a regular optional type or make the protocol conform to a throwing protocol.")
            }
            
            // Validate that non-throwing properties must be optional (ThrowingValue/ThrowingGetter are always non-optional by design)
            if !isThrowingType && !isOptional {
                throw MacroError.message("@Storage property '\(propertyName)' must be optional. Change '\(typeString)' to '\(typeString)?'. Only ThrowingValue<T> and ThrowingGetter<T> properties can be non-optional.")
            }
            
            // Validate ThrowingValue/ThrowingGetter properties are read-only
            if isThrowingType {
                if let accessorBlock = binding.accessorBlock {
                    let accessorText = accessorBlock.trimmedDescription
                    // Check if it has 'set' accessor
                    if accessorText.contains("set") {
                        throw MacroError.message("@Storage with \(isThrowingValue ? "ThrowingValue" : "ThrowingGetter") requires read-only properties. Property '\(propertyName)' must be declared as '{ get }', not '{ get set }'.")
                    }
                }
            }
            
            // Only support optional types (unless it's ThrowingValue/ThrowingGetter which handle optionality differently)
            guard isOptional || isThrowingType else {
                throw MacroError.message("@Storage only supports optional property types. Property '\(propertyName)' with type '\(typeString)' must be optional (e.g., '\(typeString)?'). Non-optional types would require implicit default values which hide missing data.")
            }
            
            // Check if type is a known basic type or potentially RawRepresentable
            let isBasicType = isSupportedType(baseType)
            
            // Reject types that are clearly not supported (tuples, closures, etc.)
            if baseType.contains("(") && baseType.contains("->") {
                throw MacroError.message("@Storage does not support closure type '\(baseType)' for property '\(propertyName)'. Use @StorageIgnored to exclude this property.")
            }
            if baseType.hasPrefix("(") && baseType.hasSuffix(")") && baseType.contains(",") {
                throw MacroError.message("@Storage does not support tuple type '\(baseType)' for property '\(propertyName)'. Use @StorageIgnored to exclude this property.")
            }
            
            // Check for @Key attribute to get custom key and legacy key
            let (storageKey, legacyKey) = extractStorageKeys(from: varDecl, propertyName: propertyName)
            
            // Track all storage keys for observation setup
            allStorageKeys.append(storageKey)
            
            // For pure ThrowingKeyValueStoring, require ThrowingValue<T> or ThrowingGetter<T>
            if isThrowingKeyValueStoring && !isKeyValueStoring && !isObservableKeyValueStoring && !isObservableThrowingKeyValueStoring {
                guard isThrowingType else {
                    throw MacroError.message("@Storage with ThrowingKeyValueStoring requires properties to use ThrowingValue<T> or ThrowingGetter<T>. Property '\(propertyName)' has type '\(typeString)'. Use 'var \(propertyName): ThrowingValue<\(typeString)> { get }' for read-write or 'var \(propertyName): ThrowingGetter<\(typeString)> { get }' for read-only.")
                }
            }
            
            // Generate property implementation
            let property: DeclSyntax
            
            if isThrowingType {
                // Extract inner type from ThrowingValue<T> or ThrowingGetter<T>
                let prefix = isThrowingValue ? "ThrowingValue<" : "ThrowingGetter<"
                let innerType = String(typeString.dropFirst(prefix.count).dropLast(1))
                let innerIsOptional = innerType.hasSuffix("?")
                
                // ThrowingValue/ThrowingGetter inner type must be non-optional
                guard !innerIsOptional else {
                    throw MacroError.message("@Storage with \(isThrowingValue ? "ThrowingValue" : "ThrowingGetter") requires the inner type to be non-optional. Property '\(propertyName)' has type '\(typeString)' but should be '\(prefix)\(innerType.replacingOccurrences(of: "?", with: ""))>'.")
                }
                
                let innerBaseType = innerType  // Already non-optional
                let innerIsBasicType = isSupportedType(innerBaseType)
                
                // Generate ThrowingValue/ThrowingGetter property (read-only)
                // The getter/setter operate on T? (optional) even though ThrowingValue<T> is non-optional
                property = generateThrowingValueProperty(
                    accessModifier: accessModifier,
                    propertyName: propertyName,
                    outerType: typeString,
                    innerType: innerType,
                    innerBaseType: innerBaseType,
                    innerIsBasicType: innerIsBasicType,
                    storageKey: storageKey,
                    legacyKey: legacyKey,
                    isReadOnly: isThrowingGetter
                )
            } else {
                // Regular property for KeyValueStoring/ObservableKeyValueStoring
                let getterBody = generateGetter(key: storageKey, legacyKey: legacyKey, type: typeString, baseType: baseType, isOptional: isOptional, isBasicType: isBasicType, setupObservation: isObservableKeyValueStoring, isThrowing: isThrowingKeyValueStoring)
                
                let useTryInternally = isObservableThrowingKeyValueStoring && !isKeyValueStoring
                let getterBodyNonThrowing = useTryInternally ? 
                    generateGetter(key: storageKey, legacyKey: legacyKey, type: typeString, baseType: baseType, isOptional: isOptional, isBasicType: isBasicType, setupObservation: isObservableThrowingKeyValueStoring, isThrowing: false).replacingOccurrences(of: "self.object", with: "try? self.object").replacingOccurrences(of: "self.removeObject", with: "try? self.removeObject") :
                    getterBody
                let setterBody = generateSetter(key: storageKey, legacyKey: legacyKey, type: typeString, baseType: baseType, isOptional: isOptional, isBasicType: isBasicType, isThrowing: useTryInternally)
                property =
                """
                \(raw: accessModifier)var \(raw: propertyName): \(raw: typeString) {
                    get {
                        \(raw: getterBodyNonThrowing)
                    }
                    set {
                        \(raw: setterBody)
                    }
                }
                """
            }
            
            generatedProperties.append(property)
            
            // Generate publisher property using string-based KVO (only for observable protocols, skip for ThrowingValue/ThrowingGetter types)
            if (isObservableKeyValueStoring || isObservableThrowingKeyValueStoring) && !isThrowingType {
                let publisher: DeclSyntax =
                """
                \(raw: accessModifier)var $\(raw: propertyName): AnyPublisher<\(raw: typeString), Never> {
                    publisher(for: \\\(raw: protocolName).\(raw: propertyName), key: "\(raw: storageKey)")
                }
                """
                
                observableProperties.append(publisher)
            }
        }
        
        // Add helper functions for KeyPath-based observation (only for observable protocols)
        if isObservableKeyValueStoring {
            // For ObservableKeyValueStoring: KeyPath<Protocol, Value?>
            let publicHelperFunction: DeclSyntax =
            """
            \(raw: accessModifier)func publisher<Value>(for keyPath: KeyPath<\(raw: protocolName), Value?>) -> AnyPublisher<Value?, Never> {
                guard let key = \(raw: helperEnumName).keyPathToStorageKey[keyPath] else {
                    fatalError("Unknown keyPath: \\(keyPath)")
                }
                return publisher(for: keyPath, key: key)
            }
            """
            observableProperties.append(publicHelperFunction)

            let helperFunction: DeclSyntax =
            """
            private func publisher<Value>(for keyPath: KeyPath<\(raw: protocolName), Value?>, key: String) -> AnyPublisher<Value?, Never> {
                self.updatesPublisher(forKey: key)
                    .prepend( () )
                    .map {
                        self[keyPath: keyPath]
                    }
                    .eraseToAnyPublisher()
            }
            """
            observableProperties.append(helperFunction)
        } else if isObservableThrowingKeyValueStoring {
            // For ObservableThrowingKeyValueStoring: KeyPath<Protocol, ThrowingValue<Value>>
            let publicHelperFunction: DeclSyntax =
            """
            \(raw: accessModifier)func publisher<Value>(for keyPath: KeyPath<\(raw: protocolName), ThrowingValue<Value>>) -> AnyPublisher<Value?, Never> {
                guard let key = \(raw: helperEnumName).keyPathToStorageKey[keyPath] else {
                    fatalError("Unknown keyPath: \\(keyPath)")
                }
                return publisher(for: keyPath, key: key)
            }
            """
            observableProperties.append(publicHelperFunction)

            let helperFunction: DeclSyntax =
            """
            private func publisher<Value>(for keyPath: KeyPath<\(raw: protocolName), ThrowingValue<Value>>, key: String) -> AnyPublisher<Value?, Never> {
                self.updatesPublisher(forKey: key)
                    .prepend( () )
                    .map { [weak self] in
                        try? self?[keyPath: keyPath].get()
                    }
                    .eraseToAnyPublisher()
            }
            """
            observableProperties.append(helperFunction)
        }
        
        // Generate automatic observation setup for UserDefaults conformances (only for ObservableKeyValueStoring and ObservableThrowingKeyValueStoring)
        if !allStorageKeys.isEmpty && (isObservableKeyValueStoring || isObservableThrowingKeyValueStoring) {
            let keysArray = allStorageKeys.map { "\"\($0)\"" }.joined(separator: ", ")
            let sanitizedName = protocolName.replacingOccurrences(of: ".", with: "_")
            let selectorString = "_\(sanitizedName)_observationCancellable"
            
            let setupMethod: DeclSyntax =
            """
            private var _\(raw: sanitizedName)_observationCancellable: AnyCancellable? {
                get {
                    guard let userDefaults = self as? UserDefaults else { return nil }
                    let key = unsafeBitCast(Selector(("\(raw: selectorString)")), to: UnsafeRawPointer.self)
                    return objc_getAssociatedObject(userDefaults, key) as? AnyCancellable
                }
                set {
                    guard let userDefaults = self as? UserDefaults else { return }
                    let key = unsafeBitCast(Selector(("\(raw: selectorString)")), to: UnsafeRawPointer.self)
                    objc_setAssociatedObject(userDefaults, key, newValue, .OBJC_ASSOCIATION_RETAIN)
                }
            }
            
            private func _setupAutoObservationIfNeeded() {
                guard let userDefaults = self as? UserDefaults else { return }
                
                if _\(raw: sanitizedName)_observationCancellable != nil {
                    return
                }
                
                // Subscribe to all publishers for keys in this protocol
                let keys = [\(raw: keysArray)]
                let publishers = keys.map { userDefaults.updatesPublisher(forKey: $0) }
                
                let cancellable = Publishers.MergeMany(publishers)
                    .sink { [weak userDefaults] _ in
                        userDefaults?.objectWillChange.send()
                    }
                
                _\(raw: sanitizedName)_observationCancellable = cancellable
            }
            """
            observableProperties.append(setupMethod)
        }

        // Create extension without where clause (protocol should inherit from KeyValueStoring)
        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(raw: protocolName)
            """
        ) {
            for property in generatedProperties {
                property
            }
        }
        
        // Only generate observable extension if there are observable properties
        var extensions = [extensionDecl]
        
        if !observableProperties.isEmpty {
            // Generate extension for both ObservableKeyValueStoring and ObservableThrowingKeyValueStoring
            let observableWhereClause = isObservableThrowingKeyValueStoring ? 
                "where Self: ObservableThrowingKeyValueStoring" :
                "where Self: ObservableKeyValueStoring"
            
            let extensionDecl2 = try ExtensionDeclSyntax(
                """
                extension \(raw: protocolName) \(raw: observableWhereClause)
                """
            ) {
                for property in observableProperties {
                    property
                }
            }
            extensions.append(extensionDecl2)
        }
        
        return extensions
    }
    
    private static func extractStorageKeys(from varDecl: VariableDeclSyntax, propertyName: String) -> (key: String, legacyKey: String?) {
        // Look for @Key attribute
        for attribute in varDecl.attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  let identType = attr.attributeName.as(IdentifierTypeSyntax.self),
                  identType.name.text == "Key" else {
                continue
            }
            
            // Extract the key and migratingLegacyKey arguments from @Key("key", migratingLegacyKey: "old.key")
            if case .argumentList(let arguments) = attr.arguments {
                var key: String?
                var legacyKey: String?
                
                for arg in arguments {
                    if arg.label == nil, // Positional argument (first = key)
                       let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        key = segment.content.text
                    } else if arg.label?.text == "migratingLegacyKey",
                              let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
                              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        legacyKey = segment.content.text
                    }
                }
                
                if let key = key {
                    return (key: key, legacyKey: legacyKey)
                }
            }
        }
        
        return (key: propertyName, legacyKey: nil)
    }
    
    private static func isSupportedType(_ typeString: String) -> Bool {
        // Basic types
        let basicTypes = ["Bool", "Int", "Double", "Float", "String", "Data", "Date", "URL"]
        if basicTypes.contains(typeString) {
            return true
        }
        
        // Array types: [Type] or Array<Type>
        if typeString.hasPrefix("[") && typeString.hasSuffix("]") {
            return true
        }
        if typeString.hasPrefix("Array<") && typeString.hasSuffix(">") {
            return true
        }
        
        // Dictionary types: [Key: Value] or Dictionary<Key, Value>
        if typeString.contains(":") && typeString.hasPrefix("[") && typeString.hasSuffix("]") {
            return true
        }
        if typeString.hasPrefix("Dictionary<") && typeString.hasSuffix(">") {
            return true
        }
        
        return false
    }
    
    private static func generateThrowingValueProperty(
        accessModifier: String,
        propertyName: String,
        outerType: String,
        innerType: String,
        innerBaseType: String,
        innerIsBasicType: Bool,
        storageKey: String,
        legacyKey: String?,
        isReadOnly: Bool = false
    ) -> DeclSyntax {
        let keyLiteral = "\"\(storageKey)\""
        
        // Generate getter closure (always returns T? - optional)
        let getterClosure: String
        if innerIsBasicType {
            if let legacyKey = legacyKey {
                // With legacy key migration
                let legacyKeyLiteral = "\"\(legacyKey)\""
                getterClosure = """
{
    if let value = try self.object(forKey: \(keyLiteral)) as? \(innerBaseType) {
        return value
    }
    // Migration: check legacy key
    if let legacyValue = try self.object(forKey: \(legacyKeyLiteral)) as? \(innerBaseType) {
        try self.set(legacyValue, forKey: \(keyLiteral))
        try self.removeObject(forKey: \(legacyKeyLiteral))
        return legacyValue
    }
    return nil
}
"""
            } else {
                // No legacy key
                getterClosure = """
{
    return try self.object(forKey: \(keyLiteral)) as? \(innerBaseType)
}
"""
            }
        } else {
            // Enum or other RawRepresentable type (always returns T? - optional)
            if let legacyKey = legacyKey {
                let legacyKeyLiteral = "\"\(legacyKey)\""
                getterClosure = """
{
    if let rawValue = try self.object(forKey: \(keyLiteral)), let value = (\(innerType))(rawValue: rawValue as! \(innerType).RawValue) {
        return value
    }
    // Migration
    if let legacyRawValue = try self.object(forKey: \(legacyKeyLiteral)), let legacyValue = (\(innerType))(rawValue: legacyRawValue as! \(innerType).RawValue) {
        if let rawValue = (legacyValue as? any RawRepresentable)?.rawValue {
            try self.set(rawValue, forKey: \(keyLiteral))
        }
        try self.removeObject(forKey: \(legacyKeyLiteral))
        return legacyValue
    }
    return nil
}
"""
            } else {
                getterClosure = """
{
    guard let rawValue = try self.object(forKey: \(keyLiteral)) else { return nil }
    return (\(innerType))(rawValue: rawValue as! \(innerType).RawValue)
}
"""
            }
        }
        
        // Generate setter closure (always takes T? - optional)
        let setterClosure: String
        if innerIsBasicType {
            setterClosure = """
{ newValue in
    if let newValue = newValue {
        try self.set(newValue, forKey: \(keyLiteral))
    } else {
        try self.removeObject(forKey: \(keyLiteral))
    }
}
"""
        } else {
            // Enum or RawRepresentable (always takes T? - optional)
            setterClosure = """
{ newValue in
    if let newValue = newValue {
        if let rawValue = (newValue as? any RawRepresentable)?.rawValue {
            try self.set(rawValue, forKey: \(keyLiteral))
        } else {
            try self.set(newValue, forKey: \(keyLiteral))
        }
    } else {
        try self.removeObject(forKey: \(keyLiteral))
    }
}
"""
        }
        
        if isReadOnly {
            // Generate ThrowingGetter (read-only, no setter)
            return """
            \(raw: accessModifier)var \(raw: propertyName): \(raw: outerType) {
                get {
                    ThrowingGetter(
                        getter: \(raw: getterClosure)
                    )
                }
            }
            """
        } else {
            // Generate ThrowingValue (read-write with getter and setter)
            return """
            \(raw: accessModifier)var \(raw: propertyName): \(raw: outerType) {
                get {
                    ThrowingValue(
                        getter: \(raw: getterClosure),
                        setter: \(raw: setterClosure)
                    )
                }
            }
            """
        }
    }
    
    private static func generateGetter(key: String, legacyKey: String?, type: String, baseType: String, isOptional: Bool, isBasicType: Bool, setupObservation: Bool = false, isThrowing: Bool = false) -> String {
        let observationSetup = setupObservation ? "_setupAutoObservationIfNeeded()\n                " : ""
        let keyLiteral = "\"\(key)\""
        // Use try for throwing getters (ThrowingKeyValueStoring), no try for non-throwing
        let tryKeyword = isThrowing ? "try " : ""
        
        // For basic types, use direct casting
        if isBasicType {
            guard let legacyKey = legacyKey else {
                return "\(observationSetup)return \(tryKeyword)self.object(forKey: \(keyLiteral)) as? \(baseType)"
            }
            
            let legacyKeyLiteral = "\"\(legacyKey)\""
            return """
\(observationSetup)if let value = \(tryKeyword)self.object(forKey: \(keyLiteral)) as? \(baseType) {
                    return value
                }
                // Migrate from legacy key if present
                if let legacyValue = \(tryKeyword)self.object(forKey: \(legacyKeyLiteral)) as? \(baseType) {
                    \(tryKeyword)self.set(legacyValue, forKey: \(keyLiteral))
                    \(tryKeyword)self.removeObject(forKey: \(legacyKeyLiteral))
                    return legacyValue
                }
                return nil
"""
        }
        
        // For RawRepresentable types, try to get raw value and convert
        guard let legacyKey = legacyKey else {
            return """
\(observationSetup)if let rawValue = \(tryKeyword)self.object(forKey: \(keyLiteral)) {
                    return (rawValue as? \(baseType)) ?? (rawValue as? \(baseType).RawValue).flatMap(\(baseType).init(rawValue:))
                }
                return nil
"""
        }
        
        let legacyKeyLiteral = "\"\(legacyKey)\""
        return """
\(observationSetup)if let rawValue = \(tryKeyword)self.object(forKey: \(keyLiteral)) {
                    if let value = rawValue as? \(baseType) {
                        return value
                    }
                    if let value = (rawValue as? \(baseType).RawValue).flatMap(\(baseType).init(rawValue:)) {
                        return value
                    }
                }
                // Migrate from legacy key if present
                if let legacyRawValue = \(tryKeyword)self.object(forKey: \(legacyKeyLiteral)) {
                    let legacyValue = (legacyRawValue as? \(baseType)) ?? (legacyRawValue as? \(baseType).RawValue).flatMap(\(baseType).init(rawValue:))
                    if let legacyValue = legacyValue {
                        // Store the raw value, not the enum itself
                        if let rawValue = (legacyValue as? any RawRepresentable)?.rawValue {
                            \(tryKeyword)self.set(rawValue, forKey: \(keyLiteral))
                        } else {
                            \(tryKeyword)self.set(legacyValue, forKey: \(keyLiteral))
                        }
                        \(tryKeyword)self.removeObject(forKey: \(legacyKeyLiteral))
                        return legacyValue
                    }
                }
                return nil
"""
    }
    
    private static func generateSetter(key: String, legacyKey: String?, type: String, baseType: String, isOptional: Bool, isBasicType: Bool, isThrowing: Bool, setupObservation: Bool = false) -> String {
        let keyLiteral = "\"\(key)\""
        // Use try? for throwing operations to handle errors silently (properties can't throw)
        let tryKeyword = isThrowing ? "try? " : ""
        
        // All non-ThrowingValue properties are optional, so we always unwrap
        var code: String
        
        if isBasicType {
            // For basic types, unwrap and set or remove
            code = """
if let newValue = newValue {
                    \(tryKeyword)self.set(newValue, forKey: \(keyLiteral))
                } else {
                    \(tryKeyword)self.removeObject(forKey: \(keyLiteral))
                }
"""
        } else {
            // For RawRepresentable types, extract raw value if possible
            code = """
if let newValue = newValue {
                    if let rawValue = (newValue as? any RawRepresentable)?.rawValue {
                        \(tryKeyword)self.set(rawValue, forKey: \(keyLiteral))
                    } else {
                        \(tryKeyword)self.set(newValue, forKey: \(keyLiteral))
                    }
                } else {
                    \(tryKeyword)self.removeObject(forKey: \(keyLiteral))
                }
"""
        }
        
        // If legacy key exists, also remove it during migration
        if let legacyKey = legacyKey {
            let legacyKeyLiteral = "\"\(legacyKey)\""
            code += "\n                \(tryKeyword)self.removeObject(forKey: \(legacyKeyLiteral))"
        }
        
        return code
    }
}

