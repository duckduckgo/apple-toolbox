//
//  SwiftLintPlugin.swift
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
// Swift Package Plugin or Xcode Build Plugin
import PackagePlugin

extension SwiftLintPlugin: BuildToolPlugin {}

#if canImport(XcodeProjectPlugin)
// Xcode Build Plugin
import XcodeProjectPlugin
extension SwiftLintPlugin: XcodeBuildToolPlugin {}
#endif

#else

// Standalone tool
import ArgumentParser

extension SwiftLintPlugin: ParsableCommand {}
#endif

@main
struct SwiftLintPlugin {

    // swiftlint:disable function_body_length
    private func createBuildCommands(
        target: String,
        inputFiles: [Path],
        packageDirectory: Path,
        workingDirectory: Path,
        tool: (String) throws -> PluginContext.Tool
    ) throws -> [Command] {

        // only lint when built from Xcode (disable for CI or xcodebuild)
        guard case .xcode = ProcessInfo().environmentType else { return [] }

        let fm = FileManager()

        let cacheURL = URL(fileURLWithPath: workingDirectory.appending("cache.json").string)
        let outputPath = workingDirectory.appending("output.txt").string

#if canImport(PackagePlugin)
        let buildDir = workingDirectory.removingLastComponent() // BrowserServicesKit
            .removingLastComponent() // browserserviceskit.output
            .removingLastComponent() // plugins
            .removingLastComponent() // SourcePackages
            .removingLastComponent() // DerivedData/DuckDuckGo-xxxx
            .appending("Build")
#else
        let buildDir = pluginContext.buildRoot.removingLastComponent()
#endif
        // if clean build: clear cache
        if let buildDirContents = try? fm.contentsOfDirectory(atPath: buildDir.string),
           !buildDirContents.contains("Products") {
            print("SwiftLintPlugin: \(target): Clean Build")

            try? fm.removeItem(at: cacheURL)
            try? fm.removeItem(atPath: outputPath)
        }

        // read cached data
        var cache = (try? JSONDecoder().decode([String: InputListItem].self, from: Data(contentsOf: cacheURL))) ?? [:]
        // read diagnostics from last pass
        let lastOutput = cache.isEmpty ? "" : (try? String(contentsOfFile: outputPath)) ?? {
            // no diagnostics file – reset
            cache = [:]
            return ""
        }()

        // analyze new/modified files and output cached diagnostics for non-modified files
        var filesToProcess = Set<String>()
        var newCache = [String: InputListItem]()
        for inputFile in inputFiles {
            try autoreleasepool {

                let modified = try inputFile.modified
                if let cacheItem = cache[inputFile.string], modified == cacheItem.modified {
                    // file not modified
                    newCache[inputFile.string] = cacheItem
                    return
                }

                // updated modification date in cache and re-process
                newCache[inputFile.string] = .init(modified: modified)

                filesToProcess.insert(inputFile.string)
            }
        }

        // merge diagnostics from last linter pass into cache
        for outputLine in lastOutput.split(separator: "\n") {
            guard let filePath = outputLine.split(separator: ":", maxSplits: 1).first.map(String.init),
                  !filesToProcess.contains(filePath) else { continue }

            newCache[filePath]?.appendDiagnosticsMessage(String(outputLine))
        }

        // collect cached diagnostic messages from cache
        let cachedDiagnostics = newCache.values.reduce(into: [String]()) {
            $0 += $1.diagnostics ?? []
        }

        // We are not producing output files and this is needed only to not include cache files into bundle
        let outputFilesDirectory = workingDirectory.appending("Output")
        try? fm.createDirectory(at: outputFilesDirectory.url, withIntermediateDirectories: true)
        try? fm.removeItem(at: cacheURL.appendingPathExtension("tmp"))
        try? fm.removeItem(atPath: outputPath + ".tmp")

        var result = [Command]()
        if !filesToProcess.isEmpty {
            print("SwiftLintPlugin: \(target): Processing \(filesToProcess.count) files")

            // write updated cache into temporary file, cache file will be overwritten when linting completes
            try JSONEncoder().encode(newCache).write(to: cacheURL.appendingPathExtension("tmp"))

            let swiftlint = try tool("swiftlint").path
            let fileNames = filesToProcess.map { Path($0).lastComponent }.joined(separator: " ")
            let files = filesToProcess.map { "\"\($0)\"" }.joined(separator: " ")

            let fixCommand = """
            cd "\(packageDirectory)" && \
            "\(swiftlint)" --fix --quiet --cache-path "\(workingDirectory)" \(files)
            """

            let lintCommand = """
            cd "\(packageDirectory)" && \
            "\(swiftlint)" --quiet --force-exclude --reporter xcode --cache-path "\(workingDirectory)" \(files) \
                | tee -a "\(outputPath).tmp"
            """

            result = [
                .prebuildCommand(
                    displayName: "swiftlint --fix \(fileNames)",
                    executable: .sh,
                    arguments: ["-c", fixCommand],
                    outputFilesDirectory: outputFilesDirectory
                ),
                .prebuildCommand(
                    displayName: "swiftlint lint \(fileNames)",
                    executable: .sh,
                    arguments: ["-c", lintCommand],
                    outputFilesDirectory: outputFilesDirectory
                )
            ]

        } else {
            print("🤷‍♂️ SwiftLintPlugin: \(target): No new files to process")
            try JSONEncoder().encode(newCache).write(to: cacheURL)
            try "".write(toFile: outputPath, atomically: false, encoding: .utf8)
        }

        // output cached diagnostic messages from previous run
        result.append(.prebuildCommand(
            displayName: "SwiftLintPlugin: \(target): cached \(cacheURL.path)",
            executable: .echo,
            arguments: [cachedDiagnostics.joined(separator: "\n")],
            outputFilesDirectory: outputFilesDirectory
        ))

        if !filesToProcess.isEmpty {
            // when ready put temporary cache and output into place
            result.append(.prebuildCommand(
                displayName: "SwiftLintPlugin: \(target): Caching results",
                executable: .mv,
                arguments: ["\(outputPath).tmp", outputPath],
                outputFilesDirectory: outputFilesDirectory
            ))
            result.append(.prebuildCommand(
                displayName: "SwiftLintPlugin: \(target): Cache source files modification dates",
                executable: .mv,
                arguments: [cacheURL.appendingPathExtension("tmp").path, cacheURL.path],
                outputFilesDirectory: outputFilesDirectory
            ))
        }

        return result
    }
    // swiftlint:enable function_body_length

