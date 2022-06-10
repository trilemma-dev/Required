//
//  InfoConstraint+Evaluate.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-20
//

import Foundation

extension InfoConstraint {
    func evaluateForStaticCode(_ staticCode: SecStaticCode) throws -> Evaluation {
        let signingInfo = try staticCode.readSigningInformation(options: [.signingInformation])
        guard let info = signingInfo[.infoPList] as? [String : Any] else {
            return .constraintNotSatisfied(self, explanation: "No info property list present")
        }
        guard let value = info[self.key.value] else {
            let explanation = "Info property list has no value for key \(self.key.value)"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
        
        return self.match.evaluate(actualValue: value, constraint: self)
    }
    
    func evaluateForSelf() throws -> Evaluation {
        guard let info = Bundle.main.infoDictionary else {
            return .constraintNotSatisfied(self, explanation: "No info property list present")
        }
        guard let value = info[self.key.value] else {
            let explanation = "Info property list has no value for key \(self.key.value)"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
        
        return self.match.evaluate(actualValue: value, constraint: self)
    }
}
