//
//  PathExtension.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

#if canImport(PackagePlugin)
import PackagePlugin
#else
public struct Path: Hashable {

    let string: String

    var stringValue: String { string }

    init(_ string: String) {
        self.string = string
    }

    /// The last path component (without any extension).
    public var stem: String {
        let filename = self.lastComponent
        if let ext = self.extension {
            return String(filename.dropLast(ext.count + 1))
        } else {
            return filename
        }
    }

    var lastComponent: String {
        (string as NSString).lastPathComponent
    }

    var `extension`: String? {
        let ext = (string as NSString).pathExtension
        if ext.isEmpty { return nil }
        return ext
    }

    func removingLastComponent() -> Path {
        Path((string as NSString).deletingLastPathComponent)
    }

    func appending(subpath: String) -> Path {
        return Path(string + (string.hasSuffix("/") ? "" : "/") + subpath)
    }

    func appending(_ components: [String]) -> Path {
        return self.appending(subpath: components.joined(separator: "/"))
    }

    func appending(_ components: String...) -> Path {
        return self.appending(components)
    }

    func appending(_ path: Path) -> Path {
        return appending(subpath: path.string)
    }

}

extension Path: CustomStringConvertible {

    @available(_PackageDescription, deprecated: 6.0)
    public var description: String {
        return self.string
    }
}

extension Path: Codable {

    @available(_PackageDescription, deprecated: 6.0)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.string)
    }

    @available(_PackageDescription, deprecated: 6.0)
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self.init(string)
    }
}

public extension String.StringInterpolation {

    @available(_PackageDescription, deprecated: 6.0)
    mutating func appendInterpolation(_ path: Path) {
        self.appendInterpolation(path.string)
    }
}
#endif

extension Path {

    static let mv = Path("/bin/mv")
    static let echo = Path("/bin/echo")
    static let cat = Path("/bin/cat")
    static let sh = Path("/bin/sh")

    private static let swiftlintConfig = ".swiftlint.yml"

    /// Scans the receiver, then all of its parents looking for a configuration file with the name ".swiftlint.yml".
    ///
    /// - returns: Path to the configuration file, or nil if one cannot be found.
    func firstParentContainingConfigFile() -> Path? {
        let proposedDirectory = sequence(
            first: self,
            next: { path in
                guard path.stem.count > 1 else {
                    // Check we're not at the root of this filesystem, as `removingLastComponent()`
                    // will continually return the root from itself.
                    return nil
                }

                return path.removingLastComponent()
            }
        ).first { path in
            let potentialConfigurationFile = path.appending(subpath: Self.swiftlintConfig)
            return potentialConfigurationFile.isAccessible()
        }
        return proposedDirectory
    }

    /// Safe way to check if the file is accessible from within the current process sandbox.
    private func isAccessible() -> Bool {
        let result = string.withCString { pointer in
            access(pointer, R_OK)
        }

        return result == 0
    }

    /// Get file modification date
    var modified: Date {
        get throws {
            try FileManager.default.attributesOfItem(atPath: self.string)[.modificationDate] as? Date ?? { throw CocoaError(.fileReadUnknown) }()
        }
    }

    var url: URL {
        URL(fileURLWithPath: self.string)
    }

    var isAbsolute: Bool {
        string.hasPrefix("/")
    }

    var exists: Bool {
        return FileManager.default.fileExists(atPath: string)
    }

    var isDirectory: Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: string, isDirectory: &isDirectory) else { return false }
        return isDirectory.boolValue
    }

    func getDirectoryContents(filter: (Path) throws -> Bool = { _ in true }) rethrows -> [Path] {
        var files: [Path] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(atPath: self.string) else { return files }

        for case let file as String in enumerator where try filter(Path(file)) {
            files.append(Path(file))
        }

        return files
    }

}
