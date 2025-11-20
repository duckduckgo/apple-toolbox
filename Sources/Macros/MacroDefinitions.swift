//
//  MacroDefinitions.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Foundation

// MARK: - Storage Macros

/// Generates type-safe KeyValueStoring protocol implementations with automatic key-value storage
///
/// Attach `@Storage` to a protocol conforming to `KeyValueStoring` (or its variants) to generate:
/// - Property getters/setters backed by the key-value store
/// - Publisher properties (`$propertyName`) for observable protocols
/// - Automatic `objectWillChange` notifications for `ObservableKeyValueStoring`
///
/// ## Quick Start
///
/// ```swift
/// import Macros
/// import Persistence
///
/// @Storage
/// protocol AppSettings: ObservableKeyValueStoring {
///     var isFirstLaunch: Bool? { get set }  // By default, key is "isFirstLaunch"
///     var username: String? { get set }     // By default, key is "username"
/// }
///
/// // Conform any KeyValueStoring implementation
/// extension UserDefaults: AppSettings {}
/// extension InMemoryKeyValueStore: AppSettings {}
///
/// // Use with type safety and observation
/// let settings: AppSettings = UserDefaults.standard
/// settings.isFirstLaunch = false
/// settings.$username.sink { print($0 ?? "none") }
/// ```
///
/// ## Supported Protocols
///
/// - `KeyValueStoring` - Basic storage
/// - `ThrowingKeyValueStoring` - Throwing storage operations (use `ThrowingValue<T>` properties)
/// - `ObservableKeyValueStoring` - With publishers and `objectWillChange`
/// - `ObservableThrowingKeyValueStoring` - Combining both capabilities
///
/// ## Property Types
///
/// **Standard properties (all protocols except throwing):**
/// - Must be **optional** (`String?`, `Int?`, `Bool?`)
/// - Basic types: `Bool`, `Int`, `Double`, `Float`, `String`, `Data`, `Date`, `URL`
/// - Collections: `Array`, `Dictionary`
/// - Enums with `RawRepresentable` (String or Int raw values)
///
/// **Throwing properties (ThrowingKeyValueStoring protocols only):**
/// - Read-write: Use `ThrowingValue<T>` (e.g., `var value: ThrowingValue<Int> { get }`)
///   - `.get()` returns `T?` (optional) and throws errors
///   - `.set(_:)` accepts `T?` (optional) and throws errors
/// - Read-only: Use `ThrowingGetter<T>` (e.g., `var readOnly: ThrowingGetter<Int> { get }`)
///   - `.get()` returns `T?` (optional) and throws errors
///   - No `.set()` method available (automatically read-only)
///
/// ## Custom Keys
///
/// **By default, properties use their variable name as the storage key.**
///
/// Use `@Key` to override the default key:
/// ```swift
/// var username: String? { get set }  // Uses "username" as key (default)
///
/// @Key("custom_key")  // Override: uses "custom_key" instead of property name
/// var property: String? { get set }
///
/// @Key("newKey", migratingLegacyKey: "old.key.with.dots")  // Migrate from dotted key
/// var migrated: String? { get set }
///
/// @Key("legacy.key", allowDotsForLegacyKey: true)  // Keep dotted key (⚠️ discouraged, see notes)
/// var legacy: String? { get set }
/// ```
///
/// ## Excluding Properties
///
/// Use `@StorageIgnored` on **properties** you want to exclude from code generation:
/// ```swift
/// @StorageIgnored
/// var customProperty: String? { get }  // Custom implementation required
/// ```
///
/// **Note:** Functions and associated types are automatically ignored - no annotation needed.
///
/// ## Observation Behavior
///
/// **Property publishers (`$propertyName` and `publisher(for: \.keyPath)`):**
/// - ✅ Emit the **current value immediately** on subscription
/// - ✅ Then emit on every subsequent change
/// - ✅ Work with **all** ObservableKeyValueStoring implementations
/// ```swift
/// settings.$username.sink { value in
///     print(value)  // Prints: current value (or nil), then new values on changes
/// }
/// ```
///
/// **objectWillChange publisher (for SwiftUI integration):**
/// - 🎯 **Primary use case:** SwiftUI view updates when @Storage properties change
/// - ✅ **Works automatically** with all `ObservableKeyValueStoring` / `ObservableThrowingKeyValueStoring` implementations
/// - ❌ Does **NOT** emit on subscription
/// - ✅ Only emits on property change
/// ```swift
/// // UserDefaults
/// let defaults: AppSettings = UserDefaults.standard
/// defaults.objectWillChange.sink {
///     print("About to change")  // Only prints on change, not on subscription
/// }
/// 
/// // Custom implementations (e.g., InMemoryKeyValueStore)
/// let mockStore: AppSettings = InMemoryKeyValueStore()
/// mockStore.objectWillChange.sink { ... }  // ✅ Works automatically
/// ```
///
/// **Implementation Details:**
/// - **UserDefaults:** Uses KVO observation (set up lazily on first property access)
/// - **Custom implementations:** Work automatically if they conform to `ObservableKeyValueStoring`
///   (e.g., `InMemoryKeyValueStore` emits changes in its storage methods)
///
/// **For nested observables in ViewModels:** See `@NestedObservable` below for properly forwarding
/// objectWillChange from nested ObservableObjects to parent ViewModels.
///
/// ## ⚠️ Common Pitfalls
///
/// 1. **Property declaration requirements differ by protocol type**
///    ```swift
///    // Regular protocols - properties must be optional
///    var count: Int { get set }   // ❌ Compile error
///    var count: Int? { get set }  // ✅ Correct
///    
///    // Throwing protocols - ThrowingValue must be non-optional
///    var value: ThrowingValue<Int>? { get }  // ❌ Wrong
///    var value: ThrowingValue<Int> { get }   // ✅ Correct (returns Int? when calling .get())
///    ```
///
/// 2. **Dotted keys discouraged for observable protocols**
///    ```swift
///    @Key("com.app.key")  // ❌ Breaks KVO, falls back to slower NotificationCenter
///    @Key("appKey")  // ✅ Use simple keys for optimal KVO performance
///    @Key("appKey", migratingLegacyKey: "com.app.key")  // ✅ Migrate from dotted key
///    @Key("com.app.key", allowDotsForLegacyKey: true)  // ⚠️ Works but slower (NotificationCenter)
///    ```
///
/// 3. **ThrowingValue/ThrowingGetter only for throwing protocols**
///    ```swift
///    import Macros
///    import Persistence
///    
///    @Storage
///    protocol Settings: KeyValueStoring {  // Non-throwing
///        var value: ThrowingValue<Int> { get }  // ❌ Wrong protocol
///    }
///    
///    @Storage
///    protocol Settings: ThrowingKeyValueStoring {
///        var value: ThrowingValue<Int> { get }  // ✅ Read-write throwing
///        var readOnly: ThrowingGetter<String> { get }  // ✅ Read-only throwing (no @ReadOnlyKey needed)
///    }
///    
///    // UserDefaults can conform to throwing protocols (never actually throws)
///    extension UserDefaults: Settings {}  // ✅ Works - UserDefaults conforms to throwing protocols
///    
///    // Usage:
///    let settings: Settings = UserDefaults.standard
///    try settings.value.set(42)  // Never throws in practice
///    let val = try settings.value.get()  // Never throws in practice
///    ```
///
/// 4. **Type-safe suite/file isolation (especially important for KeyValueFileStore)**
///    ```swift
///    // Standard usage (single suite or file):
///    extension UserDefaults: AppSettings {}  // ✅ Simple, direct extension
///    extension KeyValueFileStore: CacheSettings {}  // ✅ Simple, direct extension
///    
///    // Usage with dependency injection:
///    class MyService {
///        let settings: AppSettings
///        init(settings: AppSettings = .standard) {  // Default parameter
///            self.settings = settings
///        }
///    }
///    let service = MyService()  // Uses UserDefaults.standard
///    let customService = MyService(settings: UserDefaults.standard)  // Explicit
///    
///    // Type-safe isolation (multiple suites/files that shouldn't mix):
///    
///    // UserDefaults - different suites:
///    final class AppSettings: UserDefaults {
///        init() { super.init(suiteName: "com.app.settings")! }
///    }
///    final class DebugSettings: UserDefaults {
///        init() { super.init(suiteName: "com.app.debug")! }
///    }
///    extension AppSettings: SettingsProtocol {}
///    extension DebugSettings: DebugProtocol {}
///    
///    // KeyValueFileStore - different file paths:
///    final class UserPreferences: KeyValueFileStore {
///        init() throws { try super.init(fileURL: preferencesURL) }
///    }
///    final class AppCache: KeyValueFileStore {
///        init() throws { try super.init(fileURL: cacheURL) }
///    }
///    extension UserPreferences: PreferencesProtocol {}
///    extension AppCache: CacheProtocol {}
///    
///    // Type safety prevents mixing up suites/files:
///    func configure(settings: AppSettings) { ... }  // Can't inject DebugSettings!
///    func load(prefs: UserPreferences) { ... }      // Can't inject AppCache!
///    ```
///
/// 5. **Testability: Use InMemoryKeyValueStore for testing**
///    ```swift
///    import Macros
///    import Persistence
///    import PersistenceTestingUtils  // For InMemoryKeyValueStore
///    
///    // Production: Define @Storage protocol
///    @Storage
///    protocol AppSettings: ObservableKeyValueStoring {
///        var username: String? { get set }
///        var isEnabled: Bool? { get set }
///    }
///    extension UserDefaults: AppSettings {}
///    
///    // Tests: Use InMemoryKeyValueStore
///    extension InMemoryKeyValueStore: AppSettings {}  // ✅ Extend to conform to protocol
///    
///    let testSettings = InMemoryKeyValueStore()
///    let service = MyService(settings: testSettings)
///    
///    // For throwing protocols, use InMemoryObservableThrowingKeyValueStore:
///    @Storage
///    protocol ThrowingSettings: ObservableThrowingKeyValueStoring {
///        var value: ThrowingValue<Int> { get }
///    }
///    extension InMemoryObservableThrowingKeyValueStore: ThrowingSettings {}
///    
///    let throwingTest = InMemoryObservableThrowingKeyValueStore()
///    throwingTest.throwOnRead = MyError()  // Configure throwing behavior
///    
///    // Service with protocol injection
///    class MyService {
///        let settings: any AppSettings
///        init(settings: any AppSettings) { self.settings = settings }
///    }
///    ```
///
/// ## Access Control
///
/// Protocol visibility is propagated to generated code:
/// ```swift
/// public protocol Settings { }     // → public generated code
/// internal protocol Settings { }   // → internal generated code
/// ```
///
/// ## Nested Protocols
///
/// Fully supported with proper qualification:
/// ```swift
/// import Macros
/// import Persistence
///
/// struct MyService {
///     @Storage
///     protocol Settings: KeyValueStoring {
///         var enabled: Bool? { get set }
///     }
/// }
/// // Generates: extension MyService.Settings { ... }
/// ```
///
@attached(peer, names: suffixed(KeyPathMapping), prefixed(_), suffixed(_observationKey))
@attached(extension, names: arbitrary)
public macro Storage()
    = #externalMacro(module: "MacrosImplementation", type: "StorageMacro")

