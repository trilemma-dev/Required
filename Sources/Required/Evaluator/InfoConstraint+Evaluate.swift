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
        
        // If no info dictionary, not possible to match
        guard let info = signingInfo[.infoPList] as? [String : Any] else {
            return .constraintNotSatisfied(self, explanation: "No info property list present")
        }
        
        return self.match.evaluate(actualValue: info[self.key.value], constraint: self)
    }
    
    func evaluateForSelf() throws -> Evaluation {
        // If no info dictionary, not possible to match
        guard let info = Bundle.main.infoDictionary else {
            return .constraintNotSatisfied(self, explanation: "No info property list present")
        }
        
        return self.match.evaluate(actualValue: info[self.key.value], constraint: self)
    }
}
