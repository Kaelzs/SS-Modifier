//
//  File.swift
//  
//
//  Created by Kael Yang on 2020/5/28.
//

import Vapor

struct SurgeController {
    func routes(_ router: RoutesBuilder) throws {
        router.get("convert", use: convert)
    }
}
