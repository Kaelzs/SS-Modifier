//
//  File.swift
//  
//
//  Created by Kael Yang on 2020/5/28.
//

import Vapor

extension Request {
    func extractOneOrMoreUrl(key: String) -> [URL] {
        if let urlString: String = self.query[key],
            let url = URL(string: urlString),
            url.host != nil {
            return [url]
        } else if let urlStrings: [String] = self.query[key] {
            return urlStrings.compactMap { URL.init(string: $0) }.filter { $0.host != nil }
        }
        return []
    }

    func getBool(key: String) -> Bool? {
        if let string: String = self.query[key] {
            return ["1", "true", "t", "yes"].contains(string.lowercased())
        }
        return nil
    }
}
