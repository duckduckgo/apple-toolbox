//
//  XCProject.swift
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

final class XCProject {

    enum XCObjectType: String {
        case group = "PBXGroup"
        case variantGroup = "PBXVariantGroup"
        case fileReference = "PBXFileReference"
    }

    struct XCObject {
        let isa: XCObjectType
        let key: String
        let name: String

        fileprivate weak var project: XCProject?
    }

    enum DecodingError: Error {
        case noObjects
    }

    private(set) var objects = [String: XCObject]()
    private(set) var parents = [String /* child key */: String /* parent key */]()
    private var pathCache = [String: Path]()

    init(path: Path) throws {
        let dataStore = try NSDictionary(contentsOf: pluginContext.xcodeProject.filePath.appending("project.pbxproj").url, error: ())
        let projectObjects = try dataStore["objects"] as? [String: Any] ?? { throw DecodingError.noObjects }()

        for (key, obj) in projectObjects {
            guard let obj = obj as? [String: Any],
                  let isa = obj["isa"] as? String,
                  let objectType = XCObjectType(rawValue: isa),
                  [.group, .variantGroup, .fileReference].contains(objectType),
                  let path = obj["path"] as? String else { continue }

            let object = XCObject(isa: objectType, key: key, name: path, project: self)
            objects[key] = object

            if let children = obj["children"] as? [String] {
                for child in children {
                    parents[child] = key
                }
            }
        }
    }

}
extension XCProject.XCObject {

    func pathRelativeToProjectRoot() -> Path {
        if let path = project?.pathCache[key] { return path }
        var path = Path(name)

        var key = self.key
        while let parentKey = project?.parents[key],
              let parentGroup = project?.objects[parentKey] {
            let pathRelativeToParent = Path(parentGroup.name)
            path = pathRelativeToParent.appending(path)
            key = parentKey
        }

        project?.pathCache[self.key] = path
        return path
    }

    var path: Path {
        let path = if name.contains("/") {
            Path(name)
        } else {
            pathRelativeToProjectRoot()
        }
        return path.isAbsolute ? path : pluginContext.xcodeProject.directory.appending(path)
    }

}
