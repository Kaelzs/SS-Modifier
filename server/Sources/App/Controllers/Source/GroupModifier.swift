//
//  GroupModifier.swift
//  SSTest
//
//  Created by Kael Yang on 26/8/2020.
//  Copyright © 2020 Kael Yang. All rights reserved.
//

import Foundation

// MARK: - Variable declaractions & Convenience mutating function
extension Surge {
    struct GroupModifier {
        enum ModificationType {
            case replace
            case modify
        }

        let groupName: String

        var name: String?
        var modificationType: ModificationType = .replace {
            didSet {
                if oldValue != modificationType {
                    self.cleanContentsForTypeChanging()
                }
            }
        }

        var isBasedOnResources: Bool = false
        var requiredModifierNames: [String] = []

        var insertedModifiers: [Modifier] = []
        var appendedModifiers: [Modifier] = []
        var updators: [Updator] = []

        var resources: Set<URL> = []

        private mutating func addResourceIfNeeded(for modifier: Modifier) {
            if case .resource(let url) = modifier {
                resources.insert(url)
            }
        }

        mutating func add(insertedModifier modifierr: Modifier) {
            addResourceIfNeeded(for: modifierr)
            insertedModifiers.append(modifierr)
        }

        mutating func add(appendedModifier modifierr: Modifier) {
            addResourceIfNeeded(for: modifierr)
            appendedModifiers.append(modifierr)
        }

        mutating func add(updator: Updator) {
            updators.append(updator)
        }

        private mutating func cleanContentsForTypeChanging() {
            self.insertedModifiers = []
            self.appendedModifiers = []
            self.updators = []
            self.resources = []
        }
    }
}

// MARK: - Extractor
extension Surge.GroupModifier {
    typealias ExtractResult = (groupModifiers: [Self], resources: Set<URL>)
    private static let decoratorHelperRegex = try! NSRegularExpression(pattern: #"^#!([^\s\r]+)\s*"#, options: [.anchorsMatchLines])
    static func extract(from string: String) -> ExtractResult {
        let splittedLines = string.components(separatedBy: .newlines)

        var modifiers: [Self] = []
        var resources: Set<URL> = []
        var ignoringGroupNames: Set<String> = []

        var toHandledLines: [String] = []

        for line in splittedLines.reversed() {
            guard let range = line.range(of: #"\[.+\]"#, options: [.anchored, .regularExpression]) else {
                toHandledLines.append(line)
                continue
            }

            let groupName = String(line[line.index(range.lowerBound, offsetBy: 1) ..< line.index(range.upperBound, offsetBy: -1)])

            guard !ignoringGroupNames.contains(groupName) else {
                toHandledLines = []
                continue
            }

            ignoringGroupNames.insert(groupName)

            toHandledLines.reverse()
            guard let emptyPrefixCount = toHandledLines.firstIndex(where: { !$0.isEmpty }),
                let emptySuffixCountHelper = toHandledLines.lastIndex(where: { !$0.isEmpty }) else {
                    toHandledLines = []
                    continue
            }
            let emptySuffixCount = toHandledLines.count - emptySuffixCountHelper - 1

            toHandledLines.removeFirst(emptyPrefixCount)
            toHandledLines.removeLast(emptySuffixCount)

            var groupModifier = Self(groupName: groupName)

            let groupSupportKeyValue = Surge.Group.isKeyValueGroup(groupName)

            for handledLine in toHandledLines {
                let nsString = NSString(string: handledLine)
                guard let firstMatchResult = Self.decoratorHelperRegex.firstMatch(in: handledLine, options: [], range: NSRange(location: 0, length: nsString.length)) else {
                    if groupModifier.modificationType == .replace {
                        let modifier = Modifier(handledLine, supportKeyValue: groupSupportKeyValue)
                        groupModifier.add(insertedModifier: modifier)
                    }
                    continue
                }

                let decorator = nsString.substring(with: firstMatchResult.range(at: 1))
                let modifierString = nsString.substring(from: firstMatchResult.range.length)

                switch decorator {
                case "type":
                    switch modifierString.trimmingCharacters(in: .whitespaces).lowercased() {
                    case "modify", "modifier":
                        groupModifier.modificationType = .modify
                        ignoringGroupNames.remove(groupName)
                    case "replace":
                        groupModifier.modificationType = .replace
                        ignoringGroupNames.insert(groupName)
                    default:
                        continue
                    }
                case "name":
                    groupModifier.name = modifierString
                case "insert", "inserted":
                    groupModifier.add(insertedModifier: Modifier(modifierString, supportKeyValue: groupSupportKeyValue))
                case "append", "appended":
                    groupModifier.add(appendedModifier: Modifier(modifierString, supportKeyValue: groupSupportKeyValue))
                case "basedOnResources":
                    switch modifierString.trimmingCharacters(in: .whitespaces).lowercased() {
                    case "true", "1", "yes":
                        groupModifier.isBasedOnResources = true
                        ignoringGroupNames.remove(groupName)
                    case "false", "0", "no":
                        groupModifier.isBasedOnResources = false
                    default:
                        continue
                    }
                case "requiredModifiers":
                    let modifierNames = modifierString.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }).filter { !$0.isEmpty }
                    if !modifierNames.isEmpty {
                        groupModifier.requiredModifierNames += modifierNames
                        ignoringGroupNames.remove(groupName)
                    }
                case let updatorDecorator where updatorDecorator.starts(with: "update"),
                     let updatorDecorator where updatorDecorator.count > 7:

                    let updatorTypedString = String(updatorDecorator[updatorDecorator.index(updatorDecorator.startIndex, offsetBy: 7)...])
                    if let updator = Updator(updatorTypedString: updatorTypedString, content: modifierString) {
                        groupModifier.add(updator: updator)
                    } else {
                        groupModifier.add(insertedModifier: Modifier.plain("# updator syntax error \(updatorTypedString) not recognized."))
                    }
                default:
                    groupModifier.add(insertedModifier: Modifier.plain("# decorator not recognized, \(decorator)"))
                }
            }

            toHandledLines = []
            modifiers.append(groupModifier)
            groupModifier.resources.forEach({ resources.insert($0) })
        }

