//
//  ReadOnlyKeyMacro.swift
//  MacrosImplementation
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
//

import SwiftSyntax
import SwiftSyntaxMacros

/// Marks a property as read-only in storage protocols
/// Properties marked with @ReadOnlyKey will:
/// - Not generate setters
/// - Not support setValue(_:for:) mutations
/// - Be computed from other sources or external storage
public struct ReadOnlyKeyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This macro doesn't generate any peer declarations
        // It's used as a marker attribute that StorageMacro checks for
        return []
    }
}

