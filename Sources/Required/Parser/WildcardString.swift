//
//  WildcardString.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-09
//

/// A wildcard string matches substrings of string constants.
public enum WildcardString {
    /// The matched string must end with this string symbol.
    case prefixWildcard(WildcardSymbol, StringSymbol)
    
    /// The matched string must begin with this string symbol.
    case postfixWildcard(StringSymbol, WildcardSymbol)
    
    /// The matched string must contain this string symbol.
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
    
    var textForm: String {
        switch self {
            case .prefixWildcard(_, let string):
                return "*\(string.sourceToken.rawValue)"
            case .postfixWildcard(let string, _):
                return "\(string.sourceToken.rawValue)*"
            case .prefixAndPostfixWildcard(_, let string, _):
                return "*\(string.sourceToken.rawValue)*"
        }
    }
    
    var sourceUpperBound: String.Index {
        switch self {
            case .prefixWildcard(_, let string):
                return string.sourceToken.range.upperBound
            case .postfixWildcard(_, let wildcard):
                return wildcard.sourceToken.range.upperBound
            case .prefixAndPostfixWildcard(_, _, let wildcard):
                return wildcard.sourceToken.range.upperBound
        }
    }
}
