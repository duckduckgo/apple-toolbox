//
//  SwiftLintToolExtensions.swift
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

// Contains extensions for standalone swiftlint tool to run build system plugin code
#if !canImport(PackagePlugin)

import Foundation

/// Maps XcodeEditor productType to Build Plugin FileType
enum TargetKind: String {
    case test
    case main

    init(productType: String) {
        if productType.hasSuffix("test") || productType.hasSuffix("testing") {
            self = .test
        } else {
            self = .main
        }
    }

}

/// Maps XcodeEditor XcodeSourceFileType to Build Plugin FileType
public enum FileType: Equatable {
    case source
    case header
    case resource
    case unknown
}

protocol File {
    var path: Path { get }
    var type: FileType { get }
}

protocol XcodeTarget {
    var displayName: String { get }

    var kind: TargetKind { get }
    var inputFiles: [File] { get }
    func sourceFiles(withSuffix suffix: String) -> [File]
}

extension XcodeTarget {
    func sourceFiles(withSuffix suffix: String) -> [File] {
        inputFiles.filter {
            $0.path.string.hasSuffix(suffix)
        }
    }
}

struct FakeTarget: XcodeTarget {
    var displayName: String
    var kind: TargetKind = .main
    var files: Set<BuildFile> = []
    var inputFiles: [File] {
        Array(files)
    }
}

struct BuildFile: Hashable, File {
    var path: Path
    var type: FileType
}

enum Command {
    case prebuildCommand(
        displayName: String,
        executable: Path,
        arguments: [String],
        outputFilesDirectory: Path
    )
}

struct Project {
    var filePath: Path
    var directory: Path
}

struct PluginContext {

    struct Tool {
        var path: Path
    }

    let processInfo: ProcessInfo = ProcessInfo()

    let xcodeProject: Project

    var workspaceDir: Path? {
        processInfo.environment["WORKSPACE_DIR"].map(Path.init)
    }

    var srcRoot: Path? {
        processInfo.environment["SRCROOT"].map(Path.init)
    }

    var repoRoot: Path? {
        for case .some(let dir) in [workspaceDir, srcRoot, pluginContext.xcodeProject.directory] where dir.appending(subpath: ".git").exists {
            return dir
        }
        return nil
    }

    var buildRoot: Path {
        Path(processInfo.environment["BUILD_ROOT"]!)
    }
    var derivedData: Path {
        buildRoot.removingLastComponent().removingLastComponent()
    }
    var packageArtifacts: Path {
        derivedData.appending(["SourcePackages", "artifacts"])
    }

    var pluginWorkDirectory: Path {
        let path = Path(ProcessInfo().arguments[0] + "_files")
        if !FileManager.default.fileExists(atPath: path.string) {
            try! FileManager.default.createDirectory(atPath: path.string, withIntermediateDirectories: false) // swiftlint:disable:this force_try
        }
        return path
    }

    init() {
        xcodeProject = Project(filePath: Path(processInfo.environment["PROJECT_FILE_PATH"]!),
                               directory: Path(processInfo.environment["PROJECT_DIR"]!))
    }

    func tool(named name: String) -> Tool {
        // SourcePackages/artifacts/apple-toolbox/SwiftLintBinary/SwiftLintBinary.artifactbundle/swiftlint-0.54.0-macos/bin/swiftlint
        guard name == "swiftlint" else {
            fatalError("Unknown tool: `\(name)`")
        }
        var path = packageArtifacts.appending(["apple-toolbox", "SwiftLintBinary", "SwiftLintBinary.artifactbundle"])
        let fm = FileManager.default

        // swiftlint:disable:next force_try
        let swiftlintFolder = try! fm.contentsOfDirectory(atPath: path.string).first(where: {
            var isFolder: ObjCBool = false
            return $0.hasPrefix("swiftlint") && $0.hasSuffix("macos") && fm.fileExists(atPath: path.appending(subpath: $0).string, isDirectory: &isFolder) && isFolder.boolValue
        })!
        path = path.appending([swiftlintFolder, "bin", "swiftlint"])

        return Tool(path: path)
    }

}
typealias XcodePluginContext = PluginContext

let pluginContext = PluginContext()

#endif
