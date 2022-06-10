//
//  IdentifierConstraint+Evaluate.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-19
//

import Security
import Foundation

extension IdentifierConstraint {
    func evaluateForStaticCode(_ staticCode: SecStaticCode) throws -> Evaluation {
        let info = try staticCode.readSigningInformation(options: [.signingInformation])
        guard let identifier = info[.identifier] else {
            let explanation = "There was no identifier present. Expected: \(self.constant.value)"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
        guard let identifier = identifier as? String else {
            fatalError("kSecCodeInfoIdentifier is documented to be the key for a value of type String")
        }
        guard identifier == self.constant.value else {
            let explanation = "Identifiers did not match. Expected: \(self.constant.value) Actual: \(identifier)"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
        
        return .constraintSatisfied(self)
    }
    
    func evaluateForSelf() throws -> Evaluation {
        let signingIdentifier = try SecTask.current.signingIdentifier
        guard signingIdentifier == self.constant.value else {
            let explanation = "Identifiers did not match. Expected: \(self.constant.value), actual: \(signingIdentifier)"
            return .constraintNotSatisfied( self, explanation: explanation)
        }
        
        return .constraintSatisfied(self)
    }
}
