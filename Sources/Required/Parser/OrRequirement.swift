//
//  OrRequirement.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-08
//

/// A requirement which successfully evalutes if one or both of its child requirements do.
public struct OrRequirement: Requirement {
    public static let signifier = "or"
    
    let lhs: Requirement
    let orSymbol: OrSymbol
    let rhs: Requirement
    
    public var textForm: String {
        return "\(lhs.textForm) or \(rhs.textForm)"
    }
    
    public var children: [Requirement] {
        [lhs, rhs]
    }
    
    public var sourceRange: Range<String.Index> {
        lhs.sourceRange.lowerBound..<rhs.sourceRange.upperBound
    }
}
