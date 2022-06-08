//
//  RequirementSet.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-18
//

public struct RequirementSet {
    /// The set of requirement tags and their associated requirements.
    public let requirements: [RequirementTag : RequirementSetElement]
    
    private static let tagInitializers: [String : (Token) -> RequirementTagSymbol ] =
    [
        "host" : HostSymbol.init(sourceToken:),
        "guest" : GuestSymbol.init(sourceToken:),
        "library" : LibrarySymbol.init(sourceToken:),
        "designated" : DesignatedSymbol.init(sourceToken:)
    ]
    
    static func attemptParse(tokens: [Token]) throws -> RequirementSet? {
        guard let firstToken = tokens.first,
              firstToken.type == .identifier,
              tagInitializers.keys.contains(firstToken.rawValue) else {
            return nil
        }
        
        // All of the indices where the => token appears
        var requirementSetSymbolIndices = [Array<Token>.Index]()
        for index in tokens.indices {
            if tokens[index].type == .requirementSet {
                requirementSetSymbolIndices.append(index)
            }
        }
        
        // No => were found
        guard !requirementSetSymbolIndices.isEmpty else {
            throw ParserError.invalidRequirementSet(description: "There must be between 1 and 4 requirements")
        }
        
        var requirements = [RequirementTag : RequirementSetElement]()
        
        // Note: index is the index into requirementSetSymbolIndices, not the indices stored within it
        for index in requirementSetSymbolIndices.indices {
            // Corresponds to the RequirementSetSymbol
            let currentSetSymbolIndex = requirementSetSymbolIndices[index]
            // Corresponds to the RequirementTagSymbol for the set (if it's valid)
            let currentTagSymbolIndex = tokens.index(before: currentSetSymbolIndex)
            
            // From after the => token to the end of the requirement
            let currentSetRange: Range<Array<Token>.Index>
            // There is no next requirement
            if requirementSetSymbolIndices.index(after: index) >= requirementSetSymbolIndices.endIndex {
                currentSetRange = tokens.index(after: currentSetSymbolIndex)..<tokens.endIndex
            } else { // Goes until the next requirement starts which is one before the RequirementSetSymbol
                let nextSetIndex = requirementSetSymbolIndices[requirementSetSymbolIndices.index(after: index)]
                currentSetRange = tokens.index(after: currentSetSymbolIndex)..<tokens.index(before: nextSetIndex)
            }
            
            guard let tagInitializer = tagInitializers[tokens[currentTagSymbolIndex].rawValue] else {
                let description = "\(tokens[currentTagSymbolIndex].rawValue) is not a valid requirement tag"
                throw ParserError.invalidRequirementSet(description: description)
            }
            
            let tagSymbol = tagInitializer(tokens[currentTagSymbolIndex])
            let setSymbol = RequirementSetSymbol(sourceToken: tokens[currentSetSymbolIndex])
            let requirementTokens = Array(tokens[currentSetRange])
            let parseResult = try Parser.parse(tokens: requirementTokens)
            guard case .requirement(let requirement) = parseResult else {
                throw ParserError.invalidRequirementSet(description: "Invalid requirement for \(tagSymbol)")
            }
            
            let setElement = RequirementSetElement(tagSymbol: tagSymbol,
                                                   setSymbol: setSymbol,
                                                   requirement: requirement)
            requirements[tagSymbol.requirementTag] = setElement
        }
        
        return RequirementSet(requirements: requirements)
    }
    
    /// The textual representation of this requirement set.
    ///
    /// The returned string will not necessarily match the initial text provided, for example comments are not preserved, but will be semantically equivalent.
    public var textForm: String {
        var textForms = [String]()
        for element in requirements.values {
            let textForm = [element.tagSymbol.sourceToken.rawValue,
                            element.setSymbol.sourceToken.rawValue,
                            element.requirement.textForm].joined(separator: " ")
            textForms.append(textForm)
        }
        
        return textForms.joined(separator: " ")
    }
    
    /// A description of this requirement set which visualizes itself as one or more ASCII trees.
    ///
    /// The exact format of the returned string is subject to change and is only intended to be used for display purposes. It currenty looks like:
    /// ```
    /// host => and
    /// |--anchor apple
    /// \--identifier com.apple.perl
    ///
    /// designated => entitlement["com.apple.security.app-sandbox"] exists
    /// ```
    /// 
    /// The returned description is not a valid requirement for parsing purposes, see ``textForm`` if that is needed.
    public var prettyDescription: String {
        var prettyTexts = [String]()        
        for requirement in requirements.values {
            let tagAndSet = "\(requirement.tagSymbol) \(requirement.setSymbol) "
            var prettyText = requirement.requirement.prettyDescriptionInternal(offset: UInt(tagAndSet.count),
                                                                               depth: 0,
                                                                               ancestorDepths: [],
                                                                               isLastChildOfParent: false)
                                                    .map{ $0.1 }
                                                    .joined(separator: "\n")
            // The string computed from prettyDescriptionInternal(...) will have every line in it padded out with spaces
            // by tagAndSet's length. For the first line, we want to replace that whitespace with tagAndSet itself.
            let range = prettyText.startIndex..<prettyText.index(prettyText.startIndex, offsetBy: tagAndSet.count)
            prettyText.replaceSubrange(range, with: tagAndSet)
            prettyTexts.append(prettyText)
        }
        
        return prettyTexts.joined(separator: "\n\n")
    }
}

extension RequirementSet: CustomStringConvertible {
    public var description: String {
        textForm
    }
}

public enum RequirementTag {
    case host
    case guest
    case library
    case designated
}

public struct RequirementSetElement {
    public let tagSymbol: RequirementTagSymbol
    public let setSymbol: RequirementSetSymbol
    public let requirement: Requirement
}