/// Specifies a custom storage key for a property in `@Storage` protocols
///
/// ## Usage
///
/// ```swift
/// import Macros
/// import Persistence
///
/// @Storage
/// protocol Settings: KeyValueStoring {
///     var username: String? { get set }  // Uses "username" as key (default)
///     
///     @Key("custom_key")  // Override: uses "custom_key" instead of "property"
///     var property: String? { get set }
///     
///     @Key("newKey", migratingLegacyKey: "old.key")  // Auto-migrate from old key
///     var migrated: String? { get set }
/// }
/// ```
///
/// **Default behavior:** Without `@Key`, the property name itself is used as the storage key.
///
/// ## Legacy Key Migration
///
/// Use `migratingLegacyKey` to automatically migrate values from old keys:
/// - On first read, the value is copied from the legacy key to the new key
/// - The legacy key is then removed from storage
/// - Subsequent accesses use only the new key
///
/// ## Key Validation
///
/// ⚠️ Keys with dots (`.`) break **efficient KVO observation** in `ObservableKeyValueStoring`.
///
/// **Solutions (best to worst):**
/// 1. Use simple keys: `@Key("appKey")` instead of `@Key("com.app.key")`
/// 2. Migrate from dotted keys: `@Key("appKey", migratingLegacyKey: "com.app.key")`
/// 3. ⚠️ Override with `allowDotsForLegacyKey: true` (discouraged, see below)
///
/// **Notes:**
/// - Legacy keys used for migration can contain dots (they're not observed)
/// - Dotted keys with `allowDotsForLegacyKey: true` **DO work** with observable protocols but:
///   - **UserDefaults:** Falls back to NotificationCenter observation (slower, less efficient than KVO)
///   - **Custom implementations:** May not work at all unless manually implemented
/// - **Recommendation:** Migrate to non-dotted keys for observable protocols
///
@attached(accessor)
public macro Key(_ key: StaticString, migratingLegacyKey: StaticString? = nil, allowDotsForLegacyKey: Bool = false)
    = #externalMacro(module: "MacrosImplementation", type: "KeyMacro")

