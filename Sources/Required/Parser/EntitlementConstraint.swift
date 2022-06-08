//
//  EntitlementConstraint.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-18
//

/// A constraint on the value corresponding to a key in the signature’s embedded entitlement dictionary.
public struct EntitlementConstraint: Constraint {
    
    public static let signifier = "entitlement"
    
    /// The symbol for the `entitlement` keyword.
    public let entitlementSymbol: EntitlementSymbol
    
    /// The expression for the key portion of this constraint.
    public let key: KeyExpression
    
    /// The expression for the match portion of this constraint.
    public let match: MatchExpression
    
    static func attemptParse(tokens: [Token]) throws -> (Requirement, [Token])? {
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "entitlement" else {
            return nil
        }
        
        var remainingTokens = tokens
        let infoSymbol = EntitlementSymbol(sourceToken: remainingTokens.removeFirst())
        let keyFragmentResult = try KeyExpression.attemptParse(tokens: remainingTokens)
        remainingTokens = keyFragmentResult.1
        guard let matchResult = try MatchExpression.attemptParse(tokens: remainingTokens) else {
            throw ParserError.invalidInfo(description: "End tokens not a match expression")
        }
        let constraint = EntitlementConstraint(entitlementSymbol: infoSymbol,
                                               key: keyFragmentResult.0,
                                               match: matchResult.0)
        
        return (constraint, matchResult.1)
    }
    
    public var textForm: String {
        return "entitlement\(key.textForm) \(match.textForm)"
    }
    
    public var sourceRange: Range<String.Index> {
        entitlementSymbol.sourceToken.range.lowerBound..<match.sourceUpperBound
    }
}
