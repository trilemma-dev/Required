//
//  MatchFragment+Evaluate.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-20
//

import Foundation

extension MatchExpression {
    func evaluate(actualValue: Any?, constraint: Constraint) -> Evaluation {
        guard let actualValue = actualValue else {
            return .constraintNotSatisfied(constraint, explanation: "Value not present")
        }
        
        switch self {
            case .infix(let operation, let expected):
                // Inequality operations compare some value to a constant. The value and constant must be of the
                // same type: a string matches a string constant, a data value matches a hexadecimal constant. String
                // comparisons use the same matching rules as CFString with the kCFCompareNumerically option flag; for
                // example, "17.4" is greater than "7.4".
                guard let actualValue = actualValue as? String else {
                    let explanation = "The actual value is not a string, but the constraint is an inequality " +
                                      "comparison for a string. Expected: \(expected.value) Actual: \(actualValue)"
                    return .constraintNotSatisfied(constraint, explanation: explanation)
                }

                let result = CFStringCompare(actualValue as CFString, expected.value as CFString, .compareNumerically)
                switch result {
                    case .compareLessThan:
                        if (operation is LessThanSymbol) || (operation is LessThanOrEqualToSymbol) {
                            return .constraintSatisfied(constraint)
                        } else {
                            let explanation = "\(actualValue) is less than expected value \(expected.value)"
                            return .constraintNotSatisfied(constraint, explanation: explanation)
                        }
                    case .compareEqualTo:
                        if (operation is EqualsSymbol) ||
                            (operation is LessThanOrEqualToSymbol) ||
                            (operation is GreaterThanOrEqualToSymbol) {
                            return .constraintSatisfied(constraint)
                        } else {
                            let explanation = "\(actualValue) is equal to expected value \(expected.value)"
                            return .constraintNotSatisfied(constraint, explanation: explanation)
                        }
                    case .compareGreaterThan:
                        if (operation is GreaterThanSymbol) || (operation is GreaterThanOrEqualToSymbol) {
                            return .constraintSatisfied(constraint)
                        } else {
                            let explanation = "\(actualValue) is greater than expected value \(expected.value)"
                            return .constraintNotSatisfied(constraint, explanation: explanation)
                        }
                    @unknown default:
                        fatalError("Unhandled CFComparisonResult case")
                }
            case .infixEquals(_, let expected):
                // All equality operations compare some value to a constant. The value and constant must be of the same
                // type: a string matches a string constant, a data value matches a hexadecimal constant. The equality
                // operation evaluates to true if the value exists and is equal to the constant. String matching uses
                // the same matching rules as CFString (see CFString Reference).
                guard let actualValue = actualValue as? String else {
                    let explanation = "The actual value is not a string, but the constraint is an equality " +
                                      "comparison for a wildcard string. Actual: \(actualValue)"
                    return .constraintNotSatisfied(constraint, explanation: explanation)
                }
                
                // In match expressions (see Info, Part of a Certificate, and Entitlement), substrings of string
                // constants can be matched by using the * wildcard character:
                switch expected {
                    case .prefixWildcard(_, let string):
                        if actualValue.hasSuffix(string.value) {
                            return .constraintSatisfied(constraint)
                        } else {
                            let explanation = "\(actualValue) does not end with expected value \(string.value)"
                            return .constraintNotSatisfied(constraint, explanation: explanation)
                        }
                    case .postfixWildcard(let string, _):
                        if actualValue.hasPrefix(string.value) {
                            return .constraintSatisfied(constraint)
                        } else {
                            let explanation = "\(actualValue) does not begin with expected value \(string.value)"
                            return .constraintNotSatisfied(constraint, explanation: explanation)
                        }
                    case .prefixAndPostfixWildcard(_, let string, _):
                        if actualValue.contains(string.value) {
                            return .constraintSatisfied(constraint)
                        } else {
                            let explanation = "\(actualValue) does not contain expected value \(string.value)"
                            return .constraintNotSatisfied(constraint, explanation: explanation)
                        }
                }
            case .unarySuffix(_):
                // From Apple:
                //   The existence operator tests whether the value exists. It evaluates to false only if the value
                //   does not exist at all or is exactly the Boolean value false. An empty string and the number 0 are
                //   considered to exist.
                if actualValue is Bool, (actualValue as! Bool) == false {
                    let explanation = "Actual value is exactly the Boolean value false"
                    return .constraintNotSatisfied(constraint, explanation: explanation)
                } else {
                    return .constraintSatisfied(constraint)
                }
        }
    }
}