/// Excludes properties from `@Storage` code generation
///
/// Use `@StorageIgnored` **only on properties** that shouldn't generate storage accessors.
/// Functions and associated types are automatically ignored and don't need this annotation.
///
/// ```swift
/// import Macros
/// import Persistence
///
/// @Storage
/// protocol Settings: KeyValueStoring {
///     var storedValue: String? { get set }  // ✅ Generated
///     
///     @StorageIgnored
///     var computedValue: Int? { get }  // ❌ Not generated (custom implementation required)
///     
///     // Functions and types are automatically ignored - no annotation needed
///     func customMethod()  // ✅ No @StorageIgnored needed
///     associatedtype CustomType  // ✅ No @StorageIgnored needed
/// }
/// ```
@attached(peer)
public macro StorageIgnored()
    = #externalMacro(module: "MacrosImplementation", type: "StorageIgnoredMacro")

/// Marks a property as read-only (no setter generated)
///
/// Use for properties that are computed or managed externally.
///
/// **Note:** `ThrowingGetter<T>` is automatically read-only - no `@ReadOnlyKey` needed.
///
/// ```swift
/// import Macros
/// import Persistence
///
/// @Storage
/// protocol Settings: KeyValueStoring {
///     var editable: String? { get set }  // Can write
///     
///     @ReadOnlyKey
///     var readOnly: Int? { get }  // Cannot write
/// }
/// ```
@attached(peer)
public macro ReadOnlyKey()
    = #externalMacro(module: "MacrosImplementation", type: "ReadOnlyKeyMacro")


