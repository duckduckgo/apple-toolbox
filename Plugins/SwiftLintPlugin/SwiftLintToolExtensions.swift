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
import XcodeEditor

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

    init(_ type: XcodeSourceFileType) {
        self = switch type {
        case .Framework: .unknown
        case .PropertyList: .resource
        case .SourceCodeHeader: .header
        case .SourceCodeObjC: .source
        case .SourceCodeObjCPlusPlus: .source
        case .SourceCodeCPlusPlus: .source
        case .XibFile: .resource
        case .ImageResourcePNG: .resource
        case .Bundle: .resource
        case .Archive: .resource
        case .HTML: .resource
        case .TEXT: .resource
        case .XcodeProject: .unknown
        case .Folder: .unknown
        case .AssetCatalog: .resource
        case .SourceCodeSwift: .source
        case .Application: .unknown
        case .Playground: .unknown
        case .ShellScript: .unknown
        case .Markdown: .resource
        case .XMLPropertyList: .resource
        case .Storyboard: .resource
        case .XCConfig: .unknown
        case .XCDataModel: .resource
        case .LocalizableStrings: .resource
        default: .unknown
        }
    }
}

protocol File {
    var path: Path { get }
    var type: FileType { get }
}

/// More effective XCSourceFile path construction with file.key->parent-group map
class XCProjectWithCachedGroups: XCProject {

    private var _groupsByMemberKey: [String: XCGroup]?
    var groupsByMemberKey: [String: XCGroup] {
        if let _groupsByMemberKey { return _groupsByMemberKey }

        var groupsByMemberKey = [String: XCGroup]()
        for group in groups() ?? [] {
            for key in group.children {
                groupsByMemberKey[key as! String] = group
            }
        }
        _groupsByMemberKey = groupsByMemberKey
        return groupsByMemberKey
    }

    override func groupForGroupMember(withKey key: String!) -> XCGroup! {
        return groupsByMemberKey[key]
    }

}

/// Maps XcodeEditor XCSourceFile to Build Plugin File
extension XCSourceFile: File {

    var path: Path {
        let path = if let name, name.contains("/") {
            Path(name)
        } else {
            Path(pathRelativeToProjectRoot() ?? value(forKey: "_path") as? String ?? name)
        }
        return path.isAbsolute ? path : pluginContext.xcodeProject.directory.appending(path)
    }

    var type: FileType {
        FileType(XcodeSourceFileType(rawValue: (value(forKey: "_type") as! NSNumber).intValue))
    }

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

/// Maps XcodeEditor XCTarget to Build Plugin XcodeTarget
extension XCTarget: XcodeTarget {

    var displayName: String {
        name
    }

    var kind: TargetKind {
        TargetKind(productType: productType)
    }

    var sourceFiles: [XCSourceFile] {
        members().compactMap { $0 as? XCSourceFile }
    }

    var inputFiles: [File] {
        sourceFiles as [File]
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

    init(path: Path, type: FileType) {
        self.path = path
        self.type = type
    }

    init(sourceFile: XCSourceFile) {
        self.init(path: sourceFile.path, type: sourceFile.type)
    }
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
            try! FileManager.default.createDirectory(atPath: path.string, withIntermediateDirectories: false)
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

        let swiftlintFolder = try! fm.contentsOfDirectory(atPath: path.string).first(where: {
            var isFolder: ObjCBool = false
            return $0.hasPrefix("swiftlint") && fm.fileExists(atPath: path.appending(subpath: $0).string, isDirectory: &isFolder) && isFolder.boolValue
        })!
        path = path.appending([swiftlintFolder, "bin", "swiftlint"])

        return Tool(path: path)
    }

}
typealias XcodePluginContext = PluginContext

let pluginContext = PluginContext()

extension Process {

    convenience init(_ command: String, _ args: [String], workDirectory: URL? = nil) {
        self.init()
        self.executableURL = URL(fileURLWithPath: command)
        self.arguments = args
        if let workDirectory = workDirectory {
            self.currentDirectoryURL = workDirectory
        }
    }

}

#endif
