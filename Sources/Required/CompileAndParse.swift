//
//  CompileAndParse.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-02
//

import Foundation

// This file serves to bridge the abstract syntax tree `Requirement` and `RequirementSet` with `SecRequirement`

/// Converts a code requirement object into abstract syntax tree form.
public func SecRequirementCopyAbstractSyntaxTree(
    _ requirement: SecRequirement,
    _ flags: SecCSFlags,
    _ statement: inout Requirement
) -> OSStatus {
    var text: CFString?
    let resultCode = SecRequirementCopyString(requirement, flags, &text)
    guard resultCode == errSecSuccess else {
        return resultCode
    }
    guard let text = text as String? else {
        return errSecInternalError
    }
    
    // Because we now have the text form of a compiled requirement, tokenization and parsing should always succeed.
    // If it does not that's an implementation error of the tokenizer or parser, not an error of the API user.
    do {
        let parseResult = try Parser.parse(requirement: text)
        // A SecRequirement must be a statement, not a RequirementSet
        guard let statementResult = parseResult as? Requirement else {
            return errSecInternalError
        }
        statement = statementResult
    } catch {
        return errSecInternalError
    }
    
    return errSecSuccess
}

public extension Requirement {
    func compile() throws -> SecRequirement {
        try SecRequirement.withString(self.textForm)
    }
}

public extension RequirementSet {
    func compile() throws -> [SecRequirementType : SecRequirement] {
        var compiledSet = [SecRequirementType : SecRequirement]()
        for (tag, requirementElement) in self.requirements {
            let compiledKey: SecRequirementType
            switch tag {
                case .host:       compiledKey = .hostRequirementType
                case .guest:      compiledKey = .guestRequirementType
                case .library:    compiledKey = .libraryRequirementType
                case .designated: compiledKey = .designatedRequirementType
            }
            compiledSet[compiledKey] = try requirementElement.requirement.compile()
        }
        
        return compiledSet
    }
}
