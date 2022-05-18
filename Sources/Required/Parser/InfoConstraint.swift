//
//  Info.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-18
//

// The expression
//
//   info [key]match expression
//
// succeeds if the value associated with the top-level key in the code’s info.plist file matches match expression, where
// match expression can include any of the operators listed in Logical Operators and Comparison Operations. For example:
//
//   info [CFBundleShortVersionString] < "17.4"
//
// or
//
//   info [MySpecialMarker] exists
//
// Specify key as a string constant.
public struct InfoConstraint: Statement, StatementDescribable {
    public let infoSymbol: InfoSymbol
    public let key: KeyFragment
    public let match: MatchFragment
    
    static func attemptParse(tokens: [Token]) throws -> (Statement, [Token])? {
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "info" else {
            return nil
        }
        
        var remainingTokens = tokens
        let infoSymbol = InfoSymbol(sourceToken: remainingTokens.removeFirst())
        let keyFragmentResult = try KeyFragment.attemptParse(tokens: remainingTokens)
        remainingTokens = keyFragmentResult.1
        guard let matchResult = try MatchFragment.attemptParse(tokens: remainingTokens) else {
            throw ParserError.invalidInfo(description: "End tokens not a match expression")
        }
        let constraint = InfoConstraint(infoSymbol: infoSymbol, key: keyFragmentResult.0, match: matchResult.0)
        
        return (constraint, matchResult.1)
    }
    
    var description: StatementDescription {
        .constraint(["info"] +  key.description + match.description)
    }
}
