//
//  OrRequirement+Evaluate.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-08
//

import Security

extension OrRequirement {
    func evaluateForStaticCode(_ staticCode: SecStaticCode) throws -> Evaluation {
        let lhs = try self.lhs.evaluateForStaticCode(staticCode)
        let rhs = try self.rhs.evaluateForStaticCode(staticCode)
        
        if lhs.isSatisfied || rhs.isSatisfied {
            return .requirementSatisfied(self, children: [lhs, rhs])
        } else {
            return .requirementNotSatisfied(self, children: [lhs, rhs])
        }
    }
    
    func evaluateForSelf() throws -> Evaluation {
        let lhs = try self.lhs.evaluateForSelf()
        let rhs = try self.rhs.evaluateForSelf()
        
        if lhs.isSatisfied || rhs.isSatisfied {
            return .requirementSatisfied(self, children: [lhs, rhs])
        } else {
            return .requirementNotSatisfied(self, children: [lhs, rhs])
        }
    }
}
