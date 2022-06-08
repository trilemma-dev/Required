//
//  CodeDirectoryHashConstraint+Evaluate.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-20
//

import Foundation
import Security

extension CodeDirectoryHashConstraint {
    func evaluateForStaticCode(_ staticCode: SecStaticCode) throws -> Evaluation {
        let signingInfo = try staticCode.readSigningInformation()
        // While the documentation for kSecCodeInfoUnique does not explicitly say it's used for cdhash, it describes
        // itself as:
        //   This identifier can be used to recognize this specific code in the future. This identifier is tied to the
        //   current version of the code, unlike the kSecCodeInfoIdentifier identifier, which remains stable across
        //   developer-approved updates. The algorithm used for the kSecCodeInfoUnique identifier may change over time.
        //   However, the identifier remains stable for existing, signed code.
        //
        // This matches the purpose of cdhash and in practice always appears to behave as expected.
        //
        // Using Apple created tools, the cdhash for an application/binary can be seen using `codesign -dvvv <path>`
        guard let hash = signingInfo[.unique] as? Data else {
            return .constraintNotSatisfied(self, explanation: "Unique hash not present")
        }
       
        if hashConstantSymbol.value.lowercased() == hash.hexEncodedString() {
            return .constraintSatisfied(self)
        } else {
            return .constraintNotSatisfied(self, explanation: "Hashes did not match. " +
                                           "Expected: \(hashConstantSymbol.value.lowercased()) " +
                                           "Actual: \(hash.hexEncodedString())")
        }
    }
    
    func evaluateForSelf() throws -> Evaluation {
        try evaluateForStaticCode(try SecCode.current.asStaticCode())
    }
}
