//
//  KeyMacro.swift
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

/// Macro for generating getter/setter for KeyValueStoring-backed properties
///
/// This macro generates @objc dynamic accessors that use KeyValueStoring protocol methods.
/// Works with UserDefaults for KVO observation and any custom KeyValueStoring implementations.
///
/// ## Usage
/// ```swift
/// extension KeyValueStoring {
///     @Key("myKey", defaultValue: false)
///     var myProperty: Bool
///
///     @Key("optionalKey")
///     var optionalProperty: String?
/// }
/// ```
///
public struct KeyMacro {}

extension KeyMacro: AccessorMacro {
    
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            throw MacroError.message("@Key can only be applied to variable declarations")
        }
        
        guard let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
            throw MacroError.message("@Key requires a variable declaration")
        }
        
        guard let type = binding.typeAnnotation?.type else {
            throw MacroError.message("@Key requires an explicit type annotation")
        }
        
        let varName = identifier.text
        
        // Extract key, defaultValue, and other arguments from macro arguments
        var storageKey: String = varName
        var defaultValueExpr: ExprSyntax?
        var hasLegacyKey = false
        var allowDotsForLegacyKey = false
        
        if case .argumentList(let arguments) = node.arguments {
            for argument in arguments {
                if argument.label == nil, // Positional argument (key)
                   let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                   let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                    storageKey = segment.content.text
                } else if argument.label?.text == "defaultValue" {
                    defaultValueExpr = argument.expression
                } else if argument.label?.text == "migratingLegacyKey" {
                    hasLegacyKey = true
                } else if argument.label?.text == "allowDotsForLegacyKey" {
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self),
                       boolLiteral.literal.text == "true" {
                        allowDotsForLegacyKey = true
                    }
                }
            }
        }
        
        // Validate key doesn't contain dots (which break KVO observation)
        if storageKey.contains(".") && !allowDotsForLegacyKey {
            if hasLegacyKey {
                // If migratingLegacyKey is present, the dot is in the new key which is wrong
                throw MacroError.message("""
                    @Key error: The new key '\(storageKey)' contains a dot (.) which breaks KVO observation.
                    
                    The NEW key must not contain dots. Only the legacy key being migrated FROM can have dots.
                    
                    Fix: Use a key without dots for the new key:
                      @Key("newKeyWithoutDots", migratingLegacyKey: "\(storageKey)")
                    """)
            } else {
                // Suggest migration or explicit opt-in
                throw MacroError.message("""
                    @Key error: The key '\(storageKey)' contains a dot (.) which breaks KVO observation.
                    
                    Keys with dots cannot be observed by ObservableKeyValueStoring protocols.
                    
                    Choose one of these solutions:
                    
                    1. Migrate to a new key without dots (recommended):
                       @Key("newKeyWithoutDots", migratingLegacyKey: "\(storageKey)")
                    
                    2. If this key will NOT be observed (not used with ObservableKeyValueStoring):
                       @Key("\(storageKey)", allowDotsForLegacyKey: true)
                    """)
            }
        }
        
        // Check if type is optional
        let isOptional = type.is(OptionalTypeSyntax.self)
        let typeString = type.trimmedDescription
        let baseType = typeString.replacingOccurrences(of: "?", with: "")
        
        // Skip accessor generation for ThrowingValue types - they're handled by @Storage extension macro
        if typeString.hasPrefix("ThrowingValue<") {
            return []
        }
        
        // Generate getter and setter based on type
        let getterBody = generateGetter(key: storageKey, type: typeString, baseType: baseType, isOptional: isOptional, defaultValue: defaultValueExpr)
        let setterBody = generateSetter(key: storageKey, type: typeString, baseType: baseType, isOptional: isOptional)
        
        return [
            """
            get {
                \(raw: getterBody)
            }
            """,
            """
            set {
                \(raw: setterBody)
            }
            """
        ]
    }
    
    private static func generateGetter(key: String, type: String, baseType: String, isOptional: Bool, defaultValue: ExprSyntax?) -> String {
        let keyLiteral = "\"\(key)\""
        
        if isOptional {
            // For optional types, use object(forKey:) with casting
            return "object(forKey: \(keyLiteral)) as? \(baseType)"
        } else {
            // For non-optional types, require default value
            guard let defaultValue = defaultValue else {
                return "((object(forKey: \(keyLiteral))) as? \(type)) ?? /* default value required */"
            }
            
            let defaultExpr = defaultValue.trimmedDescription
            return "((object(forKey: \(keyLiteral))) as? \(type)) ?? \(defaultExpr)"
        }
    }
    
    private static func generateSetter(key: String, type: String, baseType: String, isOptional: Bool) -> String {
        let keyLiteral = "\"\(key)\""
        
        if isOptional {
            return """
            if let value = newValue {
                            set(value, forKey: \(keyLiteral))
                        } else {
                            removeObject(forKey: \(keyLiteral))
                        }
            """
        } else {
            return """
            set(newValue, forKey: \(keyLiteral))
            """
        }
    }
    
}
