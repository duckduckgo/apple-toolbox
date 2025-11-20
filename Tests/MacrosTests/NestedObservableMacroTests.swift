//
//  NestedObservableMacroTests.swift
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
        "NestedObservable": NestedObservableMacro.self,
    ],
    record: .missing
  )
)
struct NestedObservableMacroTests {
    
    @Test("Basic nested observable property")
    func testBasicNestedObservableProperty() {
        assertMacro {
            """
            final class ParentModel: ObservableObject {
                @NestedObservable var child: ChildModel = ChildModel()
            }
            """
        } expansion: {
            """
            final class ParentModel: ObservableObject {
                var child: ChildModel = ChildModel() {
                    get {
                        if _childCancellable == nil {
                            _childCancellable = _child.objectWillChange.sink { [weak self] _ in
                                self?.objectWillChange.send()
                            }
                        }
                        return _child
                    }
                    set {
                        _childCancellable?.cancel()
                        _child = newValue
                        _childCancellable = _child.objectWillChange.sink { [weak self] _ in
                            self?.objectWillChange.send()
                        }
                        objectWillChange.send()
                    }
                }

                private var _child: ChildModel = ChildModel()

                private var _childCancellable: AnyCancellable?
            }
            """
        }
    }
    
    @Test("Nested observable without initial value")
    func testNestedObservableWithoutInitialValue() {
        assertMacro {
            """
            final class ParentModel: ObservableObject {
                @NestedObservable var child: ChildModel
            }
            """
        } expansion: {
            """
            final class ParentModel: ObservableObject {
                var child: ChildModel {
                    get {
                        if _childCancellable == nil {
                            _childCancellable = _child.objectWillChange.sink { [weak self] _ in
                                self?.objectWillChange.send()
                            }
                        }
                        return _child
                    }
                    set {
                        _childCancellable?.cancel()
                        _child = newValue
                        _childCancellable = _child.objectWillChange.sink { [weak self] _ in
                            self?.objectWillChange.send()
                        }
                        objectWillChange.send()
                    }
                }

                private var _child: ChildModel

                private var _childCancellable: AnyCancellable?
            }
            """
        }
    }
    
    @Test("Multiple nested observable properties")
    func testMultipleNestedObservableProperties() {
        assertMacro {
            """
            final class ParentModel: ObservableObject {
                @NestedObservable var child1: ChildModel = ChildModel()
                @NestedObservable var child2: OtherModel = OtherModel()
            }
            """
        } expansion: {
            """
            final class ParentModel: ObservableObject {
                var child1: ChildModel = ChildModel() {
                    get {
                        if _child1Cancellable == nil {
                            _child1Cancellable = _child1.objectWillChange.sink { [weak self] _ in
                                self?.objectWillChange.send()
                            }
                        }
                        return _child1
                    }
                    set {
                        _child1Cancellable?.cancel()
                        _child1 = newValue
                        _child1Cancellable = _child1.objectWillChange.sink { [weak self] _ in
                            self?.objectWillChange.send()
                        }
                        objectWillChange.send()
                    }
                }

                private var _child1: ChildModel = ChildModel()

                private var _child1Cancellable: AnyCancellable?
                var child2: OtherModel = OtherModel() {
                    get {
                        if _child2Cancellable == nil {
                            _child2Cancellable = _child2.objectWillChange.sink { [weak self] _ in
                                self?.objectWillChange.send()
                            }
                        }
                        return _child2
                    }
                    set {
                        _child2Cancellable?.cancel()
                        _child2 = newValue
                        _child2Cancellable = _child2.objectWillChange.sink { [weak self] _ in
                            self?.objectWillChange.send()
                        }
                        objectWillChange.send()
                    }
                }

                private var _child2: OtherModel = OtherModel()

                private var _child2Cancellable: AnyCancellable?
            }
            """
        }
    }
    
    @Test("Error on computed property")
    func testErrorOnComputedProperty() {
        assertMacro {
            """
            final class ParentModel: ObservableObject {
                @NestedObservable var child: ChildModel {
                    return ChildModel()
                }
            }
            """
        } diagnostics: {
            """
            final class ParentModel: ObservableObject {
                @NestedObservable var child: ChildModel {
                ┬────────────────
                ╰─ 🛑 @NestedObservable cannot be applied to computed properties
                    return ChildModel()
                }
            }
            """
        }
    }
    
    @Test("Error without type annotation")
    func testErrorWithoutTypeAnnotation() {
        assertMacro {
            """
            final class ParentModel: ObservableObject {
                @NestedObservable var child = ChildModel()
            }
            """
        } diagnostics: {
            """
            final class ParentModel: ObservableObject {
                @NestedObservable var child = ChildModel()
                ┬────────────────
                ╰─ 🛑 @NestedObservable can only be applied to variable declarations with explicit type annotations
            }
            """
        }
    }
}

