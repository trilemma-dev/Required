//
//  KeyExpression.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-09
//

/// A key expression for an entitlement or info constraint.
///
/// Examples include:
/// - `["com.apple.security.app-sandbox"]`
/// - `[CFBundleVersion]`
public struct KeyExpression {
    /// The opening bracket for the key expression.
    public let leftBracket: Token
    
    /// The key as a string symbol.
    public let keySymbol: StringSymbol
    
    /// The closing bracket for the key expression.
    public let rightBracket: Token
    
    static func attemptParse(tokens: [Token]) throws -> (KeyExpression, [Token]) {
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
        
        return (KeyExpression(leftBracket: leftBracket, keySymbol: keySymbol, rightBracket: rightBracket),
                remainingTokens)
    }
    
    var value: String {
        keySymbol.value
    }
    
    var textForm: String {
        return "[\(keySymbol.sourceToken.rawValue)]"
    }
}
