//
//  CompileAndParse.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-02
//

import Foundation

// This file serves to bridge the abstract syntax tree `Requirement` and `RequirementSet` with `SecRequirement`

/// Converts a code requirement object into abstract syntax tree form.
///
/// - Parameters:
///   - requirement: A valid code requirement object.
///   - flags: Optional flags to be used with
///   [`SecRequirementCopyString`](https://developer.apple.com/documentation/security/1394253-secrequirementcopystring); see
///   [SecCSFlags](https://developer.apple.com/documentation/security/seccsflags) for possible values. Pass `SecCSFlags()` for
///   standard behavior.
///   - ast: On success, set to the abstract syntax tree representation of this requirement.
/// - Returns: A
/// [Security Framework result code](https://developer.apple.com/documentation/security/1542001-security_framework_result_codes).
public func SecRequirementCopyAbstractSyntaxTree(
    _ requirement: SecRequirement,
    _ flags: SecCSFlags,
    _ ast: inout Requirement?
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
        // A SecRequirement must be a Requirement, not a RequirementSet
        switch try Parser.parse(text: text) {
            case .requirement(let requirement):
                ast = requirement
                return errSecSuccess
            case .requirementSet(_):
                return errSecInternalError
        }
    } catch {
        return errSecInternalError
    }
}

public extension Parser {
    /// Parses a code requirement object.
    ///
    /// - Parameter requirement: A valid code requirement object.
    /// - Returns: The abstract syntax tree representation of the `requirement`.
    static func parse(requirement: SecRequirement) throws -> Requirement {
        var ast: Requirement?
        let result = SecRequirementCopyAbstractSyntaxTree(requirement, SecCSFlags(), &ast)
        guard let ast = ast else {
            throw ParserError.invalid(description: "Requirement could not be parsed, error code: \(result)")
        }
        
        return ast
    }
}

public extension Requirement {
    /// Compiles this abstract representation of a requirement into a `SecRequirement`.
    ///
    /// - Returns: A valid code requirement object.
    /// - Throws: If compilation fails, for example because a referenced certificate file does not actually exist.
    func compile() throws -> SecRequirement {
        try SecRequirement.withString(self.textForm)
    }
}

public extension RequirementSet {
    
    
    /// Compiles this abstract representation of a requirement set into a dictionary of `SecRequirementType` and `SecRequirement`.
    ///
    /// - Returns: A dictionary with values of valid code requirement object.
    /// - Throws: If compilation fails, for example because a requirement's referenced certificate file does not actually exist.
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