// MARK: - SwiftUI & Combine Macros

/// Automatically forwards a nested `ObservableObject`'s change notifications to the parent `ObservableObject`.
///
/// Apply this macro to properties of type `ObservableObject` within an `ObservableObject` class.
/// The macro generates:
/// - A backing storage variable (`_propertyName`)
/// - A stored `AnyCancellable` for the subscription (`_propertyNameCancellable`)
/// - A computed property that manages subscriptions automatically
///
/// ## Usage
///
/// ```swift
/// final class ParentModel: ObservableObject {
///     @NestedObservable var child: ChildModel = ChildModel()
/// }
/// ```
///
/// ## Generated Code
///
/// The macro transforms the property into:
/// - A backing variable: `private var _child: ChildModel`
/// - A cancellable: `private var _childCancellable: AnyCancellable?`
/// - A computed property with getter/setter that:
///   - Sets up subscription on first access (lazy)
///   - Re-subscribes when the property is replaced
///   - Forwards `child.objectWillChange` to `parent.objectWillChange`
///
/// ## Notes
///
/// - The nested object must conform to `ObservableObject`
/// - The parent class must conform to `ObservableObject`
/// - Subscription is set up lazily on first property access
/// - When the property is set to a new object, the old subscription is cancelled and a new one is created
///
@attached(accessor)
@attached(peer, names: arbitrary)
public macro NestedObservable()
    = #externalMacro(module: "MacrosImplementation", type: "NestedObservableMacro")

// MARK: - Utility Macros

/// Compile-time validated URL instantiation from String Literal
///
/// Creates URL instances from string literals with compile-time validation.
/// Rejects invalid URLs, punycode, and no-scheme URLs.
///
/// ## Usage
///
/// ```swift
/// let url = #URL("https://duckduckgo.com")  // ✅ Valid
/// let api = #URL("https://api.example.com/v1")  // ✅ Valid
///
/// let bad = #URL("http://💩.la")  // ❌ Compile error
/// let invalid = #URL("not-a-url")  // ❌ Compile error
/// ```
///
/// ## Note
///
/// For dynamic URLs, use `URL(string:)` or URL composition methods:
/// - `URL.appendingPathComponent(_:)`
/// - `URL.appendingParameters(_:allowedReservedCharacters:)`
///
@freestanding(expression)
public macro URL(_ string: StaticString) -> URL = #externalMacro(module: "MacrosImplementation", type: "URLMacro")
