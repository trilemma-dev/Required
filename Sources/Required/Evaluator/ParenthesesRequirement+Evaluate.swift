//
//  ParenthesesRequirement+Evaluate.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-08
//

import Security

extension ParenthesesRequirement {
    func evaluateForStaticCode(_ staticCode: SecStaticCode) throws -> Evaluation {
        let child = try self.requirement.evaluateForStaticCode(staticCode)
        
        if child.isSatisfied {
            return .requirementSatisfied(self, children: [child])
        } else {
            return .requirementNotSatisfied(self, children: [child])
        }
    }
    
    func evaluateForSelf() throws -> Evaluation {
        let child = try self.requirement.evaluateForSelf()
        
        if child.isSatisfied {
            return .requirementSatisfied(self, children: [child])
        } else {
            return .requirementNotSatisfied(self, children: [child])
        }
    }
}
