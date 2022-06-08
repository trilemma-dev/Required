//
//  CodeDirectoryHashConstraint.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-18
//

// The expression
//
//   cdhash hash-constant
//
// computes the canonical hash of the program’s CodeDirectory resource and succeeds if the value of this hash exactly
// equals the specified hash constant.

/// A constraint on the canonical hash of the program's CodeDirectory resource.
public struct CodeDirectoryHashConstraint: Constraint {
    
    public static let signifier = "cdhash"
    
    /// The symbol for the `cdhash` keyword.
    public let codeDirectoryHashSymbol: CodeDirectoryHashSymbol
    
    /// The symbol for the hash constant.
    public let hashConstantSymbol: HashConstantSymbol
    
    static func attemptParse(tokens: [Token]) throws -> (Requirement, [Token])? {
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "cdhash" else {
            return nil
        }
        
        var remainingTokens = tokens
        let cdHashSymbol = CodeDirectoryHashSymbol(sourceToken: remainingTokens.removeFirst())
        guard remainingTokens.first?.type == .hashConstant else {
            throw ParserError.invalidCodeDirectoryHash(description: "Token after cdhash is not a hash constant: \(remainingTokens)")
        }
        let hashConstantSymbol = HashConstantSymbol(sourceToken: remainingTokens.removeFirst())
        
        return (CodeDirectoryHashConstraint(codeDirectoryHashSymbol: cdHashSymbol,
                                           hashConstantSymbol: hashConstantSymbol), remainingTokens)
    }
    
    public var textForm: String {
        return "cdhash \(hashConstantSymbol.sourceToken.rawValue)"
    }
    
    public var sourceRange: Range<String.Index> {
        codeDirectoryHashSymbol.sourceToken.range.lowerBound..<hashConstantSymbol.sourceToken.range.upperBound
    }
}
