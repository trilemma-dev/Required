//
//  NegationRequirement.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-08
//

/// A requirement which negates the evaluation of its child requirement.
public struct NegationRequirement: Requirement {
    public static let signifier = "!"
    
    let negationSymbol: NegationSymbol
    let requirement: Requirement
    
    public var textForm: String {
        "!\(requirement.textForm)"
    }
    
    public var children: [Requirement] {
        [requirement]
    }
    
    public var sourceRange: Range<String.Index> {
        negationSymbol.sourceToken.range.lowerBound..<self.requirement.sourceRange.upperBound
    }
}
