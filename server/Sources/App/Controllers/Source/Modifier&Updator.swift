//
//  Modifier&Updator.swift
//  SSTest
//
//  Created by Kael Yang on 26/8/2020.
//  Copyright © 2020 Kael Yang. All rights reserved.
//

import Foundation

private typealias SplittedValue = (valueArray: [String], functionIndics: [Int])
private func split(valueString: String) -> SplittedValue {
    var valueArray: [String] = []
    var functionIndics: [Int] = []

    var parenthesesLevel = 0
    var quoteSet: Set<Character> = []
    var lastIndex = valueString.startIndex

    func insertResultToValueArray(withCurrentIndex currentIndex: String.Index) {
        let result = String(valueString[lastIndex ..< currentIndex]).trimmingCharacters(in: .whitespaces)
        valueArray.append(result)
        if result.starts(with: "$") {
            functionIndics.append(valueArray.count - 1)
        }
    }

    valueString.indices.forEach { stringIndex in
        let char = valueString[stringIndex]
        switch char {
        case ",":
            guard parenthesesLevel <= 0 && quoteSet.isEmpty else { return }

            insertResultToValueArray(withCurrentIndex: stringIndex)
            lastIndex = valueString.index(after: stringIndex)
        case "\'", "\"":
            if quoteSet.contains(char) {
                // It's safe to get the previous char when quoteSet is not empty..
                guard valueString[valueString.index(before: stringIndex)] != #"\"# else {
                    return
                }
                quoteSet.remove(char)
            } else {
                quoteSet.insert(char)
            }
        case "(", ")":
            guard quoteSet.isEmpty else {
                return
            }
            if char == "(" {
                parenthesesLevel += 1
            } else {
                parenthesesLevel -= 1
            }
        default:
            return
        }
    }
    if lastIndex < valueString.endIndex {
        insertResultToValueArray(withCurrentIndex: valueString.endIndex)
    }
    return (valueArray, functionIndics)
}

extension Surge.GroupModifier {
    enum Modifier {
        struct KeyValue {
            var key: String
            var values: [String]

            let functionIndics: [Int]
        }

        case keyValue(KeyValue)
        case plain(String)
        case resource(URL)

        private static let resourceRangeRegex = try! NSRegularExpression(pattern: #"\$from\(\s*\'([^\s\']+)\'\s*\)"#, options: [.caseInsensitive])
        init(_ rawValue: String, supportKeyValue: Bool) {
            let trimmedValue = rawValue.trimmingCharacters(in: .whitespaces)

            let nsString = NSString(string: trimmedValue)
            if let firstResult = Self.resourceRangeRegex.firstMatch(in: trimmedValue, options: .anchored, range: NSRange(location: 0, length: nsString.length)) {
                let resourceRange = firstResult.range(at: 1)
                let resourceUrlString = nsString.substring(with: resourceRange)
                if let resourceUrl = URL(string: resourceUrlString) {
                    self = .resource(resourceUrl)
                } else {
                    self = .plain("# Invalid resource url \(resourceUrlString)")
                }
                return
            }

            if supportKeyValue,
                let firstEqualRange = trimmedValue.range(of: #"\s*=\s*"#, options: .regularExpression, range: nil, locale: nil) {

                let key = String(trimmedValue[..<firstEqualRange.lowerBound])
                let values = String(trimmedValue[firstEqualRange.upperBound...])
                let splittedValue = split(valueString: values)
                self = .keyValue(KeyValue(key: key, values: splittedValue.valueArray, functionIndics: splittedValue.functionIndics))
                return
            }

            self = .plain(rawValue)
        }

        func exportToString() -> String {
            switch self {
            case .keyValue(let kv):
                return kv.key + " = " + kv.values.filter({ !$0.isEmpty }).joined(separator: ", ")
            case .plain(let str):
                return str
            case .resource(let url):
                return "# load resource from \(url) error."
            }
        }
    }
}

extension Surge.GroupModifier {
    struct Updator {
        enum `Type` {
            case insert(index: Int, value: String)
            case append(index: Int, value: String)
            case replace(value: String)
            case delete(index: Int)
        }

        let designatedKey: String
        let type: Type

        init?(updatorTypedString: String, content: String) {
            if let deletedIndex = updatorTypedString.range(of: "delete-").flatMap({ Int(updatorTypedString[$0.upperBound...]) }) {
                let designatedKey = content.trimmingCharacters(in: .whitespaces)
                self.designatedKey = designatedKey
                self.type = .delete(index: deletedIndex)
                return
            }

            guard let firstEqualIndex = content.firstIndex(of: "=") else {
                return nil
            }
            self.designatedKey = content[..<firstEqualIndex].trimmingCharacters(in: .whitespaces)

            let value = content[firstEqualIndex...].dropFirst().trimmingCharacters(in: .whitespaces)

            if updatorTypedString == "replace" {
                self.type = .replace(value: value)
                return
            } else if let insertedIndex = updatorTypedString.range(of: "insert-").flatMap({ Int(updatorTypedString[$0.upperBound...]) }) {
                self.type = .insert(index: insertedIndex, value: value)
                return
            } else if let appendedIndex = updatorTypedString.range(of: "append-").flatMap({ Int(updatorTypedString[$0.upperBound...]) }) {
                self.type = .append(index: appendedIndex, value: value)
                return
            }
            return nil
        }

        func update(modifier: Modifier) -> Modifier {
            guard case .keyValue(let kv) = modifier else {
                return modifier
            }
            switch self.type {
            case .insert(let index, let value):
                var values = kv.values
                values.insert(value, at: index)
                return .keyValue(Modifier.KeyValue(key: kv.key, values: values, functionIndics: kv.functionIndics.map({ $0 >= index ? $0 + 1 : $0 })))
            case .append(let index, let value):
                var values = kv.values
                values.insert(value, at: values.count - index)
                return .keyValue(Modifier.KeyValue(key: kv.key, values: values, functionIndics: kv.functionIndics))
            case .replace(let value):
                return .keyValue(Modifier.KeyValue(key: kv.key, values: [value], functionIndics: []))
            case .delete(let index):
                var values = kv.values
                values.remove(at: index)
                return .keyValue(Modifier.KeyValue(key: kv.key, values: values, functionIndics: kv.functionIndics.compactMap({ functionIndex in
                    if functionIndex < index {
                        return functionIndex
                    } else if functionIndex == index {
                        return nil
                    } else {
                        return functionIndex - 1
                    }
                })))
            }

        }
    }
}
