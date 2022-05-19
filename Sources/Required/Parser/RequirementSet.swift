//
//  RequirementSet.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-18
//

public enum RequirementTag {
    case host
    case guest
    case library
    case designated
}

public struct RequirementSetElement {
    public let tagSymbol: RequirementTagSymbol
    public let setSymbol: RequirementSetSymbol
    public let requirement: Statement
}

public struct RequirementSet: ParseResult {
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
                throw ParserError.invalidRequirementSet(description: "\(tokens[currentTagSymbolIndex].rawValue) is " +
                                                        "not a valid requirement tag")
            }
            
            let tagSymbol = tagInitializer(tokens[currentTagSymbolIndex])
            let setSymbol = RequirementSetSymbol(sourceToken: tokens[currentSetSymbolIndex])
            let requirementTokens = Array(tokens[currentSetRange])
            let parseResult = try Parser.parse(tokens: requirementTokens)
            guard let requirementStatement = parseResult as? Statement else {
                throw ParserError.invalidRequirementSet(description: "Invalid statement for \(tagSymbol)")
            }
            
            let setElement = RequirementSetElement(tagSymbol: tagSymbol,
                                                   setSymbol: setSymbol,
                                                   requirement: requirementStatement)
            requirements[tagSymbol.requirementTag] = setElement
        }
        
        return RequirementSet(requirements: requirements)
    }
    
    public func prettyPrint() {
        for requirement in requirements.values {
            print("\(requirement.tagSymbol) \(requirement.setSymbol)")
            requirement.requirement.prettyPrint()
            print("")
        }
    }
}
