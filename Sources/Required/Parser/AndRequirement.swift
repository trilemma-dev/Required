//
//  AndRequirement.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-08
//

/// A requirement which successfully evalutes if both of its child requirements do.
public struct AndRequirement: Requirement {
    
    public static let signifier = "and"
    
    let lhs: Requirement
    let andSymbol: AndSymbol
    let rhs: Requirement
    
    public var textForm: String {
        return "\(lhs.textForm) and \(rhs.textForm)"
    }
    
    public var children: [Requirement] {
        [lhs, rhs]
    }
    
    public var sourceRange: Range<String.Index> {
        lhs.sourceRange.lowerBound..<rhs.sourceRange.upperBound
    }
}
