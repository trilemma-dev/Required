//
//  TestHelpers.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-02
//

import XCTest
import Required


extension ParseResult {
    struct UnexpectedParseResult: Error { }
    
    func asRequirement() throws -> Requirement {
        switch self {
            case .requirement(let requirement):
                return requirement
            case .requirementSet(_):
                XCTFail("Parse result was a requirement set, not a requirement")
                throw UnexpectedParseResult()
        }
    }
    
    func asRequirementSet() throws -> RequirementSet {
        switch self {
            case .requirement(_):
                XCTFail("Parse result was a requirement set, not a requirement")
                throw UnexpectedParseResult()
            case .requirementSet(let requirementSet):
                return requirementSet
        }
    }
}


func parse<T: Requirement>(_ text: String, asType: T.Type) throws -> T {
    let requirement = try Parser.parse(requirement: text).asRequirement()
    XCTAssert(requirement is T)
    
    return requirement as! T
}

func parseRequirementSet(_ text: String) throws -> RequirementSet {
    try Parser.parse(requirement: text).asRequirementSet()
}
