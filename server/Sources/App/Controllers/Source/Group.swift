//
//  Group.swift
//  SSTest
//
//  Created by Kael Yang on 26/8/2020.
//  Copyright © 2020 Kael Yang. All rights reserved.
//

import Foundation

extension Surge {
     enum Group {
        private static let keyValueSupportedGroup = [
            "General",
            "Replica",
            "Proxy",
            "Proxy Group",
            "MITM",
        ].map { $0.lowercased() }

        static func isKeyValueGroup(_ groupName: String) -> Bool {
            return keyValueSupportedGroup.contains(groupName.lowercased())
        }
    }
}
