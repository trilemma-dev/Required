//
//  MatchExpression.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-09
//

// From Apple:
//   In match expressions (see Info, Part of a Certificate, and Entitlement), substrings of string constants can be
//   matched by using the * wildcard character.
//
//   Info:
//     where match expression can include any of the operators listed in Logical Operators and Comparison Operations
//
//   Certificate:
//     where match expression can include the * wildcard character and any of the operators listed in Logical Operators
//     and Comparison Operations
//
//   Entitlement:
//     where match expression can include the * wildcard character and any of the operators listed in Logical Operators
//     and Comparison Operations
//
//   Logical Operators:
//     ! (negation)
//     and (logical AND)
//     or (logical OR)
//
//   Comparison Operators:
//     = (equals)
//     < (less than)
//     > (greater than)
//     <= (less than or equal to)
//     >= (greater than or equal to)
//     exists (value is present)
//
//   Examples shown throughout:
//     thunderbolt = *thunder*
//     thunderbolt = thunder*
//     thunderbolt = *bolt
//     info [CFBundleShortVersionString] < "17.4"
//     info [MySpecialMarker] exists
//
// Interpretation:
//  - The logical operators can't actually be used in match expression (and there are no examples showing how to do so)
//  - The wildcard character can only be used with equality comparison
//  - The lack of wildcard character mentions for info dictionaries is an oversight, not behavioral difference
//  - Only string constants (plus wildcards) can be matched against
//    - Based on testing, hash constants are only for `cdhash` and integer constants for cert position

/// An expression of comparison or existence.
public enum MatchExpression {
    /// A comparison match expression for `=`, `<`, `>`, `<=`, or `>=` with a string.
    ///
    /// `=` match expressions with a wildcard string are represented by ``infixEquals(_:_:)``.
    case infix(InfixComparisonOperatorSymbol, StringSymbol)
    
    /// An `=` match expression with a ``WildcardString``.
    ///
    /// This type of expression is not a true equality comparison, it instead checks if a string begins with, ends with, or contains the wildcard string. True equality
    /// comparisons are represented by ``infix(_:_:)``.
    case infixEquals(EqualsSymbol, WildcardString)
    
    /// An `exists` match expression.
    case unarySuffix(ExistsSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (MatchExpression, [Token])? {
        guard let firstToken = tokens.first else {
            return nil
        }
        var remainingTokens = tokens
        
        // unarySuffix - exists
        if firstToken.type == .identifier, firstToken.rawValue == "exists" {
            let existsOperator = ExistsSymbol(sourceToken: remainingTokens.removeFirst())
            
            return (.unarySuffix(existsOperator), remainingTokens)
        }
        
        // infix or not a match expression
        let infixOperator: InfixComparisonOperatorSymbol
        switch firstToken.type {
            case .equals:
                infixOperator = EqualsSymbol(sourceToken: remainingTokens.removeFirst())
            case .lessThan:
                infixOperator = LessThanSymbol(sourceToken: remainingTokens.removeFirst())
            case .greaterThan:
                infixOperator = GreaterThanSymbol(sourceToken: remainingTokens.removeFirst())
            case .lessThanOrEqualTo:
                infixOperator = LessThanOrEqualToSymbol(sourceToken: remainingTokens.removeFirst())
            case .greaterThanOrEqualTo:
                infixOperator = GreaterThanOrEqualToSymbol(sourceToken: remainingTokens.removeFirst())
            // Not a comparison operator, so can't be parsed as a match expression
            default:
                return nil
        }
        
        guard let secondToken = remainingTokens.first else {
            throw ParserError.invalidMatchExpression(description: "No token present after comparison operator")
        }
        
        let expression: MatchExpression
        // Equals comparison allows for wildcard strings
        if let equalsOperator = infixOperator as? EqualsSymbol {
            if secondToken.type == .identifier {
                let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
                if let thirdToken = remainingTokens.first, thirdToken.type == .wildcard { // constant*
                    let wildcardSymbol = WildcardSymbol(sourceToken: remainingTokens.removeFirst())
                    expression = .infixEquals(equalsOperator, .postfixWildcard(stringSymbol, wildcardSymbol))
                } else { // constant
                    expression = .infix(equalsOperator, stringSymbol)
                }
            } else if secondToken.type == .wildcard {
                let wildcardSymbol = WildcardSymbol(sourceToken: remainingTokens.removeFirst())
                guard let thirdToken = remainingTokens.first, thirdToken.type == .identifier else {
                    let description = "No identifier token present after wildcard token: \(secondToken)"
                    throw ParserError.invalidMatchExpression(description: description)
                }
                
                let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
                if let fourthToken = remainingTokens.first, fourthToken.type == .wildcard { // *constant*
                    let secondWildcardSymbol = WildcardSymbol(sourceToken: remainingTokens.removeFirst())
                    expression = .infixEquals(equalsOperator, .prefixAndPostfixWildcard(wildcardSymbol,
                                                                                             stringSymbol,
                                                                                             secondWildcardSymbol))
                } else { // *constant
                    expression = .infixEquals(equalsOperator, .prefixWildcard(wildcardSymbol, stringSymbol))
                }
            } else {
                let description = "Token after comparison operator is neither a wildcard nor an identifier. " +
                                  "Token: \(secondToken)."
                throw ParserError.invalidMatchExpression(description: description)
            }
        } else { // All other comparisons only allow for string symbol comparisons (no wildcards)
            guard secondToken.type == .identifier else {
                let description = "Token after comparison operator is not an identifier. Token: \(secondToken)"
                throw ParserError.invalidMatchExpression(description: description)
            }
            expression = .infix(infixOperator, StringSymbol(sourceToken: remainingTokens.removeFirst()))
        }
        
        return (expression, remainingTokens)
    }
    
    var textForm: String {
        switch self {
            case .infix(let infixComparisonOperator, let string):
                return "\(infixComparisonOperator.sourceToken.rawValue) \(string.sourceToken.rawValue)"
            case .infixEquals(_, let wildcardString):
                return "= \(wildcardString.textForm)"
            case .unarySuffix(_):
                return "exists"
        }
    }
    
    var sourceUpperBound: String.Index {
        switch self {
            case .infix(_, let string):         return string.sourceToken.range.upperBound
            case .infixEquals(_, let wildcard): return wildcard.sourceUpperBound
            case .unarySuffix(let exists):      return exists.sourceToken.range.upperBound
        }
    }
}
