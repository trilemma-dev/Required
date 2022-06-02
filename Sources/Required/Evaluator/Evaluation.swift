//
//  Evaluation.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-19
//

public enum Evaluation {
    case constraintSatisfied(constraint: Constraint)
    case constraintNotSatisfied(constraint: Constraint, explanation: String)
    /// Due to negation a requirement, a requirement can be satisfied even if a child is not satisfied.
    /// Due to an or requirement, not all children are necessarily satisfied.
    case requirementSatisfied(requirement: Requirement, childrenEvaluations: [Evaluation])
    /// Due to a negation requirement, a requirement can be not satisfied even if a child is satsified.
    case requirementNotSatisfied(requirement: Requirement, childrenEvaluations: [Evaluation])
    
    public var isSatisfied: Bool {
        switch self {
            case .constraintSatisfied(_):           return true
            case .constraintNotSatisfied(_, _):     return false
            case .requirementSatisfied(_, _):       return true
            case .requirementNotSatisfied(_, _):    return false
        }
    }
    
    public var explanation: String {
        switch self {
            case .constraintSatisfied(_): return "This constraint is satifised."
            case .constraintNotSatisfied(_, let explanation): return explanation
            case .requirementSatisfied(_, _): return "This requirement is satisfied."
            case .requirementNotSatisfied(_, _): return "This requirement is not satisfied, see child evaluations."
        }
    }
}
