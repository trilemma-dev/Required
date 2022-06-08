//
//  ParenthesesRequirement.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-08
//

/// A requirement which evalutes identically to its child requirement.
///
/// Parentheses requirements exist to override operator precedence.
public struct ParenthesesRequirement: Requirement {
    public static let signifier = "()"
    
    let leftParenthesis: Token
    let requirement: Requirement
    let rightParenthesis: Token
    
    public var textForm: String {
        "(\(requirement.textForm))"
    }
    
    public var children: [Requirement] {
        [requirement]
    }
    
    public var sourceRange: Range<String.Index> {
        leftParenthesis.range.lowerBound..<rightParenthesis.range.upperBound
    }
}
