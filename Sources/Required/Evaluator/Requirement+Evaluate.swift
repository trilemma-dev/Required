//
//  Requirement+Evaluate.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-22
//

import Foundation

/// Default implementation for any ``Requirement`` which relies on `SecStaticCodeCheckValidity`.
public extension Requirement {
    func evaluateForStaticCode(_ staticCode: SecStaticCode) throws -> Evaluation {
        let requirement = try SecRequirement.withString(self.textForm)
        let result = SecStaticCodeCheckValidity(staticCode, SecCSFlags(), requirement)
        if result == errSecSuccess {
            if let constraint = self as? Constraint {
                return .constraintSatisfied(constraint: constraint)
            } else {
                let childrenEvaluations = try self.children.map { try $0.evaluateForStaticCode(staticCode) }
                return .requirementSatisfied(requirement: self, childrenEvaluations: childrenEvaluations)
            }
        } else if result == errSecCSReqFailed {
            let explanation = "Static code validity check failed"
            if let constraint = self as? Constraint {
                return .constraintNotSatisfied(constraint: constraint, explanation: explanation)
            } else {
                let childrenEvaluations = try self.children.map { try $0.evaluateForStaticCode(staticCode) }
                return .requirementNotSatisfied(requirement: self, childrenEvaluations: childrenEvaluations)
            }
        } else {
            throw SecurityError.statusCode(result)
        }
    }
    
    func evaluateForSelf() throws -> Evaluation {
        try evaluateForStaticCode(try SecCode.current.asStaticCode())
    }
}
