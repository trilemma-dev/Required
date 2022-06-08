//
//  Requirement.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-08
//

/// A potentially compilable and evaluatable unit of a code signing requirement.
///
/// Requirements are either:
///  - composed of one or two nested requirements, accessible via the ``children`` property
///  - directly evaluatable and contain no nested requirements making them a leaf node of the requirements tree, in which case they conform to ``Constraint``
public protocol Requirement: CustomStringConvertible {
    /// A textual representation of this requirement.
    ///
    /// The returned string will not necessarily match the initial text provided, for example comments are not preserved, but will be semantically equivalent.
    var textForm: String { get }
    
    /// The range within the initially provided string that represents this requirement.
    ///
    /// Any comments or whitespace that are within the requirement itself will be in this range, any before or after are excluded from the range.
    var sourceRange: Range<String.Index> { get }
    
    /// A generalized textual form of this requirement used for display purposes.
    ///
    /// Unless you are doing your own visualization of a requirement, you'll likely want to use ``prettyDescription``.
    static var signifier: String { get }
    
    /// The child elements of this requirement.
    ///
    /// ``AndRequirement`` and ``OrRequirement`` have two children, while ``NegationRequirement`` and ``ParenthesesRequirement``
    /// have one. ``Constraint``s do not have children and will always return an empty array.
    var children: [Requirement] { get }
}

// MARK: CustomStringConvertible

public extension Requirement {
    var description: String {
        textForm
    }
}

// MARK: Pretty description

public extension Requirement {
    /// A description of this requirement which visualizes itself and its children as an ASCII tree.
    ///
    /// The exact format of the returned string is subject to change and is only intended to be used for display purposes. It currently looks like:
    /// ```
    /// and
    /// |--()
    /// |  \--or
    /// |     |--and
    /// |     |  |--anchor apple generic
    /// |     |  \--certificate leaf[field.1.2.840.113635.100.6.1.9]
    /// |     \--and
    /// |        |--and
    /// |        |  |--and
    /// |        |  |  |--anchor apple generic
    /// |        |  |  \--certificate 1[field.1.2.840.113635.100.6.2.6]
    /// |        |  \--certificate leaf[field.1.2.840.113635.100.6.1.13]
    /// |        \--certificate leaf[subject.OU] = "9JA89QQLNQ"
    /// \--identifier "developer.apple.wwdc-Release"
    /// ```
    ///
    /// The returned description is not a valid requirement for parsing purposes, see ``textForm`` if that is needed.
    var prettyDescription: String {
        self.prettyDescriptionInternal(offset: 0,
                                       depth: 0,
                                       ancestorDepths: [],
                                       isLastChildOfParent: false)
            .map{ $0.1 }
            .joined(separator: "\n")
    }
    
    internal func prettyDescriptionInternal(
        offset: UInt, // Used for requirements that are part of a requirement set
        depth: UInt,
        ancestorDepths: [UInt],
        isLastChildOfParent: Bool
    ) -> [(Requirement, String)] {
        var prettyText = ""
        
        // Apply any explicitly set offset
        for _ in 0..<offset {
            prettyText += " "
        }
        
        // Padding per depth is three characters
        for i in 0..<depth {
            if i == depth - 1 { // portion right before this element will be displayed
                prettyText += isLastChildOfParent ? "\\--" : "|--"
            } else if ancestorDepths.contains(i) { // whether a | needs to be drawn for an ancestor
                prettyText += "|  "
            } else { // general padding
                prettyText += "   "
            }
        }
        
        var childrenPrettyText = [(Requirement, String)]()
        if self.children.isEmpty { // base case - no children
            prettyText += self.textForm
        } else {
            prettyText += type(of: self).signifier
            for index in children.indices {
                var ancestorDepths = ancestorDepths
                if isLastChildOfParent {
                    ancestorDepths.removeLast()
                }
                ancestorDepths += [depth]
                
                let isLast = (index == children.index(before: children.endIndex))
                
                childrenPrettyText += children[index].prettyDescriptionInternal(offset: offset,
                                                                                depth: depth + 1,
                                                                                ancestorDepths: ancestorDepths,
                                                                                isLastChildOfParent: isLast)
            }
        }
        
        return [(self, prettyText)] + childrenPrettyText
    }
}
