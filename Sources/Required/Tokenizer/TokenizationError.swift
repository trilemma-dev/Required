//
//  TokenizationError.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-03
//

/// An error when tokenizing (lexing) a requirements string.
struct TokenizationError: Error {
    /// The requirement string which could not be tokenized successfully.
    let requirement: String
    
    /// The index in the `requirement` String at which tokenization failed.
    let failureIndex: String.Index
    
    /// The portion of the `requirement` string which failed to be tokenized.
    public var nonTokenizedPortion: String {
        String(requirement[failureIndex..<requirement.endIndex])
    }
    
    /// Guidance on why the requirement may be failing to tokenize.
    public var debugGuidance: String {
        if self.nonTokenizedPortion.starts(with: "//") {
            return "// style comments must be terminated with a new line"
        } else if self.nonTokenizedPortion.starts(with: "/*") {
            return "/* */ style comments must be terminated with */"
        } else if self.nonTokenizedPortion.starts(with: "H\"") {
            return "Hash constants beginning with H\" must be terminated with \""
        } else if self.nonTokenizedPortion.starts(with: "/") {
            return "Unquoted absolute file paths starting with a / may only contain letters, numbers, and periods"
        } else {
            return "No specific guidance available; check only valid characters have been used"
        }
    }
    
    public var localizedDescription: String {
        "Tokenization failed, non-tokenized portion: \(nonTokenizedPortion)"
    }
}
