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

/// Compile-time validated OS version independent URL instantiation from String Literal.
///
/// Used to statically validate preset URLs.
/// The idea is to disable any flaky URL conversions like punycode or no-scheme urls, only 1-1 mapped String Literals can be used.
///
/// Usage: `let url = #URL("https://duckduckgo.com")`
///
/// - Note: Strings like "http://💩.la" or "1" are not valid #URL parameter values.
/// To instantiate a parametrized URL use `URL.appendingPathComponent(_:)` or `URL.appendingParameters(_:allowedReservedCharacters:)`
/// To instantiate a URL from a String format, use `URL(string:)`
///
/// - Parameter string: valid URL String Literal with URL scheme and
/// - Returns: URL instance if provided string argument is a valid URL
/// - Throws: Compile-time error if provided string argument is not a valid URL
///
@freestanding(expression)
public macro URL(_ string: StaticString) -> URL = #externalMacro(module: "MacrosImplementation", type: "URLMacro")
