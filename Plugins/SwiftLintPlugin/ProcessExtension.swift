//
//  ProcessExtension.swift
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

// Contains extensions for standalone swiftlint tool to run build system plugin code
#if !canImport(PackagePlugin)

extension Process {

    convenience init(_ command: String, _ args: [String], workDirectory: Path? = nil) {
        self.init()
        self.executableURL = URL(fileURLWithPath: command)
        self.arguments = args
        if let workDirectory = workDirectory {
            self.currentDirectoryURL = workDirectory.url
        }
    }

    func executeCommand() throws -> String {
        let pipe = Pipe()
        self.standardOutput = pipe
        try self.run()

        let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
        guard let output = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadUnknownStringEncoding, userInfo: [NSLocalizedDescriptionKey: "could not decode data \(data.base64EncodedString())"])
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func which(_ commandName: String) -> Process {
        Process("/usr/bin/which", [commandName])
    }

}

#endif
