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
public enum CodeDirectoryHashConstraint: Statement, StatementDescribable {
    case filePath(CodeDirectoryHashSymbol, StringSymbol)
    case hashConstant(CodeDirectoryHashSymbol, HashConstantSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (Statement, [Token])? {
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "cdhash" else {
            return nil
        }
        
        var remainingTokens = tokens
        let cdHashSymbol = CodeDirectoryHashSymbol(sourceToken: remainingTokens.removeFirst())
        if remainingTokens.first?.type == .hashConstant { // hash constant
            let hashConstantSymbol = HashConstantSymbol(sourceToken: remainingTokens.removeFirst())
            
            return (CodeDirectoryHashConstraint.hashConstant(cdHashSymbol, hashConstantSymbol), remainingTokens)
        } else if remainingTokens.first?.type == .identifier { // could be a path
            // It's intentional no actual validation is happening as to whether this identifier is actually a path. The
            // full validation would happen as part of compilation whether this value needs to be a valid path, the path
            // needs to exist on disk, and the path needs to refer to to a file containing an X.509 DER encoded
            // certificate. However, none of that needs to be true to build a valid syntax tree.
            let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
            
            return (CodeDirectoryHashConstraint.filePath(cdHashSymbol, stringSymbol), remainingTokens)
        } else {
            throw ParserError.invalidCodeDirectoryHash(description: "Token after cdhash is not a hash " +
                                                                "constant or an identifier")
        }
    }
    
    var description: StatementDescription {
        switch self {
            case .filePath(_, let stringSymbol):
                return .constraint(["cdhash", stringSymbol.value])
            case .hashConstant(_, let hashConstantSymbol):
                return .constraint(["cdhash", hashConstantSymbol.value])
        }
    }
}
