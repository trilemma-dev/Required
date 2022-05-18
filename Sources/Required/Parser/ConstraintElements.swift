//
//  ConstraintElements.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-18
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
public enum MatchFragment {
    case infix(InfixComparisonOperatorSymbol, StringSymbol)
    case infixEquals(EqualsSymbol, WildcardString)
    case unarySuffix(ExistsSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (MatchFragment, [Token])? {
        guard let firstToken = tokens.first else {
            return nil
        }
        var remainingTokens = tokens
        
        // unarySuffix - exists
        if firstToken.type == .identifier, firstToken.rawValue == "exists" {
            let existsOperator = ExistsSymbol(sourceToken: remainingTokens.removeFirst())
            
            return (.unarySuffix(existsOperator), remainingTokens)
        }
        
        // infix or not a match fragment
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
            // Not a comparison operator, so can't be parsed as a match fragment
            default:
                return nil
        }
        
        guard let secondToken = remainingTokens.first else {
            throw ParserError.invalidMatchFragment(description: "No token present after comparison operator")
        }
        
        let fragment: MatchFragment
        // Equals comparison allows for wildcard strings
        if let equalsOperator = infixOperator as? EqualsSymbol {
            if secondToken.type == .identifier {
                let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
                if let thirdToken = remainingTokens.first, thirdToken.type == .wildcard { // constant*
                    let wildcardSymbol = WildcardSymbol(sourceToken: remainingTokens.removeFirst())
                    fragment = .infixEquals(equalsOperator, .postfixWildcard(stringSymbol, wildcardSymbol))
                } else { // constant
                    fragment = .infix(equalsOperator, stringSymbol)
                }
            } else if secondToken.type == .wildcard {
                let wildcardSymbol = WildcardSymbol(sourceToken: remainingTokens.removeFirst())
                guard let thirdToken = remainingTokens.first, thirdToken.type == .identifier else {
                    throw ParserError.invalidMatchFragment(description: "No identifier token present after wildcard " +
                                                            "token: \(secondToken)")
                }
                
                let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
                if let fourthToken = remainingTokens.first, fourthToken.type == .wildcard { // *constant*
                    let secondWildcardSymbol = WildcardSymbol(sourceToken: remainingTokens.removeFirst())
                    fragment = .infixEquals(equalsOperator, .prefixAndPostfixWildcard(wildcardSymbol,
                                                                                             stringSymbol,
                                                                                             secondWildcardSymbol))
                } else { // *constant
                    fragment = .infixEquals(equalsOperator, .prefixWildcard(wildcardSymbol, stringSymbol))
                }
            } else {
                throw ParserError.invalidMatchFragment(description: "Token after comparison operator neither a " +
                                                        "wildcard nor an identifier. Token: \(secondToken).")
            }
        } else { // All other comparisons only allow for string symbol comparisons (no wildcards)
            guard secondToken.type == .identifier else {
                throw ParserError.invalidMatchFragment(description: "Token after comparison operator is not " +
                                                        "an identifier. Token: \(secondToken)")
            }
            fragment = .infix(infixOperator, StringSymbol(sourceToken: remainingTokens.removeFirst()))
        }
        
        return (fragment, remainingTokens)
    }
    
    
    var description: [String] {
        switch self {
            case .infix(let infixComparisonOperator, let stringSymbol):
                return [infixComparisonOperator.sourceToken.rawValue, stringSymbol.value]
            case .infixEquals(_, let wildcardString):
                return ["="] + wildcardString.description
            case .unarySuffix(_):
                return ["exists"]
        }
    }
}

public enum WildcardString {
    case prefixWildcard(WildcardSymbol, StringSymbol)
    case postfixWildcard(StringSymbol, WildcardSymbol)
    case prefixAndPostfixWildcard(WildcardSymbol, StringSymbol, WildcardSymbol)
    
    var description: [String] {
        switch self {
            case .prefixWildcard(_, let stringSymbol):
                return ["*", stringSymbol.value]
            case .postfixWildcard(let stringSymbol, _):
                return [stringSymbol.value, "*"]
            case .prefixAndPostfixWildcard(_, let stringSymbol, _):
                return ["*", stringSymbol.value, "*"]
        }
    }
}

public typealias ElementFragment = KeyFragment

public struct KeyFragment {
    public let leftBracket: Token
    public let keySymbol: StringSymbol
    public let rightBracket: Token
    
    static func attemptParse(tokens: [Token]) throws -> (KeyFragment, [Token]) {
        var remainingTokens = tokens
        
        guard remainingTokens.first?.type == .leftBracket else {
            throw ParserError.invalidKeyFragment(description: "First token is not [")
        }
        let leftBracket = remainingTokens.removeFirst()
        
        guard remainingTokens.first?.type == .identifier else {
            throw ParserError.invalidKeyFragment(description: "Second token is not an identifier")
        }
        let keySymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
        
        guard remainingTokens.first?.type == .rightBracket else {
            throw ParserError.invalidKeyFragment(description: "Third token is not ]")
        }
        let rightBracket = remainingTokens.removeFirst()
        
        return (KeyFragment(leftBracket: leftBracket, keySymbol: keySymbol, rightBracket: rightBracket),
                remainingTokens)
    }
    
    var value: String {
        keySymbol.value
    }
    
    var description: [String] {
        return ["[", keySymbol.value, "]"]
    }
}
