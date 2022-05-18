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
public enum IdentifierConstraint: Statement, StatementDescribable {
    case explicitEquality(IdentifierSymbol, EqualsSymbol, StringSymbol)
    case implicitEquality(IdentifierSymbol, StringSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (Statement, [Token])? {
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
    
    var constant: StringSymbol {
        switch self {
            case .explicitEquality(_, _, let stringSymbol):
                return stringSymbol
            case .implicitEquality(_, let stringSymbol):
                return stringSymbol
        }
    }
    
    var description: StatementDescription {
        switch self {
            case .explicitEquality(_, _, let stringSymbol):
                return .constraint(["identifier", "=", stringSymbol.value ])
            case .implicitEquality(_, let stringSymbol):
                return .constraint(["identifier", stringSymbol.value])
        }
    }
}
