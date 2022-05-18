//
//  EntitlementConstraint.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-18
//

public struct EntitlementConstraint: Statement, StatementDescribable {
    public let entitlementSymbol: EntitlementSymbol
    public let key: KeyFragment
    public let match: MatchFragment
    
    static func attemptParse(tokens: [Token]) throws -> (Statement, [Token])? {
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "entitlement" else {
            return nil
        }
        
        var remainingTokens = tokens
        let infoSymbol = EntitlementSymbol(sourceToken: remainingTokens.removeFirst())
        let keyFragmentResult = try KeyFragment.attemptParse(tokens: remainingTokens)
        remainingTokens = keyFragmentResult.1
        guard let matchResult = try MatchFragment.attemptParse(tokens: remainingTokens) else {
            throw ParserError.invalidInfo(description: "End tokens not a match expression")
        }
        let constraint = EntitlementConstraint(entitlementSymbol: infoSymbol,
                                               key: keyFragmentResult.0,
                                               match: matchResult.0)
        
        return (constraint, matchResult.1)
    }
    
    var description: StatementDescription {
        .constraint(["entitlement"] +  key.description + match.description)
    }
}