    // MARK: - Standalone tool Main
#if !canImport(PackagePlugin)

    private func getModifiedFiles(at path: Path) throws -> [Path] {
        // path to `git`
        let git = try {
            let cacheURL = pluginContext.pluginWorkDirectory.appending("git").url
            if let cached = try? String(contentsOf: cacheURL) { return cached }
            let whichGit = Process.which("git")
            print("no chached git, running `\(whichGit.executableURL!.path) git`")
            let git = try whichGit.executeCommand()
            try? git.write(to: cacheURL, atomically: false, encoding: .utf8)
            return git
        }()

        print("Running \(git) diff at \(path)")
        let output = try Process(git, ["diff", "HEAD", "--name-only"], workDirectory: path).executeCommand().components(separatedBy: "\n")
        // append non-tracked files
        + Process(git, ["ls-files", "--others", "--exclude-standard"], workDirectory: path).executeCommand().components(separatedBy: "\n")

        return output.compactMap {
            guard !$0.isEmpty else { return nil }
            let absolutePath = path.appending(subpath: $0)
            guard absolutePath.isExistingFile else { return nil }
            return absolutePath
        }
    }

    mutating func run() throws {
        let target: XcodeTarget
        let start = Date()

        let gitRootFolders: [Path] = try {
            struct ProjectCache: Codable {
                let projectModified: Date
                let gitRootFolders: [Path]
            }
            // try loading list of .git root folders from cache if pbxproj is not modified
            let cacheURL = URL(fileURLWithPath: pluginContext.pluginWorkDirectory.appending("project_cache.json").string)

            let projectModified = try pluginContext.xcodeProject.filePath.appending("project.pbxproj").modified
            if let cache = (try? JSONDecoder().decode(ProjectCache.self, from: Data(contentsOf: cacheURL))),
               cache.projectModified == projectModified {
                return cache.gitRootFolders
            }

            // load xc project
            let project = try XCProject(path: pluginContext.xcodeProject.filePath)

            // get all folders with `.git` subfolder (like BrowserServicesKit) from xc project build files
            let gitRootFolders: [Path] = project.objects.values.compactMap { obj -> Path? in
                guard obj.isa == .fileReference else { return nil }
                let path = obj.path
                guard path.isDirectory && path.appending(subpath: ".git").exists else { return nil }
                return path
            } + [pluginContext.repoRoot!] // and project root itself

            // cache
            let cache = ProjectCache(projectModified: projectModified, gitRootFolders: gitRootFolders)
            try JSONEncoder().encode(cache).write(to: cacheURL)

            return gitRootFolders
        }()

        // get all modified files
        var buildFiles = Set<BuildFile>()
        for gitRootFolder in gitRootFolders {
            let modifiedFiles = try getModifiedFiles(at: gitRootFolder)
            buildFiles.formUnion(modifiedFiles.map { BuildFile(path: $0, type: .source) })
        }

        target = FakeTarget(displayName: "Target", files: buildFiles)
        let time = Date().timeIntervalSince(start)
        print("⏰ parsing took \(String(format: "%.2f", time))s.")

        let commands = try createBuildCommands(context: pluginContext, target: target)

        for command in commands {
            switch command {
            case .prebuildCommand(displayName: let name, executable: let path, arguments: let args, outputFilesDirectory: _):
                print("Running \(name)")
                let process = Process(path.string, args)
                try process.run()
                process.waitUntilExit()
            }
        }
    }
#endif

}

