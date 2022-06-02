//
//  IdentifierConstraint+Evaluate.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-19
//

import Security
import Foundation

public extension IdentifierConstraint {
    func evaluateForStaticCode(_ staticCode: SecStaticCode) throws -> Evaluation {
        let info = try staticCode.readSigningInformation(options: [.signingInformation])
        
        guard let identifier = info[.identifier] else {
            let explanation = "Expected: \(self.constant.value), but there was no identifier present"
            return .constraintNotSatisfied(constraint: self, explanation: explanation)
        }
        
        guard let identifier = identifier as? String else {
            fatalError("kSecCodeInfoIdentifier is documented to be the key for a value of type String")
        }
        
        guard identifier == self.constant.value else {
            let explanation = "Expected: \(self.constant.value), actual: \(identifier)"
            return .constraintNotSatisfied(constraint: self, explanation: explanation)
        }
        
        return .constraintSatisfied(constraint: self)
    }
    
    func evaluateForSelf() throws -> Evaluation {
        let signingIdentifier = try SecTask.current.signingIdentifier
        guard signingIdentifier == self.constant.value else {
            let explanation = "Expected: \(self.constant.value), actual: \(signingIdentifier)"
            return .constraintNotSatisfied(constraint: self, explanation: explanation)
        }
        
        return .constraintSatisfied(constraint: self)
    }
}
