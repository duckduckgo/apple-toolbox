//
//  StorageMacroTests.swift
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

@testable import MacrosImplementation
import MacroTesting
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite(
  .macros(
    [
        "Storage": StorageMacro.self,
        "Key": KeyMacro.self,
        "StorageIgnored": StorageIgnoredMacro.self
    ],
    record: .none
  )
)
struct StorageMacroTests {
    
    // MARK: - Basic Expansion Tests
    
    @Test("Basic protocol with simple properties")
    func testBasicProtocolWithSimpleProperties() {
        assertMacro {
            """
            @Storage
            protocol AppSettings: KeyValueStoring {
                var isFirstLaunch: Bool? { get set }
                var refreshInterval: Double? { get set }
            }
            """
        } expansion: {
          #"""
          protocol AppSettings: KeyValueStoring {
              var isFirstLaunch: Bool? { get set }
              var refreshInterval: Double? { get set }
          }

          private enum AppSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \AppSettings.isFirstLaunch: "isFirstLaunch",
                  \AppSettings.refreshInterval: "refreshInterval"
              ]
          }

          extension AppSettings {
              var isFirstLaunch: Bool? {
                  get {
                      return self.object(forKey: "isFirstLaunch") as? Bool
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "isFirstLaunch")
                              } else {
                                  self.removeObject(forKey: "isFirstLaunch")
                              }
                  }
              }
              var refreshInterval: Double? {
                  get {
                      return self.object(forKey: "refreshInterval") as? Double
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "refreshInterval")
                              } else {
                                  self.removeObject(forKey: "refreshInterval")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Protocol with custom storage keys")
    func testProtocolWithCustomStorageKeys() {
        assertMacro {
            """
            @Storage
            protocol AppSettings: KeyValueStoring {
                @Key("is-first-launch")
                var isFirstLaunch: Bool? { get set }
                
                var refreshInterval: Double? { get set }
            }
            """
        } expansion: {
          #"""
          protocol AppSettings: KeyValueStoring {
              var isFirstLaunch: Bool? { get set 
                  get {
                      object(forKey: "is-first-launch") as? Bool
                  }

                  set {
                      if let value = newValue {
                                  set(value, forKey: "is-first-launch")
                              } else {
                                  removeObject(forKey: "is-first-launch")
                              }
                  }}
              
              var refreshInterval: Double? { get set }
          }

          private enum AppSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \AppSettings.isFirstLaunch: "is-first-launch",
                  \AppSettings.refreshInterval: "refreshInterval"
              ]
          }

          extension AppSettings {
              var isFirstLaunch: Bool? {
                  get {
                      return self.object(forKey: "is-first-launch") as? Bool
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "is-first-launch")
                              } else {
                                  self.removeObject(forKey: "is-first-launch")
                              }
                  }
              }
              var refreshInterval: Double? {
                  get {
                      return self.object(forKey: "refreshInterval") as? Double
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "refreshInterval")
                              } else {
                                  self.removeObject(forKey: "refreshInterval")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Nested protocol in struct")
    func testNestedProtocolInStruct() {
        // Note: In real usage, the qualified name is correctly provided (e.g., SyncDiagnosisHelper.Settings).
        // The helper enum name includes dots and becomes SyncDiagnosisHelper.SettingsKeyPathMapping.
        assertMacro {
            """
            struct AppConfig {
                @Storage
                protocol Settings: KeyValueStoring {
                    var debugMode: Bool? { get set }
                    var apiKey: String? { get set }
                }
            }
            """
        } expansion: {
          #"""
          struct AppConfig {
              protocol Settings: KeyValueStoring {
                  var debugMode: Bool? { get set }
                  var apiKey: String? { get set }
              }

              private enum SettingsKeyPathMapping {
                  static let keyPathToStorageKey: [AnyKeyPath: String] = [
                      \Settings.debugMode: "debugMode",
                      \Settings.apiKey: "apiKey"
                  ]
              }
          }

          extension Settings {
              var debugMode: Bool? {
                  get {
                      return self.object(forKey: "debugMode") as? Bool
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "debugMode")
                              } else {
                                  self.removeObject(forKey: "debugMode")
                              }
                  }
              }
              var apiKey: String? {
                  get {
                      return self.object(forKey: "apiKey") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "apiKey")
                              } else {
                                  self.removeObject(forKey: "apiKey")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Optional types")
    func testOptionalTypes() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var optionalBool: Bool? { get set }
                var optionalInt: Int? { get set }
                var optionalDouble: Double? { get set }
                var optionalString: String? { get set }
                var optionalData: Data? { get set }
            }
            """
        } expansion: {
          #"""
          protocol Settings: KeyValueStoring {
              var optionalBool: Bool? { get set }
              var optionalInt: Int? { get set }
              var optionalDouble: Double? { get set }
              var optionalString: String? { get set }
              var optionalData: Data? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.optionalBool: "optionalBool",
                  \Settings.optionalInt: "optionalInt",
                  \Settings.optionalDouble: "optionalDouble",
                  \Settings.optionalString: "optionalString",
                  \Settings.optionalData: "optionalData"
              ]
          }

          extension Settings {
              var optionalBool: Bool? {
                  get {
                      return self.object(forKey: "optionalBool") as? Bool
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "optionalBool")
                              } else {
                                  self.removeObject(forKey: "optionalBool")
                              }
                  }
              }
              var optionalInt: Int? {
                  get {
                      return self.object(forKey: "optionalInt") as? Int
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "optionalInt")
                              } else {
                                  self.removeObject(forKey: "optionalInt")
                              }
                  }
              }
              var optionalDouble: Double? {
                  get {
                      return self.object(forKey: "optionalDouble") as? Double
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "optionalDouble")
                              } else {
                                  self.removeObject(forKey: "optionalDouble")
                              }
                  }
              }
              var optionalString: String? {
                  get {
                      return self.object(forKey: "optionalString") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "optionalString")
                              } else {
                                  self.removeObject(forKey: "optionalString")
                              }
                  }
              }
              var optionalData: Data? {
                  get {
                      return self.object(forKey: "optionalData") as? Data
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "optionalData")
                              } else {
                                  self.removeObject(forKey: "optionalData")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Non-optional types are rejected")
    func testNonOptionalTypes() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var requiredBool: Bool { get set }
                var requiredInt: Int { get set }
                var requiredDouble: Double { get set }
                var requiredString: String { get set }
                var requiredData: Data { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage property 'requiredBool' must be optional. Change 'Bool' to 'Bool?'. Only ThrowingValue<T> and ThrowingGetter<T> properties can be non-optional.
          protocol Settings: KeyValueStoring {
              var requiredBool: Bool { get set }
              var requiredInt: Int { get set }
              var requiredDouble: Double { get set }
              var requiredString: String { get set }
              var requiredData: Data { get set }
          }
          """
        }
    }
    
    @Test("Mixed optional and non-optional properties")
    func testMixedOptionalAndNonOptional() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var isEnabled: Bool { get set }
                var username: String? { get set }
                var count: Int { get set }
                var lastSync: Double? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage property 'isEnabled' must be optional. Change 'Bool' to 'Bool?'. Only ThrowingValue<T> and ThrowingGetter<T> properties can be non-optional.
          protocol Settings: KeyValueStoring {
              var isEnabled: Bool { get set }
              var username: String? { get set }
              var count: Int { get set }
              var lastSync: Double? { get set }
          }
          """
        }
    }
    
    @Test("Empty protocol")
    func testEmptyProtocol() {
        assertMacro {
            """
            @Storage
            protocol EmptySettings: KeyValueStoring {
            }
            """
        } expansion: {
          """
          protocol EmptySettings: KeyValueStoring {
          }

          private enum EmptySettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [

              ]
          }

          extension EmptySettings {
          }
          """
        }
    }
    
    @Test("Protocol with read-only properties")
    func testProtocolWithReadOnlyProperties() {
        assertMacro {
            """
            @Storage
            protocol ReadOnlySettings: KeyValueStoring {
                var value: String { get }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage property 'value' must be optional. Change 'String' to 'String?'. Only ThrowingValue<T> and ThrowingGetter<T> properties can be non-optional.
          protocol ReadOnlySettings: KeyValueStoring {
              var value: String { get }
          }
          """
        }
    }
    
    @Test("Protocol not inheriting from KeyValueStoring")
    func testProtocolNotInheritingFromKeyValueStoring() {
        assertMacro {
            """
            @Storage
            protocol BadSettings {
                var value: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage requires the protocol to inherit from exactly one of: KeyValueStoring, ThrowingKeyValueStoring, ObservableKeyValueStoring, or ObservableThrowingKeyValueStoring
          protocol BadSettings {
              var value: String? { get set }
          }
          """
        }
    }
    
    @Test("Complex types")
    func testComplexTypes() {
        assertMacro {
            """
            @Storage
            protocol ComplexSettings: KeyValueStoring {
                var array: [String]? { get set }
                var dictionary: [String: Int]? { get set }
                var date: Date? { get set }
                var url: URL? { get set }
            }
            """
        } expansion: {
          #"""
          protocol ComplexSettings: KeyValueStoring {
              var array: [String]? { get set }
              var dictionary: [String: Int]? { get set }
              var date: Date? { get set }
              var url: URL? { get set }
          }

          private enum ComplexSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ComplexSettings.array: "array",
                  \ComplexSettings.dictionary: "dictionary",
                  \ComplexSettings.date: "date",
                  \ComplexSettings.url: "url"
              ]
          }

          extension ComplexSettings {
              var array: [String]? {
                  get {
                      return self.object(forKey: "array") as? [String]
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "array")
                              } else {
                                  self.removeObject(forKey: "array")
                              }
                  }
              }
              var dictionary: [String: Int]? {
                  get {
                      return self.object(forKey: "dictionary") as? [String: Int]
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "dictionary")
                              } else {
                                  self.removeObject(forKey: "dictionary")
                              }
                  }
              }
              var date: Date? {
                  get {
                      return self.object(forKey: "date") as? Date
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "date")
                              } else {
                                  self.removeObject(forKey: "date")
                              }
                  }
              }
              var url: URL? {
                  get {
                      return self.object(forKey: "url") as? URL
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "url")
                              } else {
                                  self.removeObject(forKey: "url")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Multiple StorageKey attributes")
    func testMultipleStorageKeyAttributes() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                @Key("app.first.launch")
                var isFirstLaunch: Bool? { get set }
                
                @Key("user.name")
                var userName: String? { get set }
                
                @Key("session.count")
                var sessionCount: Int? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          protocol Settings: KeyValueStoring {
              @Key("app.first.launch")
              ┬───────────────────────
              ╰─ 🛑 @Key error: The key 'app.first.launch' contains a dot (.) which breaks KVO observation.

          Keys with dots cannot be observed by ObservableKeyValueStoring protocols.

          Choose one of these solutions:

          1. Migrate to a new key without dots (recommended):
             @Key("newKeyWithoutDots", migratingLegacyKey: "app.first.launch")

          2. If this key will NOT be observed (not used with ObservableKeyValueStoring):
             @Key("app.first.launch", allowDotsForLegacyKey: true)
              var isFirstLaunch: Bool? { get set }
              
              @Key("user.name")
              ┬────────────────
              ╰─ 🛑 @Key error: The key 'user.name' contains a dot (.) which breaks KVO observation.

          Keys with dots cannot be observed by ObservableKeyValueStoring protocols.

          Choose one of these solutions:

          1. Migrate to a new key without dots (recommended):
             @Key("newKeyWithoutDots", migratingLegacyKey: "user.name")

          2. If this key will NOT be observed (not used with ObservableKeyValueStoring):
             @Key("user.name", allowDotsForLegacyKey: true)
              var userName: String? { get set }
              
              @Key("session.count")
              ┬────────────────────
              ╰─ 🛑 @Key error: The key 'session.count' contains a dot (.) which breaks KVO observation.

          Keys with dots cannot be observed by ObservableKeyValueStoring protocols.

          Choose one of these solutions:

          1. Migrate to a new key without dots (recommended):
             @Key("newKeyWithoutDots", migratingLegacyKey: "session.count")

          2. If this key will NOT be observed (not used with ObservableKeyValueStoring):
             @Key("session.count", allowDotsForLegacyKey: true)
              var sessionCount: Int? { get set }
          }
          """
        } 
    }
    
    @Test("Single non-optional property")
    func testSingleNonOptionalProperty() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var isEnabled: Bool { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage property 'isEnabled' must be optional. Change 'Bool' to 'Bool?'. Only ThrowingValue<T> and ThrowingGetter<T> properties can be non-optional.
          protocol Settings: KeyValueStoring {
              var isEnabled: Bool { get set }
          }
          """
        }
    }
    
    @Test("Unsupported custom type")
    func testUnsupportedCustomType() {
        assertMacro {
            """
            struct CustomType {
                var value: String
            }
            
            @Storage
            protocol Settings: KeyValueStoring {
                var customValue: CustomType? { get set }
            }
            """
        } expansion: {
          #"""
          struct CustomType {
              var value: String
          }
          protocol Settings: KeyValueStoring {
              var customValue: CustomType? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.customValue: "customValue"
              ]
          }

          extension Settings {
              var customValue: CustomType? {
                  get {
                      if let rawValue = self.object(forKey: "customValue") {
                                  return (rawValue as? CustomType) ?? (rawValue as? CustomType.RawValue).flatMap(CustomType.init(rawValue:))
                              }
                              return nil
                  }
                  set {
                      if let newValue = newValue {
                                  if let rawValue = (newValue as? any RawRepresentable)?.rawValue {
                                      self.set(rawValue, forKey: "customValue")
                                  } else {
                                      self.set(newValue, forKey: "customValue")
                                  }
                              } else {
                                  self.removeObject(forKey: "customValue")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Unsupported tuple type")
    func testUnsupportedTupleType() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var coordinates: (Double, Double)? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage does not support tuple type '(Double, Double)' for property 'coordinates'. Use @StorageIgnored to exclude this property.
          protocol Settings: KeyValueStoring {
              var coordinates: (Double, Double)? { get set }
          }
          """
        }
    }
    
    @Test("Unsupported closure type")
    func testUnsupportedClosureType() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var callback: (() -> Void)? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage does not support closure type '(() -> Void)' for property 'callback'. Use @StorageIgnored to exclude this property.
          protocol Settings: KeyValueStoring {
              var callback: (() -> Void)? { get set }
          }
          """
        }
    }
    
    @Test("Mixed supported and unsupported types - unsupported types pass through macro but fail at compile-time")
    func testMixedSupportedAndUnsupportedTypes() {
        // Note: The macro generates code for CustomType (treating it as potentially RawRepresentable),
        // but this will fail at Swift compile-time since CustomType doesn't conform to RawRepresentable
        // and can't be stored in UserDefaults. This is intentional - we let Swift's type system catch it.
        assertMacro {
            """
            struct CustomType {
                var value: String
            }
            
            @Storage
            protocol Settings: KeyValueStoring {
                var validString: String? { get set }
                var invalidCustom: CustomType? { get set }
                var validInt: Int? { get set }
            }
            """
        } expansion: {
          #"""
          struct CustomType {
              var value: String
          }
          protocol Settings: KeyValueStoring {
              var validString: String? { get set }
              var invalidCustom: CustomType? { get set }
              var validInt: Int? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.validString: "validString",
                  \Settings.invalidCustom: "invalidCustom",
                  \Settings.validInt: "validInt"
              ]
          }

          extension Settings {
              var validString: String? {
                  get {
                      return self.object(forKey: "validString") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "validString")
                              } else {
                                  self.removeObject(forKey: "validString")
                              }
                  }
              }
              var invalidCustom: CustomType? {
                  get {
                      if let rawValue = self.object(forKey: "invalidCustom") {
                                  return (rawValue as? CustomType) ?? (rawValue as? CustomType.RawValue).flatMap(CustomType.init(rawValue:))
                              }
                              return nil
                  }
                  set {
                      if let newValue = newValue {
                                  if let rawValue = (newValue as? any RawRepresentable)?.rawValue {
                                      self.set(rawValue, forKey: "invalidCustom")
                                  } else {
                                      self.set(newValue, forKey: "invalidCustom")
                                  }
                              } else {
                                  self.removeObject(forKey: "invalidCustom")
                              }
                  }
              }
              var validInt: Int? {
                  get {
                      return self.object(forKey: "validInt") as? Int
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "validInt")
                              } else {
                                  self.removeObject(forKey: "validInt")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Data type is supported")
    func testDataTypeSupported() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var imageData: Data? { get set }
                var configData: Data? { get set }
            }
            """
        } expansion: {
          #"""
          protocol Settings: KeyValueStoring {
              var imageData: Data? { get set }
              var configData: Data? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.imageData: "imageData",
                  \Settings.configData: "configData"
              ]
          }

          extension Settings {
              var imageData: Data? {
                  get {
                      return self.object(forKey: "imageData") as? Data
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "imageData")
                              } else {
                                  self.removeObject(forKey: "imageData")
                              }
                  }
              }
              var configData: Data? {
                  get {
                      return self.object(forKey: "configData") as? Data
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "configData")
                              } else {
                                  self.removeObject(forKey: "configData")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Custom class type passes through macro but fails at compile-time")
    func testCustomClassTypePassesThrough() {
        // Note: The macro generates code for CustomClass (treating it as potentially RawRepresentable),
        // but this will fail at Swift compile-time since classes can't be stored in UserDefaults.
        assertMacro {
            """
            class CustomClass {
                var value: String
            }
            
            @Storage
            protocol Settings: KeyValueStoring {
                var customObject: CustomClass? { get set }
            }
            """
        } expansion: {
          #"""
          class CustomClass {
              var value: String
          }
          protocol Settings: KeyValueStoring {
              var customObject: CustomClass? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.customObject: "customObject"
              ]
          }

          extension Settings {
              var customObject: CustomClass? {
                  get {
                      if let rawValue = self.object(forKey: "customObject") {
                                  return (rawValue as? CustomClass) ?? (rawValue as? CustomClass.RawValue).flatMap(CustomClass.init(rawValue:))
                              }
                              return nil
                  }
                  set {
                      if let newValue = newValue {
                                  if let rawValue = (newValue as? any RawRepresentable)?.rawValue {
                                      self.set(rawValue, forKey: "customObject")
                                  } else {
                                      self.set(newValue, forKey: "customObject")
                                  }
                              } else {
                                  self.removeObject(forKey: "customObject")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Custom enum without RawRepresentable passes through macro but fails at compile-time")
    func testCustomEnumWithoutRawValuePassesThrough() {
        // Note: The macro generates code for CustomEnum (treating it as potentially RawRepresentable),
        // but this will fail at Swift compile-time since CustomEnum has no raw value.
        // Enums MUST have String or Int raw values to work with UserDefaults.
        assertMacro {
            """
            enum CustomEnum {
                case one, two
            }
            
            @Storage
            protocol Settings: KeyValueStoring {
                var enumValue: CustomEnum? { get set }
            }
            """
        } expansion: {
          #"""
          enum CustomEnum {
              case one, two
          }
          protocol Settings: KeyValueStoring {
              var enumValue: CustomEnum? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.enumValue: "enumValue"
              ]
          }

          extension Settings {
              var enumValue: CustomEnum? {
                  get {
                      if let rawValue = self.object(forKey: "enumValue") {
                                  return (rawValue as? CustomEnum) ?? (rawValue as? CustomEnum.RawValue).flatMap(CustomEnum.init(rawValue:))
                              }
                              return nil
                  }
                  set {
                      if let newValue = newValue {
                                  if let rawValue = (newValue as? any RawRepresentable)?.rawValue {
                                      self.set(rawValue, forKey: "enumValue")
                                  } else {
                                      self.set(newValue, forKey: "enumValue")
                                  }
                              } else {
                                  self.removeObject(forKey: "enumValue")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Protocol with functions ignores them")
    func testProtocolWithFunctionsIgnoresThem() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var value: String? { get set }
                func doSomething()
                func getValue() -> String?
            }
            """
        } expansion: {
          #"""
          protocol Settings: KeyValueStoring {
              var value: String? { get set }
              func doSomething()
              func getValue() -> String?
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.value: "value"
              ]
          }

          extension Settings {
              var value: String? {
                  get {
                      return self.object(forKey: "value") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "value")
                              } else {
                                  self.removeObject(forKey: "value")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Protocol with associated types ignores them")
    func testProtocolWithAssociatedTypesIgnoresThem() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                associatedtype ValueType
                var value: String? { get set }
            }
            """
        } expansion: {
          #"""
          protocol Settings: KeyValueStoring {
              associatedtype ValueType
              var value: String? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.value: "value"
              ]
          }

          extension Settings {
              var value: String? {
                  get {
                      return self.object(forKey: "value") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "value")
                              } else {
                                  self.removeObject(forKey: "value")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Protocol without KeyValueStoring inheritance")
    func testProtocolWithoutKeyValueStoringShowsWarning() {
        assertMacro {
            """
            @Storage
            protocol BadSettings {
                var value: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage requires the protocol to inherit from exactly one of: KeyValueStoring, ThrowingKeyValueStoring, ObservableKeyValueStoring, or ObservableThrowingKeyValueStoring
          protocol BadSettings {
              var value: String? { get set }
          }
          """
        }
    }
    
    @Test("Protocol with ThrowingKeyValueStoring works")
    func testProtocolWithThrowingKeyValueStoring() {
        assertMacro {
            """
            @Storage
            protocol Settings: ThrowingKeyValueStoring {
                var value: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage with ThrowingKeyValueStoring requires properties to use ThrowingValue<T> or ThrowingGetter<T>. Property 'value' has type 'String?'. Use 'var value: ThrowingValue<String> { get }' for read-write or 'var value: ThrowingGetter<String> { get }' for read-only.
          protocol Settings: ThrowingKeyValueStoring {
              var value: String? { get set }
          }
          """
        }
    }
    
    @Test("Protocol with both storage protocols works")
    func testProtocolWithBothStorageProtocols() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring, ThrowingKeyValueStoring {
                var value: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage protocol cannot inherit from multiple storage protocols. Found: KeyValueStoring, ThrowingKeyValueStoring. Choose exactly one.
          protocol Settings: KeyValueStoring, ThrowingKeyValueStoring {
              var value: String? { get set }
          }
          """
        } 
    }
    
    @Test("All UserDefaults-supported types")
    func testAllUserDefaultsSupportedTypes() {
        assertMacro {
            """
            @Storage
            protocol AllTypes: KeyValueStoring {
                var boolValue: Bool? { get set }
                var intValue: Int? { get set }
                var doubleValue: Double? { get set }
                var floatValue: Float? { get set }
                var stringValue: String? { get set }
                var dataValue: Data? { get set }
                var dateValue: Date? { get set }
                var urlValue: URL? { get set }
                var arrayValue: [String]? { get set }
                var dictValue: [String: Int]? { get set }
            }
            """
        } expansion: {
          #"""
          protocol AllTypes: KeyValueStoring {
              var boolValue: Bool? { get set }
              var intValue: Int? { get set }
              var doubleValue: Double? { get set }
              var floatValue: Float? { get set }
              var stringValue: String? { get set }
              var dataValue: Data? { get set }
              var dateValue: Date? { get set }
              var urlValue: URL? { get set }
              var arrayValue: [String]? { get set }
              var dictValue: [String: Int]? { get set }
          }

          private enum AllTypesKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \AllTypes.boolValue: "boolValue",
                  \AllTypes.intValue: "intValue",
                  \AllTypes.doubleValue: "doubleValue",
                  \AllTypes.floatValue: "floatValue",
                  \AllTypes.stringValue: "stringValue",
                  \AllTypes.dataValue: "dataValue",
                  \AllTypes.dateValue: "dateValue",
                  \AllTypes.urlValue: "urlValue",
                  \AllTypes.arrayValue: "arrayValue",
                  \AllTypes.dictValue: "dictValue"
              ]
          }

          extension AllTypes {
              var boolValue: Bool? {
                  get {
                      return self.object(forKey: "boolValue") as? Bool
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "boolValue")
                              } else {
                                  self.removeObject(forKey: "boolValue")
                              }
                  }
              }
              var intValue: Int? {
                  get {
                      return self.object(forKey: "intValue") as? Int
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "intValue")
                              } else {
                                  self.removeObject(forKey: "intValue")
                              }
                  }
              }
              var doubleValue: Double? {
                  get {
                      return self.object(forKey: "doubleValue") as? Double
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "doubleValue")
                              } else {
                                  self.removeObject(forKey: "doubleValue")
                              }
                  }
              }
              var floatValue: Float? {
                  get {
                      return self.object(forKey: "floatValue") as? Float
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "floatValue")
                              } else {
                                  self.removeObject(forKey: "floatValue")
                              }
                  }
              }
              var stringValue: String? {
                  get {
                      return self.object(forKey: "stringValue") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "stringValue")
                              } else {
                                  self.removeObject(forKey: "stringValue")
                              }
                  }
              }
              var dataValue: Data? {
                  get {
                      return self.object(forKey: "dataValue") as? Data
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "dataValue")
                              } else {
                                  self.removeObject(forKey: "dataValue")
                              }
                  }
              }
              var dateValue: Date? {
                  get {
                      return self.object(forKey: "dateValue") as? Date
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "dateValue")
                              } else {
                                  self.removeObject(forKey: "dateValue")
                              }
                  }
              }
              var urlValue: URL? {
                  get {
                      return self.object(forKey: "urlValue") as? URL
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "urlValue")
                              } else {
                                  self.removeObject(forKey: "urlValue")
                              }
                  }
              }
              var arrayValue: [String]? {
                  get {
                      return self.object(forKey: "arrayValue") as? [String]
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "arrayValue")
                              } else {
                                  self.removeObject(forKey: "arrayValue")
                              }
                  }
              }
              var dictValue: [String: Int]? {
                  get {
                      return self.object(forKey: "dictValue") as? [String: Int]
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "dictValue")
                              } else {
                                  self.removeObject(forKey: "dictValue")
                              }
                  }
              }
          }
          """#
        }
    }
    
    // MARK: - Legacy Key Migration Tests
    
    @Test("Property with legacy key generates migration code")
    func testPropertyWithLegacyKey() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                @Key("new.key", legacyKey: "old.key")
                var migratedProperty: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          protocol Settings: KeyValueStoring {
              @Key("new.key", legacyKey: "old.key")
              ┬────────────────────────────────────
              ╰─ 🛑 @Key error: The key 'new.key' contains a dot (.) which breaks KVO observation.

          Keys with dots cannot be observed by ObservableKeyValueStoring protocols.

          Choose one of these solutions:

          1. Migrate to a new key without dots (recommended):
             @Key("newKeyWithoutDots", migratingLegacyKey: "new.key")

          2. If this key will NOT be observed (not used with ObservableKeyValueStoring):
             @Key("new.key", allowDotsForLegacyKey: true)
              var migratedProperty: String? { get set }
          }
          """
        } 
    }
    
    @Test("Multiple properties with legacy keys")
    func testMultiplePropertiesWithLegacyKeys() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                @Key("user.name", legacyKey: "username")
                var userName: String? { get set }
                
                @Key("is.enabled", legacyKey: "enabled")
                var isEnabled: Bool? { get set }
                
                var normalProperty: Int? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          protocol Settings: KeyValueStoring {
              @Key("user.name", legacyKey: "username")
              ┬───────────────────────────────────────
              ╰─ 🛑 @Key error: The key 'user.name' contains a dot (.) which breaks KVO observation.

          Keys with dots cannot be observed by ObservableKeyValueStoring protocols.

          Choose one of these solutions:

          1. Migrate to a new key without dots (recommended):
             @Key("newKeyWithoutDots", migratingLegacyKey: "user.name")

          2. If this key will NOT be observed (not used with ObservableKeyValueStoring):
             @Key("user.name", allowDotsForLegacyKey: true)
              var userName: String? { get set }
              
              @Key("is.enabled", legacyKey: "enabled")
              ┬───────────────────────────────────────
              ╰─ 🛑 @Key error: The key 'is.enabled' contains a dot (.) which breaks KVO observation.

          Keys with dots cannot be observed by ObservableKeyValueStoring protocols.

          Choose one of these solutions:

          1. Migrate to a new key without dots (recommended):
             @Key("newKeyWithoutDots", migratingLegacyKey: "is.enabled")

          2. If this key will NOT be observed (not used with ObservableKeyValueStoring):
             @Key("is.enabled", allowDotsForLegacyKey: true)
              var isEnabled: Bool? { get set }
              
              var normalProperty: Int? { get set }
          }
          """
        } 
    }
    
    // MARK: - StorageIgnored Tests
    
    @Test("StorageIgnored on function prevents generation")
    func testStorageIgnoredOnFunction() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var value: String? { get set }
                
                @StorageIgnored
                func customMethod()
                
                @StorageIgnored
                func anotherMethod() -> Int
            }
            """
        } expansion: {
          #"""
          protocol Settings: KeyValueStoring {
              var value: String? { get set }
              
              func customMethod()
              
              func anotherMethod() -> Int
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.value: "value"
              ]
          }

          extension Settings {
              var value: String? {
                  get {
                      return self.object(forKey: "value") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "value")
                              } else {
                                  self.removeObject(forKey: "value")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("StorageIgnored on associated type")
    func testStorageIgnoredOnAssociatedType() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var value: String? { get set }
                
                @StorageIgnored
                associatedtype ValueType
            }
            """
        } expansion: {
          #"""
          protocol Settings: KeyValueStoring {
              var value: String? { get set }
              
              associatedtype ValueType
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.value: "value"
              ]
          }

          extension Settings {
              var value: String? {
                  get {
                      return self.object(forKey: "value") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "value")
                              } else {
                                  self.removeObject(forKey: "value")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("StorageIgnored mixed with regular properties")
    func testStorageIgnoredMixedWithProperties() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var prop1: String? { get set }
                
                @StorageIgnored
                func helper()
                
                var prop2: Int? { get set }
                
                @StorageIgnored
                associatedtype T
                
                var prop3: Bool? { get set }
            }
            """
        } expansion: {
          #"""
          protocol Settings: KeyValueStoring {
              var prop1: String? { get set }
              
              func helper()
              
              var prop2: Int? { get set }
              
              associatedtype T
              
              var prop3: Bool? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.prop1: "prop1",
                  \Settings.prop2: "prop2",
                  \Settings.prop3: "prop3"
              ]
          }

          extension Settings {
              var prop1: String? {
                  get {
                      return self.object(forKey: "prop1") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "prop1")
                              } else {
                                  self.removeObject(forKey: "prop1")
                              }
                  }
              }
              var prop2: Int? {
                  get {
                      return self.object(forKey: "prop2") as? Int
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "prop2")
                              } else {
                                  self.removeObject(forKey: "prop2")
                              }
                  }
              }
              var prop3: Bool? {
                  get {
                      return self.object(forKey: "prop3") as? Bool
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "prop3")
                              } else {
                                  self.removeObject(forKey: "prop3")
                              }
                  }
              }
          }
          """#
        }
    }
    
    // MARK: - RawRepresentable Enum Tests
    
    @Test("Enum with String raw value")
    func testEnumWithStringRawValue() {
        assertMacro {
            """
            enum Theme: String {
                case light, dark
            }
            
            @Storage
            protocol Settings: KeyValueStoring {
                var theme: Theme? { get set }
                var name: String? { get set }
            }
            """
        } expansion: {
          #"""
          enum Theme: String {
              case light, dark
          }
          protocol Settings: KeyValueStoring {
              var theme: Theme? { get set }
              var name: String? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.theme: "theme",
                  \Settings.name: "name"
              ]
          }

          extension Settings {
              var theme: Theme? {
                  get {
                      if let rawValue = self.object(forKey: "theme") {
                                  return (rawValue as? Theme) ?? (rawValue as? Theme.RawValue).flatMap(Theme.init(rawValue:))
                              }
                              return nil
                  }
                  set {
                      if let newValue = newValue {
                                  if let rawValue = (newValue as? any RawRepresentable)?.rawValue {
                                      self.set(rawValue, forKey: "theme")
                                  } else {
                                      self.set(newValue, forKey: "theme")
                                  }
                              } else {
                                  self.removeObject(forKey: "theme")
                              }
                  }
              }
              var name: String? {
                  get {
                      return self.object(forKey: "name") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "name")
                              } else {
                                  self.removeObject(forKey: "name")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Enum with Int raw value")
    func testEnumWithIntRawValue() {
        assertMacro {
            """
            enum Priority: Int {
                case low = 0
                case high = 1
            }
            
            @Storage
            protocol Settings: KeyValueStoring {
                var priority: Priority? { get set }
            }
            """
        } expansion: {
          #"""
          enum Priority: Int {
              case low = 0
              case high = 1
          }
          protocol Settings: KeyValueStoring {
              var priority: Priority? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.priority: "priority"
              ]
          }

          extension Settings {
              var priority: Priority? {
                  get {
                      if let rawValue = self.object(forKey: "priority") {
                                  return (rawValue as? Priority) ?? (rawValue as? Priority.RawValue).flatMap(Priority.init(rawValue:))
                              }
                              return nil
                  }
                  set {
                      if let newValue = newValue {
                                  if let rawValue = (newValue as? any RawRepresentable)?.rawValue {
                                      self.set(rawValue, forKey: "priority")
                                  } else {
                                      self.set(newValue, forKey: "priority")
                                  }
                              } else {
                                  self.removeObject(forKey: "priority")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Multiple enum properties")
    func testMultipleEnumProperties() {
        assertMacro {
            """
            enum TabPosition: String {
                case top, bottom
            }
            
            enum SortOrder: Int {
                case ascending = 0
                case descending = 1
            }
            
            @Storage
            protocol Settings: KeyValueStoring {
                var tabPosition: TabPosition? { get set }
                var sortOrder: SortOrder? { get set }
                var isEnabled: Bool? { get set }
            }
            """
        } expansion: {
          #"""
          enum TabPosition: String {
              case top, bottom
          }

          enum SortOrder: Int {
              case ascending = 0
              case descending = 1
          }
          protocol Settings: KeyValueStoring {
              var tabPosition: TabPosition? { get set }
              var sortOrder: SortOrder? { get set }
              var isEnabled: Bool? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.tabPosition: "tabPosition",
                  \Settings.sortOrder: "sortOrder",
                  \Settings.isEnabled: "isEnabled"
              ]
          }

          extension Settings {
              var tabPosition: TabPosition? {
                  get {
                      if let rawValue = self.object(forKey: "tabPosition") {
                                  return (rawValue as? TabPosition) ?? (rawValue as? TabPosition.RawValue).flatMap(TabPosition.init(rawValue:))
                              }
                              return nil
                  }
                  set {
                      if let newValue = newValue {
                                  if let rawValue = (newValue as? any RawRepresentable)?.rawValue {
                                      self.set(rawValue, forKey: "tabPosition")
                                  } else {
                                      self.set(newValue, forKey: "tabPosition")
                                  }
                              } else {
                                  self.removeObject(forKey: "tabPosition")
                              }
                  }
              }
              var sortOrder: SortOrder? {
                  get {
                      if let rawValue = self.object(forKey: "sortOrder") {
                                  return (rawValue as? SortOrder) ?? (rawValue as? SortOrder.RawValue).flatMap(SortOrder.init(rawValue:))
                              }
                              return nil
                  }
                  set {
                      if let newValue = newValue {
                                  if let rawValue = (newValue as? any RawRepresentable)?.rawValue {
                                      self.set(rawValue, forKey: "sortOrder")
                                  } else {
                                      self.set(newValue, forKey: "sortOrder")
                                  }
                              } else {
                                  self.removeObject(forKey: "sortOrder")
                              }
                  }
              }
              var isEnabled: Bool? {
                  get {
                      return self.object(forKey: "isEnabled") as? Bool
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "isEnabled")
                              } else {
                                  self.removeObject(forKey: "isEnabled")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Enum with legacy key migration")
    func testEnumWithLegacyKeyMigration() {
        assertMacro {
            """
            enum DisplayMode: String {
                case compact, expanded
            }
            
            @Storage
            protocol Settings: KeyValueStoring {
                @Key("new.display.mode", legacyKey: "displayMode")
                var displayMode: DisplayMode? { get set }
            }
            """
        } diagnostics: {
          """
          enum DisplayMode: String {
              case compact, expanded
          }

          @Storage
          protocol Settings: KeyValueStoring {
              @Key("new.display.mode", legacyKey: "displayMode")
              ┬─────────────────────────────────────────────────
              ╰─ 🛑 @Key error: The key 'new.display.mode' contains a dot (.) which breaks KVO observation.

          Keys with dots cannot be observed by ObservableKeyValueStoring protocols.

          Choose one of these solutions:

          1. Migrate to a new key without dots (recommended):
             @Key("newKeyWithoutDots", migratingLegacyKey: "new.display.mode")

          2. If this key will NOT be observed (not used with ObservableKeyValueStoring):
             @Key("new.display.mode", allowDotsForLegacyKey: true)
              var displayMode: DisplayMode? { get set }
          }
          """
        } 
    }
    
    // MARK: - Protocol Inheritance Validation Tests
    
    @Test("Protocol without base protocol inheritance should fail")
    func testProtocolWithoutBaseProtocolInheritance() {
        assertMacro {
            """
            @Storage
            protocol Settings {
                var value: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage requires the protocol to inherit from exactly one of: KeyValueStoring, ThrowingKeyValueStoring, ObservableKeyValueStoring, or ObservableThrowingKeyValueStoring
          protocol Settings {
              var value: String? { get set }
          }
          """
        }
    }
    
    @Test("Protocol with ThrowingKeyValueStoring inheritance")
    func testThrowingKeyValueStoringProtocol() {
        assertMacro {
            """
            @Storage
            protocol Settings: ThrowingKeyValueStoring {
                var value: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage with ThrowingKeyValueStoring requires properties to use ThrowingValue<T> or ThrowingGetter<T>. Property 'value' has type 'String?'. Use 'var value: ThrowingValue<String> { get }' for read-write or 'var value: ThrowingGetter<String> { get }' for read-only.
          protocol Settings: ThrowingKeyValueStoring {
              var value: String? { get set }
          }
          """
        }
    }
    
    @Test("Protocol with KeyValueStoring inheritance")
    func testKeyValueStoringProtocol() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var value: String? { get set }
            }
            """
        } expansion: {
          #"""
          protocol Settings: KeyValueStoring {
              var value: String? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.value: "value"
              ]
          }

          extension Settings {
              var value: String? {
                  get {
                      return self.object(forKey: "value") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "value")
                              } else {
                                  self.removeObject(forKey: "value")
                              }
                  }
              }
          }
          """#
        }
    }
    
    // MARK: - ThrowingValue Tests
    
    @Test("ThrowingKeyValueStoring with ThrowingValue properties")
    func testThrowingValueBasic() {
        assertMacro {
            """
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                var username: ThrowingValue<String> { get }
                var count: ThrowingValue<Int> { get }
            }
            """
        } expansion: {
          #"""
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var username: ThrowingValue<String> { get }
              var count: ThrowingValue<Int> { get }
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.username: "username",
                  \ThrowingSettings.count: "count"
              ]
          }

          extension ThrowingSettings {
              var username: ThrowingValue<String> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "username") as? String
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "username")
                  } else {
                      try self.removeObject(forKey: "username")
                  }
                          }
                      )
                  }
              }
              var count: ThrowingValue<Int> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "count") as? Int
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "count")
                  } else {
                      try self.removeObject(forKey: "count")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    @Test("ThrowingValue with custom key")
    func testThrowingValueWithCustomKey() {
        assertMacro {
            """
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                @Key("user_name")
                var username: ThrowingValue<String> { get }
            }
            """
        } expansion: {
          #"""
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var username: ThrowingValue<String> { get }
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.username: "user_name"
              ]
          }

          extension ThrowingSettings {
              var username: ThrowingValue<String> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "user_name") as? String
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "user_name")
                  } else {
                      try self.removeObject(forKey: "user_name")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    @Test("ThrowingValue with legacy key migration")
    func testThrowingValueWithLegacyKey() {
        assertMacro {
            """
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                @Key("newUsername", migratingLegacyKey: "old.username")
                var username: ThrowingValue<String> { get }
            }
            """
        } expansion: {
          #"""
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var username: ThrowingValue<String> { get }
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.username: "newUsername"
              ]
          }

          extension ThrowingSettings {
              var username: ThrowingValue<String> {
                  get {
                      ThrowingValue(
                          getter: {
                  if let value = try self.object(forKey: "newUsername") as? String {
                      return value
                  }
                  // Migration: check legacy key
                  if let legacyValue = try self.object(forKey: "old.username") as? String {
                      try self.set(legacyValue, forKey: "newUsername")
                      try self.removeObject(forKey: "old.username")
                      return legacyValue
                  }
                  return nil
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "newUsername")
                  } else {
                      try self.removeObject(forKey: "newUsername")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    @Test("ThrowingValue with RawRepresentable enum")
    func testThrowingValueWithEnum() {
        assertMacro {
            """
            enum Theme: String {
                case light, dark
            }
            
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                var theme: ThrowingValue<Theme> { get }
            }
            """
        } expansion: {
          #"""
          enum Theme: String {
              case light, dark
          }
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var theme: ThrowingValue<Theme> { get }
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.theme: "theme"
              ]
          }

          extension ThrowingSettings {
              var theme: ThrowingValue<Theme> {
                  get {
                      ThrowingValue(
                          getter: {
                  guard let rawValue = try self.object(forKey: "theme") else {
                      return nil
                  }
                  return (Theme)(rawValue: rawValue as! Theme.RawValue)
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      if let rawValue = (newValue as? any RawRepresentable)?.rawValue {
                          try self.set(rawValue, forKey: "theme")
                      } else {
                          try self.set(newValue, forKey: "theme")
                      }
                  } else {
                      try self.removeObject(forKey: "theme")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    @Test("ThrowingValue with enum and legacy key")
    func testThrowingValueEnumWithLegacyKey() {
        assertMacro {
            """
            enum DisplayMode: Int {
                case compact = 0
                case expanded = 1
            }
            
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                @Key("displayMode", migratingLegacyKey: "old_display_mode")
                var mode: ThrowingValue<DisplayMode> { get }
            }
            """
        } expansion: {
          #"""
          enum DisplayMode: Int {
              case compact = 0
              case expanded = 1
          }
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var mode: ThrowingValue<DisplayMode> { get }
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.mode: "displayMode"
              ]
          }

          extension ThrowingSettings {
              var mode: ThrowingValue<DisplayMode> {
                  get {
                      ThrowingValue(
                          getter: {
                  if let rawValue = try self.object(forKey: "displayMode"), let value = (DisplayMode)(rawValue: rawValue as! DisplayMode.RawValue) {
                      return value
                  }
                  // Migration
                  if let legacyRawValue = try self.object(forKey: "old_display_mode"), let legacyValue = (DisplayMode)(rawValue: legacyRawValue as! DisplayMode.RawValue) {
                      if let rawValue = (legacyValue as? any RawRepresentable)?.rawValue {
                          try self.set(rawValue, forKey: "displayMode")
                      }
                      try self.removeObject(forKey: "old_display_mode")
                      return legacyValue
                  }
                  return nil
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      if let rawValue = (newValue as? any RawRepresentable)?.rawValue {
                          try self.set(rawValue, forKey: "displayMode")
                      } else {
                          try self.set(newValue, forKey: "displayMode")
                      }
                  } else {
                      try self.removeObject(forKey: "displayMode")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    @Test("ThrowingValue with multiple properties and mixed keys")
    func testThrowingValueMixedKeys() {
        assertMacro {
            """
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                var defaultValue: ThrowingValue<String> { get }
                
                @Key("custom_key")
                var customValue: ThrowingValue<Int> { get }
                
                @Key("migrated", migratingLegacyKey: "old.migrated")
                var migratedValue: ThrowingValue<Bool> { get }
            }
            """
        } expansion: {
          #"""
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var defaultValue: ThrowingValue<String> { get }
              
              var customValue: ThrowingValue<Int> { get }
              
              var migratedValue: ThrowingValue<Bool> { get }
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.defaultValue: "defaultValue",
                  \ThrowingSettings.customValue: "custom_key",
                  \ThrowingSettings.migratedValue: "migrated"
              ]
          }

          extension ThrowingSettings {
              var defaultValue: ThrowingValue<String> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "defaultValue") as? String
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "defaultValue")
                  } else {
                      try self.removeObject(forKey: "defaultValue")
                  }
                          }
                      )
                  }
              }
              var customValue: ThrowingValue<Int> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "custom_key") as? Int
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "custom_key")
                  } else {
                      try self.removeObject(forKey: "custom_key")
                  }
                          }
                      )
                  }
              }
              var migratedValue: ThrowingValue<Bool> {
                  get {
                      ThrowingValue(
                          getter: {
                  if let value = try self.object(forKey: "migrated") as? Bool {
                      return value
                  }
                  // Migration: check legacy key
                  if let legacyValue = try self.object(forKey: "old.migrated") as? Bool {
                      try self.set(legacyValue, forKey: "migrated")
                      try self.removeObject(forKey: "old.migrated")
                      return legacyValue
                  }
                  return nil
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "migrated")
                  } else {
                      try self.removeObject(forKey: "migrated")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    @Test("ThrowingValue with Data type")
    func testThrowingValueWithData() {
        assertMacro {
            """
            import Foundation
            
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                var blob: ThrowingValue<Data> { get }
            }
            """
        } expansion: {
          #"""
          import Foundation
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var blob: ThrowingValue<Data> { get }
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.blob: "blob"
              ]
          }

          extension ThrowingSettings {
              var blob: ThrowingValue<Data> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "blob") as? Data
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "blob")
                  } else {
                      try self.removeObject(forKey: "blob")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    @Test("ThrowingValue with Array type")
    func testThrowingValueWithArray() {
        assertMacro {
            """
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                var items: ThrowingValue<[String]> { get }
            }
            """
        } expansion: {
          #"""
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var items: ThrowingValue<[String]> { get }
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.items: "items"
              ]
          }

          extension ThrowingSettings {
              var items: ThrowingValue<[String]> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "items") as? [String]
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "items")
                  } else {
                      try self.removeObject(forKey: "items")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    @Test("ThrowingValue with Dictionary type")
    func testThrowingValueWithDictionary() {
        assertMacro {
            """
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                var metadata: ThrowingValue<[String: Int]> { get }
            }
            """
        } expansion: {
          #"""
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var metadata: ThrowingValue<[String: Int]> { get }
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.metadata: "metadata"
              ]
          }

          extension ThrowingSettings {
              var metadata: ThrowingValue<[String: Int]> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "metadata") as? [String: Int]
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "metadata")
                  } else {
                      try self.removeObject(forKey: "metadata")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    @Test("Error: ThrowingKeyValueStoring without ThrowingValue wrapper")
    func testThrowingKeyValueStoringRequiresThrowingValue() {
        assertMacro {
            """
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                var username: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage with ThrowingKeyValueStoring requires properties to use ThrowingValue<T> or ThrowingGetter<T>. Property 'username' has type 'String?'. Use 'var username: ThrowingValue<String> { get }' for read-write or 'var username: ThrowingGetter<String> { get }' for read-only.
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var username: String? { get set }
          }
          """
        }
    }
    
    @Test("Error: ThrowingValue with non-optional inner type")
    func testThrowingValueRequiresOptionalInnerType() {
        assertMacro {
            """
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                var username: ThrowingValue<String> { get }
            }
            """
        } diagnostics: {
          """

          """
        } expansion: {
          #"""
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var username: ThrowingValue<String> { get }
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.username: "username"
              ]
          }

          extension ThrowingSettings {
              var username: ThrowingValue<String> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "username") as? String
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "username")
                  } else {
                      try self.removeObject(forKey: "username")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    @Test("ThrowingValue no publisher generation")
    func testThrowingValueNoPublishers() {
        assertMacro {
            """
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                var value: ThrowingValue<Int> { get }
            }
            """
        } expansion: {
          #"""
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var value: ThrowingValue<Int> { get }
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.value: "value"
              ]
          }

          extension ThrowingSettings {
              var value: ThrowingValue<Int> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "value") as? Int
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "value")
                  } else {
                      try self.removeObject(forKey: "value")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    @Test("Public ThrowingValue properties")
    func testPublicThrowingValue() {
        assertMacro {
            """
            @Storage
            public protocol ThrowingSettings: ThrowingKeyValueStoring {
                var username: ThrowingValue<String> { get }
            }
            """
        } expansion: {
          #"""
          public protocol ThrowingSettings: ThrowingKeyValueStoring {
              var username: ThrowingValue<String> { get }
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.username: "username"
              ]
          }

          extension ThrowingSettings {
              public var username: ThrowingValue<String> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "username") as? String
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "username")
                  } else {
                      try self.removeObject(forKey: "username")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    @Test("Internal protocol generates internal accessors")
    func testInternalProtocol() {
        assertMacro {
            """
            @Storage
            internal protocol Settings: KeyValueStoring {
                var value: String? { get set }
            }
            """
        } expansion: {
          #"""
          internal protocol Settings: KeyValueStoring {
              var value: String? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.value: "value"
              ]
          }

          extension Settings {
              var value: String? {
                  get {
                      return self.object(forKey: "value") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "value")
                              } else {
                                  self.removeObject(forKey: "value")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Private protocol generates private accessors")
    func testPrivateProtocol() {
        assertMacro {
            """
            @Storage
            private protocol Settings: KeyValueStoring {
                var value: String? { get set }
            }
            """
        } expansion: {
          #"""
          private protocol Settings: KeyValueStoring {
              var value: String? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.value: "value"
              ]
          }

          extension Settings {
              private var value: String? {
                  get {
                      return self.object(forKey: "value") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "value")
                              } else {
                                  self.removeObject(forKey: "value")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Fileprivate protocol generates fileprivate accessors")
    func testFileprivateProtocol() {
        assertMacro {
            """
            @Storage
            fileprivate protocol Settings: KeyValueStoring {
                var value: String? { get set }
            }
            """
        } expansion: {
          #"""
          fileprivate protocol Settings: KeyValueStoring {
              var value: String? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.value: "value"
              ]
          }

          extension Settings {
              fileprivate var value: String? {
                  get {
                      return self.object(forKey: "value") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "value")
                              } else {
                                  self.removeObject(forKey: "value")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Public ObservableKeyValueStoring generates public accessors")
    func testPublicObservableProtocol() {
        assertMacro {
            """
            @Storage
            public protocol Settings: ObservableKeyValueStoring {
                var value: String? { get set }
            }
            """
        } expansion: {
          #"""
          public protocol Settings: ObservableKeyValueStoring {
              var value: String? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.value: "value"
              ]
          }

          extension Settings {
              public var value: String? {
                  get {
                      _setupAutoObservationIfNeeded()
                              return self.object(forKey: "value") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "value")
                              } else {
                                  self.removeObject(forKey: "value")
                              }
                  }
              }
          }

          extension Settings where Self: ObservableKeyValueStoring {
              public var $value: AnyPublisher<String?, Never> {
                  publisher(for: \Settings.value, key: "value")
              }
              public func publisher<Value>(for keyPath: KeyPath<Settings, Value?>) -> AnyPublisher<Value?, Never> {
                  guard let key = SettingsKeyPathMapping.keyPathToStorageKey[keyPath] else {
                      fatalError("Unknown keyPath: \(keyPath)")
                  }
                  return publisher(for: keyPath, key: key)
              }
              private func publisher<Value>(for keyPath: KeyPath<Settings, Value?>, key: String) -> AnyPublisher<Value?, Never> {
                  self.updatesPublisher(forKey: key)
                      .prepend( () )
                      .map {
                          self [keyPath: keyPath]
                      }
                      .eraseToAnyPublisher()
              }
              private var _Settings_observationCancellable: AnyCancellable? {
                  get {
                      guard let userDefaults = self as? UserDefaults else {
                          return nil
                      }
                      let key = unsafeBitCast(Selector(("_Settings_observationCancellable")), to: UnsafeRawPointer.self)
                      return objc_getAssociatedObject(userDefaults, key) as? AnyCancellable
                  }
                  set {
                      guard let userDefaults = self as? UserDefaults else {
                          return
                      }
                      let key = unsafeBitCast(Selector(("_Settings_observationCancellable")), to: UnsafeRawPointer.self)
                      objc_setAssociatedObject(userDefaults, key, newValue, .OBJC_ASSOCIATION_RETAIN)
                  }
              }

          private func _setupAutoObservationIfNeeded() {
              guard let userDefaults = self as? UserDefaults else { return }
              
              if _Settings_observationCancellable != nil {
                  return
              }
              
              // Subscribe to all publishers for keys in this protocol
              let keys = ["value"]
              let publishers = keys.map { userDefaults.updatesPublisher(forKey: $0) }
              
              let cancellable = Publishers.MergeMany(publishers)
                  .sink { [weak userDefaults] _ in
                      userDefaults?.objectWillChange.send()
                  }
              
              _Settings_observationCancellable = cancellable
          }
          }
          """#
        }
    }
    
    @Test("ThrowingValue with @StorageIgnored")
    func testThrowingValueWithIgnored() {
        assertMacro {
            """
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                var stored: ThrowingValue<String> { get }
                
                @StorageIgnored
                func customMethod()
            }
            """
        } expansion: {
          #"""
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var stored: ThrowingValue<String> { get }
              
              func customMethod()
          }

          private enum ThrowingSettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \ThrowingSettings.stored: "stored"
              ]
          }

          extension ThrowingSettings {
              var stored: ThrowingValue<String> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "stored") as? String
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "stored")
                  } else {
                      try self.removeObject(forKey: "stored")
                  }
                          }
                      )
                  }
              }
          }
          """#
        }
    }
    
    // MARK: - Protocol Conformance Validation Tests
    
    @Test("Protocol with AnyObject conformance")
    func testProtocolWithAnyObject() {
        assertMacro {
            """
            @Storage
            protocol Settings: AnyObject, KeyValueStoring {
                var value: String? { get set }
            }
            """
        } expansion: {
          #"""
          protocol Settings: AnyObject, KeyValueStoring {
              var value: String? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.value: "value"
              ]
          }

          extension Settings {
              var value: String? {
                  get {
                      return self.object(forKey: "value") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "value")
                              } else {
                                  self.removeObject(forKey: "value")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Protocol with multiple non-storage conformances")
    func testProtocolWithMultipleConformances() {
        assertMacro {
            """
            protocol CustomProtocol {}
            
            @Storage
            protocol Settings: AnyObject, CustomProtocol, ObservableKeyValueStoring {
                var value: Int? { get set }
            }
            """
        } expansion: {
          #"""
          protocol CustomProtocol {}
          protocol Settings: AnyObject, CustomProtocol, ObservableKeyValueStoring {
              var value: Int? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.value: "value"
              ]
          }

          extension Settings {
              var value: Int? {
                  get {
                      _setupAutoObservationIfNeeded()
                              return self.object(forKey: "value") as? Int
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "value")
                              } else {
                                  self.removeObject(forKey: "value")
                              }
                  }
              }
          }

          extension Settings where Self: ObservableKeyValueStoring {
              var $value: AnyPublisher<Int?, Never> {
                  publisher(for: \Settings.value, key: "value")
              }
              func publisher<Value>(for keyPath: KeyPath<Settings, Value?>) -> AnyPublisher<Value?, Never> {
                  guard let key = SettingsKeyPathMapping.keyPathToStorageKey[keyPath] else {
                      fatalError("Unknown keyPath: \(keyPath)")
                  }
                  return publisher(for: keyPath, key: key)
              }
              private func publisher<Value>(for keyPath: KeyPath<Settings, Value?>, key: String) -> AnyPublisher<Value?, Never> {
                  self.updatesPublisher(forKey: key)
                      .prepend( () )
                      .map {
                          self [keyPath: keyPath]
                      }
                      .eraseToAnyPublisher()
              }
              private var _Settings_observationCancellable: AnyCancellable? {
                  get {
                      guard let userDefaults = self as? UserDefaults else {
                          return nil
                      }
                      let key = unsafeBitCast(Selector(("_Settings_observationCancellable")), to: UnsafeRawPointer.self)
                      return objc_getAssociatedObject(userDefaults, key) as? AnyCancellable
                  }
                  set {
                      guard let userDefaults = self as? UserDefaults else {
                          return
                      }
                      let key = unsafeBitCast(Selector(("_Settings_observationCancellable")), to: UnsafeRawPointer.self)
                      objc_setAssociatedObject(userDefaults, key, newValue, .OBJC_ASSOCIATION_RETAIN)
                  }
              }

          private func _setupAutoObservationIfNeeded() {
              guard let userDefaults = self as? UserDefaults else { return }
              
              if _Settings_observationCancellable != nil {
                  return
              }
              
              // Subscribe to all publishers for keys in this protocol
              let keys = ["value"]
              let publishers = keys.map { userDefaults.updatesPublisher(forKey: $0) }
              
              let cancellable = Publishers.MergeMany(publishers)
                  .sink { [weak userDefaults] _ in
                      userDefaults?.objectWillChange.send()
                  }
              
              _Settings_observationCancellable = cancellable
          }
          }
          """#
        }
    }
    
    @Test("Error: Protocol without any storage conformance")
    func testProtocolWithoutStorageConformance() {
        assertMacro {
            """
            @Storage
            protocol Settings: AnyObject {
                var value: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage requires the protocol to inherit from exactly one of: KeyValueStoring, ThrowingKeyValueStoring, ObservableKeyValueStoring, or ObservableThrowingKeyValueStoring
          protocol Settings: AnyObject {
              var value: String? { get set }
          }
          """
        }
    }
    
    @Test("Error: Protocol with multiple storage conformances - KeyValueStoring + ObservableKeyValueStoring")
    func testProtocolWithMultipleStorageConformances1() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring, ObservableKeyValueStoring {
                var value: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage protocol cannot inherit from multiple storage protocols. Found: KeyValueStoring, ObservableKeyValueStoring. Choose exactly one.
          protocol Settings: KeyValueStoring, ObservableKeyValueStoring {
              var value: String? { get set }
          }
          """
        }
    }
    
    @Test("Error: Protocol with multiple storage conformances - ThrowingKeyValueStoring + ObservableKeyValueStoring")
    func testProtocolWithMultipleStorageConformances2() {
        assertMacro {
            """
            @Storage
            protocol Settings: ThrowingKeyValueStoring, ObservableKeyValueStoring {
                var value: ThrowingValue<String> { get }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage protocol cannot inherit from multiple storage protocols. Found: ThrowingKeyValueStoring, ObservableKeyValueStoring. Choose exactly one.
          protocol Settings: ThrowingKeyValueStoring, ObservableKeyValueStoring {
              var value: ThrowingValue<String> { get }
          }
          """
        }
    }
    
    @Test("Error: Protocol with multiple storage conformances - KeyValueStoring + ThrowingKeyValueStoring")
    func testProtocolWithMultipleStorageConformances3() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring, ThrowingKeyValueStoring {
                var value: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage protocol cannot inherit from multiple storage protocols. Found: KeyValueStoring, ThrowingKeyValueStoring. Choose exactly one.
          protocol Settings: KeyValueStoring, ThrowingKeyValueStoring {
              var value: String? { get set }
          }
          """
        }
    }
    
    @Test("Protocol with Sendable conformance")
    func testProtocolWithSendable() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring, Sendable {
                var value: String? { get set }
            }
            """
        } expansion: {
          #"""
          protocol Settings: KeyValueStoring, Sendable {
              var value: String? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.value: "value"
              ]
          }

          extension Settings {
              var value: String? {
                  get {
                      return self.object(forKey: "value") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "value")
                              } else {
                                  self.removeObject(forKey: "value")
                              }
                  }
              }
          }
          """#
        }
    }
    
    @Test("Protocol with custom protocol before storage protocol")
    func testProtocolWithCustomProtocolFirst() {
        assertMacro {
            """
            protocol Identifiable {
                var id: String { get }
            }
            
            @Storage
            protocol Settings: Identifiable, ObservableKeyValueStoring {
                var username: String? { get set }
            }
            """
        } expansion: {
          #"""
          protocol Identifiable {
              var id: String { get }
          }
          protocol Settings: Identifiable, ObservableKeyValueStoring {
              var username: String? { get set }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.username: "username"
              ]
          }

          extension Settings {
              var username: String? {
                  get {
                      _setupAutoObservationIfNeeded()
                              return self.object(forKey: "username") as? String
                  }
                  set {
                      if let newValue = newValue {
                                  self.set(newValue, forKey: "username")
                              } else {
                                  self.removeObject(forKey: "username")
                              }
                  }
              }
          }

          extension Settings where Self: ObservableKeyValueStoring {
              var $username: AnyPublisher<String?, Never> {
                  publisher(for: \Settings.username, key: "username")
              }
              func publisher<Value>(for keyPath: KeyPath<Settings, Value?>) -> AnyPublisher<Value?, Never> {
                  guard let key = SettingsKeyPathMapping.keyPathToStorageKey[keyPath] else {
                      fatalError("Unknown keyPath: \(keyPath)")
                  }
                  return publisher(for: keyPath, key: key)
              }
              private func publisher<Value>(for keyPath: KeyPath<Settings, Value?>, key: String) -> AnyPublisher<Value?, Never> {
                  self.updatesPublisher(forKey: key)
                      .prepend( () )
                      .map {
                          self [keyPath: keyPath]
                      }
                      .eraseToAnyPublisher()
              }
              private var _Settings_observationCancellable: AnyCancellable? {
                  get {
                      guard let userDefaults = self as? UserDefaults else {
                          return nil
                      }
                      let key = unsafeBitCast(Selector(("_Settings_observationCancellable")), to: UnsafeRawPointer.self)
                      return objc_getAssociatedObject(userDefaults, key) as? AnyCancellable
                  }
                  set {
                      guard let userDefaults = self as? UserDefaults else {
                          return
                      }
                      let key = unsafeBitCast(Selector(("_Settings_observationCancellable")), to: UnsafeRawPointer.self)
                      objc_setAssociatedObject(userDefaults, key, newValue, .OBJC_ASSOCIATION_RETAIN)
                  }
              }

          private func _setupAutoObservationIfNeeded() {
              guard let userDefaults = self as? UserDefaults else { return }
              
              if _Settings_observationCancellable != nil {
                  return
              }
              
              // Subscribe to all publishers for keys in this protocol
              let keys = ["username"]
              let publishers = keys.map { userDefaults.updatesPublisher(forKey: $0) }
              
              let cancellable = Publishers.MergeMany(publishers)
                  .sink { [weak userDefaults] _ in
                      userDefaults?.objectWillChange.send()
                  }
              
              _Settings_observationCancellable = cancellable
          }
          }
          """#
        }
    }
    
    @Test("Error: Protocol without storage protocol conformance")
    func testProtocolNoStorageInheritance() {
        assertMacro {
            """
            @Storage
            protocol Settings {
                var value: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage requires the protocol to inherit from exactly one of: KeyValueStoring, ThrowingKeyValueStoring, ObservableKeyValueStoring, or ObservableThrowingKeyValueStoring
          protocol Settings {
              var value: String? { get set }
          }
          """
        }
    }
    
    @Test("Error: ThrowingValue with get set accessor")
    func testThrowingValueWithGetSet() {
        assertMacro {
            """
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                var username: ThrowingValue<String> { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage with ThrowingValue requires read-only properties. Property 'username' must be declared as '{ get }', not '{ get set }'.
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var username: ThrowingValue<String> { get set }
          }
          """
        }
    }
    
    @Test("Error: ThrowingValue with optional inner type")
    func testThrowingValueOptionalInnerType() {
        assertMacro {
            """
            @Storage
            protocol ThrowingSettings: ThrowingKeyValueStoring {
                var username: ThrowingValue<String?> { get }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage with ThrowingValue requires the inner type to be non-optional. Property 'username' has type 'ThrowingValue<String?>' but should be 'ThrowingValue<String>'.
          protocol ThrowingSettings: ThrowingKeyValueStoring {
              var username: ThrowingValue<String?> { get }
          }
          """
        }
    }
    
    // MARK: - ObservableThrowingKeyValueStoring Tests
    
    @Test("ObservableThrowingKeyValueStoring with ThrowingValue properties")
    func testObservableThrowingKeyValueStoring() {
        assertMacro {
            """
            @Storage
            protocol Settings: ObservableThrowingKeyValueStoring {
                var username: ThrowingValue<String> { get }
                var count: ThrowingValue<Int> { get }
            }
            """
        } expansion: {
          #"""
          protocol Settings: ObservableThrowingKeyValueStoring {
              var username: ThrowingValue<String> { get }
              var count: ThrowingValue<Int> { get }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.username: "username",
                  \Settings.count: "count"
              ]
          }

          extension Settings {
              var username: ThrowingValue<String> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "username") as? String
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "username")
                  } else {
                      try self.removeObject(forKey: "username")
                  }
                          }
                      )
                  }
              }
              var count: ThrowingValue<Int> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "count") as? Int
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "count")
                  } else {
                      try self.removeObject(forKey: "count")
                  }
                          }
                      )
                  }
              }
          }

          extension Settings where Self: ObservableThrowingKeyValueStoring {
              func publisher<Value>(for keyPath: KeyPath<Settings, ThrowingValue<Value>>) -> AnyPublisher<Value?, Never> {
                  guard let key = SettingsKeyPathMapping.keyPathToStorageKey[keyPath] else {
                      fatalError("Unknown keyPath: \(keyPath)")
                  }
                  return publisher(for: keyPath, key: key)
              }
              private func publisher<Value>(for keyPath: KeyPath<Settings, ThrowingValue<Value>>, key: String) -> AnyPublisher<Value?, Never> {
                  self.updatesPublisher(forKey: key)
                      .prepend( () )
                      .map { [weak self] in
                          try? self? [keyPath: keyPath].get()
                      }
                      .eraseToAnyPublisher()
              }
              private var _Settings_observationCancellable: AnyCancellable? {
                  get {
                      guard let userDefaults = self as? UserDefaults else {
                          return nil
                      }
                      let key = unsafeBitCast(Selector(("_Settings_observationCancellable")), to: UnsafeRawPointer.self)
                      return objc_getAssociatedObject(userDefaults, key) as? AnyCancellable
                  }
                  set {
                      guard let userDefaults = self as? UserDefaults else {
                          return
                      }
                      let key = unsafeBitCast(Selector(("_Settings_observationCancellable")), to: UnsafeRawPointer.self)
                      objc_setAssociatedObject(userDefaults, key, newValue, .OBJC_ASSOCIATION_RETAIN)
                  }
              }

          private func _setupAutoObservationIfNeeded() {
              guard let userDefaults = self as? UserDefaults else { return }
              
              if _Settings_observationCancellable != nil {
                  return
              }
              
              // Subscribe to all publishers for keys in this protocol
              let keys = ["username", "count"]
              let publishers = keys.map { userDefaults.updatesPublisher(forKey: $0) }
              
              let cancellable = Publishers.MergeMany(publishers)
                  .sink { [weak userDefaults] _ in
                      userDefaults?.objectWillChange.send()
                  }
              
              _Settings_observationCancellable = cancellable
          }
          }
          """#
        }
    }
    
    @Test("ObservableThrowingKeyValueStoring with custom keys")
    func testObservableThrowingKeyValueStoringWithCustomKeys() {
        assertMacro {
            """
            @Storage
            protocol Settings: ObservableThrowingKeyValueStoring {
                @Key("user_name")
                var username: ThrowingValue<String> { get }
            }
            """
        } expansion: {
          #"""
          protocol Settings: ObservableThrowingKeyValueStoring {
              var username: ThrowingValue<String> { get }
          }

          private enum SettingsKeyPathMapping {
              static let keyPathToStorageKey: [AnyKeyPath: String] = [
                  \Settings.username: "user_name"
              ]
          }

          extension Settings {
              var username: ThrowingValue<String> {
                  get {
                      ThrowingValue(
                          getter: {
                  return try self.object(forKey: "user_name") as? String
                          },
                          setter: { newValue in
                  if let newValue = newValue {
                      try self.set(newValue, forKey: "user_name")
                  } else {
                      try self.removeObject(forKey: "user_name")
                  }
                          }
                      )
                  }
              }
          }

          extension Settings where Self: ObservableThrowingKeyValueStoring {
              func publisher<Value>(for keyPath: KeyPath<Settings, ThrowingValue<Value>>) -> AnyPublisher<Value?, Never> {
                  guard let key = SettingsKeyPathMapping.keyPathToStorageKey[keyPath] else {
                      fatalError("Unknown keyPath: \(keyPath)")
                  }
                  return publisher(for: keyPath, key: key)
              }
              private func publisher<Value>(for keyPath: KeyPath<Settings, ThrowingValue<Value>>, key: String) -> AnyPublisher<Value?, Never> {
                  self.updatesPublisher(forKey: key)
                      .prepend( () )
                      .map { [weak self] in
                          try? self? [keyPath: keyPath].get()
                      }
                      .eraseToAnyPublisher()
              }
              private var _Settings_observationCancellable: AnyCancellable? {
                  get {
                      guard let userDefaults = self as? UserDefaults else {
                          return nil
                      }
                      let key = unsafeBitCast(Selector(("_Settings_observationCancellable")), to: UnsafeRawPointer.self)
                      return objc_getAssociatedObject(userDefaults, key) as? AnyCancellable
                  }
                  set {
                      guard let userDefaults = self as? UserDefaults else {
                          return
                      }
                      let key = unsafeBitCast(Selector(("_Settings_observationCancellable")), to: UnsafeRawPointer.self)
                      objc_setAssociatedObject(userDefaults, key, newValue, .OBJC_ASSOCIATION_RETAIN)
                  }
              }

          private func _setupAutoObservationIfNeeded() {
              guard let userDefaults = self as? UserDefaults else { return }
              
              if _Settings_observationCancellable != nil {
                  return
              }
              
              // Subscribe to all publishers for keys in this protocol
              let keys = ["user_name"]
              let publishers = keys.map { userDefaults.updatesPublisher(forKey: $0) }
              
              let cancellable = Publishers.MergeMany(publishers)
                  .sink { [weak userDefaults] _ in
                      userDefaults?.objectWillChange.send()
                  }
              
              _Settings_observationCancellable = cancellable
          }
          }
          """#
        }
    }
    
    @Test("Error: ObservableThrowingKeyValueStoring requires ThrowingValue")
    func testObservableThrowingKeyValueStoringRequiresThrowingValue() {
        assertMacro {
            """
            @Storage
            protocol Settings: ObservableThrowingKeyValueStoring {
                var value: String? { get set }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage with ThrowingKeyValueStoring requires properties to use ThrowingValue<T> or ThrowingGetter<T>. Property 'value' has type 'String?'. Use 'var value: ThrowingValue<String> { get }' for read-write or 'var value: ThrowingGetter<String> { get }' for read-only.
          protocol Settings: ObservableThrowingKeyValueStoring {
              var value: String? { get set }
          }
          """
        }
    }
    
    @Test("Error: ThrowingValue used with non-throwing protocol")
    func testThrowingValueWithNonThrowingProtocol() {
        assertMacro {
            """
            @Storage
            protocol Settings: KeyValueStoring {
                var value: ThrowingValue<String> { get }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage property 'value' uses ThrowingValue<T> but the protocol 'Settings' does not conform to ThrowingKeyValueStoring or ObservableThrowingKeyValueStoring. Either change the property to a regular optional type or make the protocol conform to a throwing protocol.
          protocol Settings: KeyValueStoring {
              var value: ThrowingValue<String> { get }
          }
          """
        }
    }
    
    @Test("Error: ThrowingValue used with ObservableKeyValueStoring")
    func testThrowingValueWithObservableKeyValueStoring() {
        assertMacro {
            """
            @Storage
            protocol Settings: ObservableKeyValueStoring {
                var value: ThrowingValue<Int> { get }
            }
            """
        } diagnostics: {
          """
          @Storage
          ┬───────
          ╰─ 🛑 @Storage property 'value' uses ThrowingValue<T> but the protocol 'Settings' does not conform to ThrowingKeyValueStoring or ObservableThrowingKeyValueStoring. Either change the property to a regular optional type or make the protocol conform to a throwing protocol.
          protocol Settings: ObservableKeyValueStoring {
              var value: ThrowingValue<Int> { get }
          }
          """
        }
    }
}

