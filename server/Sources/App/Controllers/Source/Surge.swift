//
//  Surge.swift
//  SSTest
//
//  Created by Kael Yang on 26/8/2020.
//  Copyright © 2020 Kael Yang. All rights reserved.
//

import Foundation

public enum Surge { }

extension Surge {
    static func generate(with groupModifiers: [GroupModifier], resources: Surge.GroupModifier.Resources, skipNormalProxy: Bool) -> String {

        // 1. flat all resource modifiers.
        let flattedGroupModifiers: [GroupModifier] = groupModifiers.map { groupModifier in
            let flatResult = groupModifier.flat(withResources: resources, skipNormalProxy: skipNormalProxy)

            switch flatResult {
            case .success(let flattedModifier):
                return flattedModifier
            case .failure(let resourceError):
                var fallbackModifier = GroupModifier(groupName: groupModifier.groupName)
                fallbackModifier.modificationType = .modify
                fallbackModifier.add(insertedModifier: GroupModifier.Modifier.plain("# Group \(groupModifier.name ?? groupModifier.groupName) is removed since resource \(resourceError.url.absoluteString) is not downloaded."))
                return fallbackModifier
            }
        }

        // 2. filter optional modifiers. (required modifier not found)
        let filtedGroupModifiers = flattedGroupModifiers.filter { modifier -> Bool in
            let requiredModifiers = modifier.requiredModifierNames
            return requiredModifiers.allSatisfy { name -> Bool in
                flattedGroupModifiers.contains(where: { $0.name == name })
            }
        }

        typealias GroupName = String

        var sortedGroupNames: [String] = []
        var groups: [GroupName: [GroupModifier.Modifier]] = [:]
        var update: [(GroupName, [GroupModifier.Updator])] = []

        // 3. Merge all modify and replace group's modifiers.
        filtedGroupModifiers.forEach { groupModifier in
            if !groupModifier.updators.isEmpty {
                update.append((groupModifier.groupName, groupModifier.updators))
            }
            switch groupModifier.modificationType {
            case .modify:
                if var modifiers = groups[groupModifier.groupName] {
                    modifiers.insert(contentsOf: groupModifier.insertedModifiers, at: 0)
                    modifiers.append(contentsOf: groupModifier.appendedModifiers)
                    groups[groupModifier.groupName] = modifiers
                } else {
                    fallthrough
                }
            case .replace:
                groups[groupModifier.groupName] = groupModifier.insertedModifiers + groupModifier.appendedModifiers
                sortedGroupNames.append(groupModifier.groupName)
            }
        }

        // 4. Execute all updators.
        update.forEach { groupName, updators in
            guard var modifiers = groups[groupName] else {
                return
            }
            updators.forEach { updator in
                guard let firstMatchedModifierIndex = modifiers.firstIndex(where: { modifier -> Bool in
                    if case .keyValue(let kv) = modifier,
                        kv.key == updator.designatedKey {
                        return true
                    } else {
                        return false
                    }
                }) else {
                    return
                }

                modifiers[firstMatchedModifierIndex] = updator.update(modifier: modifiers[firstMatchedModifierIndex])
            }
            groups[groupName] = modifiers
        }

        // 5. Handle functions (replacing groups)
        return groups.mapValues { modifiers -> [GroupModifier.Modifier] in
            return modifiers.map { modifier in
                guard case .keyValue(let kv) = modifier,
                    !kv.functionIndics.isEmpty else {
                        return modifier
                }
                return .keyValue(kv.handleFunction(withReferenceModifiers: filtedGroupModifiers))
            }
        }.sorted(by: {
            sortedGroupNames.firstIndex(of: $0.key)! < sortedGroupNames.firstIndex(of: $1.key)!
        }).map { groupName, modifiers -> String in
            return "[\(groupName)]\n" + modifiers.map { $0.exportToString() }.joined(separator: "\n") + "\n"
        }.joined(separator: "\n")
    }
}
