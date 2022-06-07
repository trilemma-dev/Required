//
//  Token.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-03
//

/// A lexical token for the Code Sign Requirement Language.
///
/// This token has no semantic meaning, it exists as intermediate step which is fed into the parser.
public struct Token: Equatable {
    let type: TokenType
    
    /// The original text value this token represents.
    public let rawValue: String
    
    /// The range this token represents in the textual representation of the requirement or requirement set.
    public let range: Range<String.Index>
}

// Pretty prints the token to aid in debugging.
extension Token: CustomStringConvertible {
    public var description: String {
        switch type {
            case .whitespace:
                if rawValue == " " {
                    return "whitespace [space] [\(range.lowerBound)]"
                } else if rawValue == "\t" {
                    return "whitespace [tab]"
                } else if rawValue == "\n" {
                    return "whitespace [new line]"
                } else {
                    fatalError("Unknown whitespace")
                }
            case .comment:
                return "comment [length: \(rawValue.count)] [\(range.lowerBound)]"
            default:
                return "\(type) \(rawValue)"
        }
    }
}
