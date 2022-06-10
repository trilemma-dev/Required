//
//  Requirement+Evaluate.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-22
//

import Foundation

public extension Requirement {
    // Both functions in this extension are implemented in a rather hacky manner. This is because the behavior we want
    // is for the the `evaluate` functions implemented for each requirement type as an extension to be called. However,
    // Swift (for good reasons) does not allow extensions to override existing functions. So to work around that, this
    // is acting as manual dispatch.
    //
    // Note: The evaluate extensions are all internal because it simplifies documentation, but making them public would
    // not change anything about the above except if an API user explicitly cast a requirement to one of its concrete
    // implementations.
    
    /// Evaluates this requirement relative to this provided static code.
    ///
    /// This evaluation is recursive for all child requirements of this requirement.
    func evaluateForStaticCode(_ staticCode: SecStaticCode) throws -> Evaluation {
        switch self.self {
            case is OrRequirement:
                return try (self as! OrRequirement).evaluateForStaticCode(staticCode)
            case is AndRequirement:
                return try (self as! AndRequirement).evaluateForStaticCode(staticCode)
            case is NegationRequirement:
                return try (self as! NegationRequirement).evaluateForStaticCode(staticCode)
            case is ParenthesesRequirement:
                return try (self as! ParenthesesRequirement).evaluateForStaticCode(staticCode)
            case is CertificateConstraint:
                return try (self as! CertificateConstraint).evaluateForStaticCode(staticCode)
            case is CodeDirectoryHashConstraint:
                return try (self as! CodeDirectoryHashConstraint).evaluateForStaticCode(staticCode)
            case is EntitlementConstraint:
                return try (self as! EntitlementConstraint).evaluateForStaticCode(staticCode)
            case is IdentifierConstraint:
                return try (self as! IdentifierConstraint).evaluateForStaticCode(staticCode)
            case is InfoConstraint:
                return try (self as! InfoConstraint).evaluateForStaticCode(staticCode)
            default:
                fatalError("Unknown type: \(self.self)")
        }
    }
    
    /// Evaluates this requirement relative to this current process.
    ///
    /// This evaluation is recursive for all child requirements of this requirement.
    func evaluateForSelf() throws -> Evaluation {
        switch self.self {
            case is OrRequirement:                  return try (self as! OrRequirement).evaluateForSelf()
            case is AndRequirement:                 return try (self as! AndRequirement).evaluateForSelf()
            case is NegationRequirement:            return try (self as! NegationRequirement).evaluateForSelf()
            case is ParenthesesRequirement:         return try (self as! ParenthesesRequirement).evaluateForSelf()
            case is CertificateConstraint:          return try (self as! CertificateConstraint).evaluateForSelf()
            case is CodeDirectoryHashConstraint:    return try (self as! CodeDirectoryHashConstraint).evaluateForSelf()
            case is EntitlementConstraint:          return try (self as! EntitlementConstraint).evaluateForSelf()
            case is IdentifierConstraint:           return try (self as! IdentifierConstraint).evaluateForSelf()
            case is InfoConstraint:                 return try (self as! InfoConstraint).evaluateForSelf()
            default:                                fatalError("Unknown type: \(self.self)")
        }
    }
}
