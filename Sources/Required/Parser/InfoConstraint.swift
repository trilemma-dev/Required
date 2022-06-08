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

/// A constraint on the value corresponding to a key in the code's Info.plist file.
public struct InfoConstraint: Constraint {
    public static let signifier = "info"
    
    /// The symbol for the `info` keyword.
    public let infoSymbol: InfoSymbol
    
    /// The expression for the key portion of this constraint.
    public let key: KeyExpression
    
    /// The expression for the match portion of this constraint.
    public let match: MatchExpression
    
    static func attemptParse(tokens: [Token]) throws -> (Requirement, [Token])? {
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "info" else {
            return nil
        }
        
        var remainingTokens = tokens
        let infoSymbol = InfoSymbol(sourceToken: remainingTokens.removeFirst())
        let keyFragmentResult = try KeyExpression.attemptParse(tokens: remainingTokens)
        remainingTokens = keyFragmentResult.1
        guard let matchResult = try MatchExpression.attemptParse(tokens: remainingTokens) else {
            throw ParserError.invalidInfo(description: "End tokens not a match expression")
        }
        let constraint = InfoConstraint(infoSymbol: infoSymbol, key: keyFragmentResult.0, match: matchResult.0)
        
        return (constraint, matchResult.1)
    }
    
    public var textForm: String {
        return "info\(key.textForm) \(match.textForm)"
    }
    
    public var sourceRange: Range<String.Index> {
        infoSymbol.sourceToken.range.lowerBound..<match.sourceUpperBound
    }
}
