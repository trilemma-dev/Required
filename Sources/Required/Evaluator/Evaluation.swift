//
//  Evaluation.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-19
//

/// Whether a ``Requirement`` was satisfied and if not an explanationf of why it was not.
///
/// The results of an evaluation can be easily visualized with the ``prettyDescription`` property.
public enum Evaluation {
    /// The constraint was satisfied.
    case constraintSatisfied(Constraint)
    
    /// The constraint was not satisified.
    ///
    /// An explanation of why the constraint was not satisfied is provided.
    case constraintNotSatisfied(Constraint, explanation: String)
    
    /// The requirement was satisfied.
    ///
    /// This is only applicable for requirements which are not constraints, meaning they having children evaluations.
    ///
    /// >Note: If this evaluation is for a ``NegationRequirement``, then the `childrenEvaluations` element will not be satisfied.
    case requirementSatisfied(Requirement, children: [Evaluation])
    
    /// The requirement was not satisfied.
    ///
    /// This is only applicable for requirements which are not constraints, meaning they having children evaluations.
    ///
    /// >Note: If this evaluation is for a ``NegationRequirement``, then the `childrenEvaluations` element will be satisfied.
    case requirementNotSatisfied(Requirement, children: [Evaluation])
    
    /// Whether this evaluation was satisfied.
    public var isSatisfied: Bool {
        switch self {
            case .constraintSatisfied(_):           return true
            case .constraintNotSatisfied(_, _):     return false
            case .requirementSatisfied(_, _):       return true
            case .requirementNotSatisfied(_, _):    return false
        }
    }
    
    /// The ``Requirement`` (which may be a ``Constraint``) that was evaluated.
    public var requirement: Requirement {
        switch self {
            case .constraintSatisfied(let constraint):          return constraint
            case .constraintNotSatisfied(let constraint, _):    return constraint
            case .requirementSatisfied(let requirement, _):     return requirement
            case .requirementNotSatisfied(let requirement, _):  return requirement
        }
    }
    
    /// An explanation of whether the valuation was satisfied and if not an explanation of why it was not.
    public var explanation: String {
        switch self {
            case .constraintSatisfied(_): return "This constraint is satifised."
            case .constraintNotSatisfied(_, let explanation): return explanation
            case .requirementSatisfied(_, _): return "This requirement is satisfied."
            case .requirementNotSatisfied(_, _): return "This requirement is not satisfied, see child evaluations."
        }
    }
    
    /// The children evaluations of this evaluation.
    ///
    /// If this evaluation is for a ``Constraint`` then an empty array will be returned.
    public var children: [Evaluation] {
        switch self {
            case .constraintSatisfied(_):                   return []
            case .constraintNotSatisfied(_, _):             return []
            case .requirementSatisfied(_, let children):    return children
            case .requirementNotSatisfied(_, let children): return children
        }
    }
    
    private var depthFirstAllEvaluations: [Evaluation] {
        var evaluations = [self]
        for child in self.children {
            evaluations += child.depthFirstAllEvaluations
        }
        
        return evaluations
    }
    
    /// A description of this evaluation which visualizes itself and its children as an ASCII tree.
    ///
    /// The exact format of the returned string is subject to change and is only intended to be used for display purposes. It currently looks like:
    /// ```
    /// and {true}
    /// |--() {true}
    /// |  \--or {true}
    /// |     |--and {true}
    /// |     |  |--anchor apple generic {true}
    /// |     |  \--certificate leaf[field.1.2.840.113635.100.6.1.9] {true}
    /// |     \--and {false}
    /// |        |--and {false}
    /// |        |  |--and {false}
    /// |        |  |  |--anchor apple generic {true}
    /// |        |  |  \--certificate 1[field.1.2.840.113635.100.6.2.6] {false}¹
    /// |        |  \--certificate leaf[field.1.2.840.113635.100.6.1.13] {false}²
    /// |        \--certificate leaf[subject.OU] = "9JA89QQLNQ" {false}³
    /// \--identifier "developer.apple.wwdc-Release" {true}
    ///
    /// Constraints not satisfied:
    /// 1. The certificate <Apple Worldwide Developer Relations Certification Authority> does not contain OID 1.2.840.113635.100.6.2.6
    /// 2. The certificate <Apple Mac OS Application Signing> does not contain OID 1.2.840.113635.100.6.1.13
    /// 3. Value not present
    /// ```
    public var prettyDescription: String {
        let descriptions = self.requirement.prettyDescriptionInternal(offset: 0,
                                                                      depth: 0,
                                                                      ancestorDepths: [],
                                                                      isLastChildOfParent: false)
        // This works around the fact that Requirement isn't Hashable and so can't be a dictionary key
        // (Conforming to Hashable would be undesirable as then Requirement couldn't be used as a generic constraint)
        var descriptionMap = [Range<String.Index> : String]()
        for description in descriptions {
            descriptionMap[description.0.sourceRange] = description.1
        }
        
        var prettyTexts = [String]()
        var explanations = [String]() // Explanations for constraints that were not satisfied
        for evaluation in depthFirstAllEvaluations {
            var description = descriptionMap[evaluation.requirement.sourceRange]!
            description += " {\(evaluation.isSatisfied)}"
            if !evaluation.isSatisfied && evaluation.children.isEmpty {
                explanations.append(evaluation.explanation)
                description += UInt(explanations.count).superscript
            }
            prettyTexts.append(description)
        }
        
        if !explanations.isEmpty {
            prettyTexts.append("")
            if explanations.count == 1 {
                prettyTexts.append("Constraint not satisfied:")
            } else {
                prettyTexts.append("Constraints not satisfied:")
            }
            
            for i in 0..<explanations.count {
                prettyTexts.append("\(i + 1). \(explanations[i])")
            }
        }
        
        return prettyTexts.joined(separator: "\n")
    }
}

fileprivate extension UInt {
    var superscript: String {
        var superscript = ""
        
        // Loop through each base 10 digit and prepend its corresponding Unicode superscript representation
        var input = self
        while input > 0 {
            switch input % 10 {
                case 0: superscript = "\u{2070}" + superscript
                case 1: superscript = "\u{00B9}" + superscript
                case 2: superscript = "\u{00B2}" + superscript
                case 3: superscript = "\u{00B3}" + superscript
                case 4: superscript = "\u{2074}" + superscript
                case 5: superscript = "\u{2075}" + superscript
                case 6: superscript = "\u{2076}" + superscript
                case 7: superscript = "\u{2077}" + superscript
                case 8: superscript = "\u{2078}" + superscript
                case 9: superscript = "\u{2079}" + superscript
                default: fatalError("Out of range value \(input) for original input \(self)")
            }
            input /= 10
        }
        
        return superscript
    }
}
