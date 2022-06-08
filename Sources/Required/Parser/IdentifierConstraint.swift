//
//  IdentifierConstraint.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-18
//

// The expression
//   identifier = constant
//
// succeeds if the unique identifier string embedded in the code signature is exactly equal to constant. The equal sign
// is optional in identifier expressions. Signing identifiers can be tested only for exact equality; the wildcard
// character (*) can not be used with the identifier constraint, nor can identifiers be tested for inequality.

/// A constraint on the unique identifier string embedded in the code signature.
public enum IdentifierConstraint: Constraint {
    public static let signifier = "identifier"
    
    /// When equality is explicitly indicated with use of the = symbol.
    case explicitEquality(IdentifierSymbol, EqualsSymbol, StringSymbol)
    
    /// When equality is implicitly indicated without the use of the = symbol.
    case implicitEquality(IdentifierSymbol, StringSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (Requirement, [Token])? {
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "identifier" else {
            return nil
        }
        
        let identifierConstraint: IdentifierConstraint
        var remainingTokens = tokens
        let identifierSymbol = IdentifierSymbol(sourceToken: remainingTokens.removeFirst())
        // Next element must exist and can either be an equality symbol or a string symbol
        guard let secondToken = remainingTokens.first else {
            throw ParserError.invalidIdentifier(description: "No token after identifier")
        }
        if secondToken.type == .equals {
            let equalsOperator = EqualsSymbol(sourceToken: remainingTokens.removeFirst())
            // Third token must be a string symbol
            guard let thirdToken = remainingTokens.first else {
                throw ParserError.invalidIdentifier(description: "No token after identifier =")
            }
            if thirdToken.type == .identifier {
                let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
                identifierConstraint = .explicitEquality(identifierSymbol, equalsOperator, stringSymbol)
            } else {
                throw ParserError.invalidIdentifier(description: "Token after identifier = is not an identifier. " +
                                                                 "Token: \(thirdToken)")
            }
        } else if secondToken.type == .identifier {
            let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
            identifierConstraint = .implicitEquality(identifierSymbol, stringSymbol)
        } else {
            throw ParserError.invalidIdentifier(description: "Token after identifier is not an identifier. " +
                                                             "Token: \(secondToken)")
        }
        
        return (identifierConstraint, remainingTokens)
    }
    
    var identifier: IdentifierSymbol {
        switch self {
            case .explicitEquality(let identifier, _, _):   return identifier
            case .implicitEquality(let identifier, _):      return identifier
        }
    }
    
    var constant: StringSymbol {
        switch self {
            case .explicitEquality(_, _, let string):   return string
            case .implicitEquality(_, let string):      return string
        }
    }
    
    public var textForm: String {
        return "identifier \(constant.sourceToken.rawValue)"
    }
    
    public var sourceRange: Range<String.Index> {
        self.identifier.sourceToken.range.lowerBound..<constant.sourceToken.range.upperBound
    }
}
