//
//  NestedObservableMacro.swift
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

/// Macro for generating nested ObservableObject forwarding
///
/// This macro transforms a property into a computed property with backing storage
/// that automatically forwards the nested object's `objectWillChange` to the parent's.
///
public struct NestedObservableMacro {}

extension NestedObservableMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
              binding.typeAnnotation != nil else {
            throw MacroError.message("@NestedObservable can only be applied to variable declarations with explicit type annotations")
        }
        
        // Ensure this is not a computed property already
        if binding.accessorBlock != nil {
            throw MacroError.message("@NestedObservable cannot be applied to computed properties")
        }
        
        let propertyName = identifier.identifier.text
        let backingName = "_\(propertyName)"
        let cancellableName = "_\(propertyName)Cancellable"
        
        // Generate getter that lazily sets up subscription
        let getter: AccessorDeclSyntax =
        """
        get {
            if \(raw: cancellableName) == nil {
                \(raw: cancellableName) = \(raw: backingName).objectWillChange.sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
            }
            return \(raw: backingName)
        }
        """
        
        // Generate setter that cancels old subscription and sets up new one
        let setter: AccessorDeclSyntax =
        """
        set {
            \(raw: cancellableName)?.cancel()
            \(raw: backingName) = newValue
            \(raw: cancellableName) = \(raw: backingName).objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            objectWillChange.send()
        }
        """
        
        return [getter, setter]
    }
}

extension NestedObservableMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation else {
            return []
        }
        
        let propertyName = identifier.identifier.text
        let typeString = typeAnnotation.type.trimmedDescription
        let backingName = "_\(propertyName)"
        let cancellableName = "_\(propertyName)Cancellable"
        
        // Get initial value if present
        let initialValue: String
        if let initValue = binding.initializer?.value {
            initialValue = " = \(initValue.trimmedDescription)"
        } else {
            initialValue = ""
        }
        
        // Generate backing storage
        let backingStorage: DeclSyntax =
        """
        private var \(raw: backingName): \(raw: typeString)\(raw: initialValue)
        """
        
        // Generate cancellable storage
        let cancellableStorage: DeclSyntax =
        """
        private var \(raw: cancellableName): AnyCancellable?
        """
        
        return [backingStorage, cancellableStorage]
    }
}

