//
//  MatchFragment+Evaluate.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-20
//

import Foundation

extension MatchFragment {
    func evaluate(actualValue: Any?, constraint: Constraint) -> Evaluation {
        guard let actualValue = actualValue else {
            return .constraintNotSatisfied(constraint: constraint, explanation: "Value not present")
        }
        
        switch self {
            case .infix(let operation, let string):
                // Inequality operations compare some value to a constant. The value and constant must be of the
                // same type: a string matches a string constant, a data value matches a hexadecimal constant. String
                // comparisons use the same matching rules as CFString with the kCFCompareNumerically option flag; for
                // example, "17.4" is greater than "7.4".
                guard let actualValue = actualValue as? String else {
                    let explanation = "Value not a string, but the constraint is an inequality comparison for a " +
                                      "string. Value: \(actualValue)"
                    return .constraintNotSatisfied(constraint: constraint, explanation: explanation)
                }

                let result = CFStringCompare(actualValue as CFString, string.value as CFString, .compareNumerically)
                switch result {
                    case .compareLessThan:
                        if (operation is LessThanSymbol) || (operation is LessThanOrEqualToSymbol) {
                            return .constraintSatisfied(constraint: constraint)
                        } else {
                            let explanation = "\(actualValue) is less than \(string.value)"
                            return .constraintNotSatisfied(constraint: constraint, explanation: explanation)
                        }
                    case .compareEqualTo:
                        if (operation is EqualsSymbol) ||
                            (operation is LessThanOrEqualToSymbol) ||
                            (operation is GreaterThanOrEqualToSymbol) {
                            return .constraintSatisfied(constraint: constraint)
                        } else {
                            let explanation = "\(actualValue) is equal to \(string.value)"
                            return .constraintNotSatisfied(constraint: constraint, explanation: explanation)
                        }
                    case .compareGreaterThan:
                        if (operation is GreaterThanSymbol) || (operation is GreaterThanOrEqualToSymbol) {
                            return .constraintSatisfied(constraint: constraint)
                        } else {
                            let explanation = "\(actualValue) is greater than \(string.value)"
                            return .constraintNotSatisfied(constraint: constraint, explanation: explanation)
                        }
                    @unknown default:
                        fatalError("Unhandled CFComparisonResult case")
                }
            case .infixEquals(_, let wildcardString):
                // All equality operations compare some value to a constant. The value and constant must be of the same
                // type: a string matches a string constant, a data value matches a hexadecimal constant. The equality
                // operation evaluates to true if the value exists and is equal to the constant. String matching uses
                // the same matching rules as CFString (see CFString Reference).
                guard let actualValue = actualValue as? String else {
                    let explanation = "Value not a string, but the constraint is an equality comparison for a " +
                                      "wildcard string."
                    return .constraintNotSatisfied(constraint: constraint, explanation: explanation)
                }
                
                // In match expressions (see Info, Part of a Certificate, and Entitlement), substrings of string
                // constants can be matched by using the * wildcard character:
                switch wildcardString {
                    case .prefixWildcard(_, let string):
                        if actualValue.hasSuffix(string.value) {
                            return .constraintSatisfied(constraint: constraint)
                        } else {
                            let explanation = "\(actualValue) does not end with \(string.value)"
                            return .constraintNotSatisfied(constraint: constraint, explanation: explanation)
                        }
                    case .postfixWildcard(let string, _):
                        if actualValue.hasPrefix(string.value) {
                            return .constraintSatisfied(constraint: constraint)
                        } else {
                            let explanation = "\(actualValue) does not begin with \(string.value)"
                            return .constraintNotSatisfied(constraint: constraint, explanation: explanation)
                        }
                    case .prefixAndPostfixWildcard(_, let string, _):
                        if actualValue.contains(string.value) {
                            return .constraintSatisfied(constraint: constraint)
                        } else {
                            let explanation = "\(actualValue) does not contain \(string.value)"
                            return .constraintNotSatisfied(constraint: constraint, explanation: explanation)
                        }
                }
            case .unarySuffix(_):
                // From Apple:
                //   The existence operator tests whether the value exists. It evaluates to false only if the value
                //   does not exist at all or is exactly the Boolean value false. An empty string and the number 0 are
                //   considered to exist.
                if actualValue is Bool, (actualValue as! Bool) == false {
                    let explanation = "Exactly the Boolean value false."
                    return .constraintNotSatisfied(constraint: constraint, explanation: explanation)
                } else {
                    return .constraintSatisfied(constraint: constraint)
                }
        }
    }
}
