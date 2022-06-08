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
            return .constraintNotSatisfied(self, explanation: "No entitlements present")
        }
        
        return self.match.evaluate(actualValue: entitlements[self.key.value], constraint: self)
    }
    
    func evaluateForSelf() throws -> Evaluation {
        let actualValue = try SecTask.current.valueForEntitlement(key: self.key.value)
        
        return self.match.evaluate(actualValue: actualValue, constraint: self)
    }
}