// MARK: - Swift Package Plugin
#if canImport(PackagePlugin)
extension SwiftLintPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // disable output for SPM modules built in RELEASE mode
        guard let target = target as? SourceModuleTarget else {
            assertionFailure("invalid target")
            return []
        }

        guard (target as? SwiftSourceModuleTarget)?.compilationConditions.contains(.debug) != false || target.kind == .test else {
            print("SwiftLintPlugin: \(target.name): Skipping for RELEASE build")
            return []
        }

        let inputFiles = target.sourceFiles(withSuffix: "swift").map(\.path)
        guard !inputFiles.isEmpty else {
            print("SwiftLintPlugin: \(target.name): No input files")
            return []
        }

        return try createBuildCommands(
            target: target.name,
            inputFiles: inputFiles,
            packageDirectory: context.package.directory.firstParentContainingConfigFile() ?? context.package.directory,
            workingDirectory: context.pluginWorkDirectory,
            tool: context.tool(named:)
        )
    }
}
#endif

// MARK: - Xcode Build Plugin and standalone tool launcher
#if canImport(XcodeProjectPlugin) || !canImport(PackagePlugin)
extension SwiftLintPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let inputFiles = target.inputFiles.filter {
            $0.type == .source && $0.path.extension == "swift"
        }.map(\.path)

        guard !inputFiles.isEmpty else {
            print("SwiftLintPlugin: \(target): No input files")
            return []
        }

        return try createBuildCommands(
            target: target.displayName,
            inputFiles: inputFiles,
            packageDirectory: context.xcodeProject.directory,
            workingDirectory: context.pluginWorkDirectory,
            tool: context.tool(named:)
        )
    }
}

#endif

extension String {
    static let swiftlintConfigFileName = ".swiftlint.yml"

    static let debug = "DEBUG"
}
