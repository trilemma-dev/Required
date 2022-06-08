//
//  Constraint.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-08
//

import Foundation

/// A constraint is the base case ``Requirement``, it contains no children that are requirements.
public protocol Constraint: Requirement { }

public extension Constraint {
    var children: [Requirement] { [] }
}