        return (modifiers.reversed(), resources)
    }
}

// MARK: - Profile generator
extension Surge.GroupModifier {
    public typealias Resources = [URL: String]
    private static let nextGroupRegex = try! NSRegularExpression(pattern: #"^\n*\[([^\r\n]+)\]"#, options: [.anchorsMatchLines])
    private func flat(modifier: Modifier, withResource resources: Resources, skipNormalProxy: Bool) -> [Modifier] {
        guard case .resource(let url) = modifier else {
            return [modifier]
        }

        guard let resource = resources[url] else {
            return [Modifier.plain("# cannot download resource from \(url.absoluteString)")]
        }

        let toHandledContents: String

        let groupTitleRegex = try! NSRegularExpression(pattern: #"^\["# + self.groupName + #"\][^\n]*\n+"#, options: [.anchorsMatchLines])
        let nsString = NSString(string: resource)
        if let matched = groupTitleRegex.firstMatch(in: resource, options: [], range: NSRange(location: 0, length: nsString.length)) {

            let groupNameRange = matched.range
            let start = groupNameRange.location + groupNameRange.length

            let endRange = Self.nextGroupRegex.firstMatch(in: resource, options: [], range: NSRange(location: start, length: nsString.length - start))?.range

            let endLocation = endRange?.location ?? nsString.length

            toHandledContents = nsString.substring(with: NSRange(location: start, length: endLocation - start))
        } else {
            toHandledContents = resource
        }

        let toHandledLines = toHandledContents.trimmingCharacters(in: .whitespaceAndNewline).components(separatedBy: .newlines)

        let groupSupportKeyValue = Surge.Group.isKeyValueGroup(groupName)

        var toHandledModifiers = toHandledLines.map({ Modifier($0, supportKeyValue: groupSupportKeyValue) })

        if self.groupName.lowercased() == "proxy",
           skipNormalProxy {
            toHandledModifiers.removeAll { modifier in
                if case let .keyValue(kv) = modifier,
                   kv.values.count == 1,
                   ["direct", "reject", "reject-tinygif"].contains(kv.values[0]) {
                    return true
                }
                return false
            }
        }

        return [Modifier.plain("# resource from \(url.absoluteString)")]
            + toHandledModifiers
            + [Modifier.plain("# resource end \(url.absoluteString)")]
    }

    struct ResourceError: Error {
        let url: URL
    }
    func flat(withResources resources: Resources, skipNormalProxy: Bool) -> Result<Self, ResourceError> {
        guard !self.resources.isEmpty else {
            return .success(self)
        }

        if self.isBasedOnResources,
            let errorResources = self.resources.first(where: { resources[$0] == nil }) {
            return .failure(ResourceError(url: errorResources))
        }

        var copy = self
        copy.insertedModifiers = copy.insertedModifiers.flatMap { self.flat(modifier: $0, withResource: resources, skipNormalProxy: skipNormalProxy) }
        copy.appendedModifiers = copy.appendedModifiers.flatMap { self.flat(modifier: $0, withResource: resources, skipNormalProxy: skipNormalProxy) }

        return .success(copy)
    }
}
