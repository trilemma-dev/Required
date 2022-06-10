//
//  EntitlementConstraint+Evaluate.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-19
//

import Security

extension EntitlementConstraint {
    func evaluateForStaticCode(_ staticCode: SecStaticCode) throws -> Evaluation {
        let signingInfo = try staticCode.readSigningInformation(options: [.signingInformation])
        // If no entitlements dictionary, not possible to match
        guard let entitlements = signingInfo[.entitlementsDict] as? [String : Any] else {
            return .constraintNotSatisfied(self, explanation: "No entitlements dictionary present")
        }
        guard let value = entitlements[self.key.value] else {
            let explanation = "Entitlements dictionary has no value for key \(self.key.value)"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
        
        return self.match.evaluate(actualValue: value, constraint: self)
    }
    
    func evaluateForSelf() throws -> Evaluation {
        let value = try SecTask.current.valueForEntitlement(key: self.key.value)
        guard let value = value else {
            let explanation = "Entitlements dictionary has no value for key \(self.key.value)"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
        
        return self.match.evaluate(actualValue: value, constraint: self)
    }
}
