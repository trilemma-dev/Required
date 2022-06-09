//
//  Parser.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-14
//

/// Parses requirements and requirement sets into their abstract syntax tree form.
///
/// These requirements are expected to conform to Apple's
/// [Code Signing Requirement Language](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html#//apple_ref/doc/uid/TP40005929-CH5-SW2).
public struct Parser {
    private init() { }
    
    /// Parses the textual form of a requirement or requirement set.
    ///
    /// No compilation of the requirement occurs as part of parsing meaning the requirement or requirement set may not be valid; for example a referenced
    /// certificate file may not exist which would cause compilation to fail.
    ///
    /// - Parameter text: The textual form of a requirement or requirement set.
    /// - Returns: Either ``ParseResult/requirement(_:)`` or  ``ParseResult/requirementSet(_:)`` depending on the value provided.
    /// - Throws: If the value provided was not a valid requirement or requirement set.
    public static func parse(text: String) throws -> ParseResult {
        try parse(tokens: try Tokenizer.tokenize(text: text))
    }
    
    // Internal implementation based on tokens
    static func parse(tokens: [Token]) throws -> ParseResult {
        let strippedTokens = tokens.strippingWhitespaceAndComments()
        if let requirementSet = try RequirementSet.attemptParse(tokens: strippedTokens) {
            return .requirementSet(requirementSet)
        } else {
            return .requirement(try parseInternal(tokens: strippedTokens, depth: 0).0)
        }
    }
    
    private static func parseInternal(tokens: [Token], depth: UInt) throws -> (Requirement, [Token]) {
        var parsedElements = [Any]()
        var tokens = tokens
        while !tokens.isEmpty {
            let nextToken = tokens.first
            
            if nextToken?.type == .leftParenthesis {
                // Recurse into parsing inside the parantheses
                let leftParenthesis = tokens.removeFirst()
                let recursionResult = try parseInternal(tokens: tokens, depth: depth + 1)
                tokens = recursionResult.1
                
                guard tokens.first?.type == .rightParenthesis else {
                    throw ParserError.invalidToken(description: "( must be matched by )")
                }
                let rightParenthesis = tokens.removeFirst()
                let parenthesesRequirement = ParenthesesRequirement(leftParenthesis: leftParenthesis,
                                                                    requirement: recursionResult.0,
                                                                    rightParenthesis: rightParenthesis)
                parsedElements.append(parenthesesRequirement)
            } else if nextToken?.type == .rightParenthesis {
                if depth == 0 {
                    throw ParserError.invalidToken(description: ") was not matched by a starting (")
                }
                
                // The end of this recursion level has been reached, break out of the loop to return what's been parsed
                break
            } else if nextToken?.type == .negation {
                parsedElements.append(NegationSymbol(sourceToken: tokens.removeFirst()))
            } else if nextToken?.type == .identifier, nextToken?.rawValue == "and" {
                parsedElements.append(AndSymbol(sourceToken: tokens.removeFirst()))
            } else if nextToken?.type == .identifier, nextToken?.rawValue == "or" {
                parsedElements.append(OrSymbol(sourceToken: tokens.removeFirst()))
            } else {
                let parsers = [IdentifierConstraint.attemptParse(tokens:),
                               InfoConstraint.attemptParse(tokens:),
                               EntitlementConstraint.attemptParse(tokens:),
                               CertificateConstraint.attemptParse(tokens:),
                               CodeDirectoryHashConstraint.attemptParse(tokens:)]
                
                let parsedCount = parsedElements.count
                for parser in parsers {
                    if let result = try parser(tokens) {
                        tokens = result.1
                        parsedElements.append(result.0)
                        break
                    }
                }
                guard parsedCount != parsedElements.count else {
                    throw ParserError.invalidToken(description: "Token couldn't be parsed: \(nextToken!)")
                }
            }
        }
        
        // parsedElements should now consist of:
        //   Requirement (specifically various types which conform to this protocol)
        //   NegationSymbol
        //   AndSymbol
        //   OrSymbol
        
        // Now it's time to combine these together (if possible) into a valid requirement, potentially a deeply nested
        // one, following the logical operator precedence order. In order of decreasing precedence:
        //   ! (negation)
        //   and (logical AND)
        //   or (logical OR)
        parsedElements = try resolveNegations(parsedElements: parsedElements)
        parsedElements = try resolveInfixOperators(parsedElements: parsedElements,
                                                   symbolType: AndSymbol.self) { lhs, symbol, rhs in
            AndRequirement(lhs: lhs, andSymbol: symbol, rhs: rhs)
        }
        parsedElements = try resolveInfixOperators(parsedElements: parsedElements,
                                                   symbolType: OrSymbol.self) { lhs, symbol, rhs in
            OrRequirement(lhs: lhs, orSymbol: symbol, rhs: rhs)
        }
        
        // If the tokens represent a semanticly valid input, then there should now be exactly one element in
        // parsedElements and it should be a Requirement. Otherwise, this is not valid.
        guard parsedElements.count == 1, let requirement = parsedElements.first as? Requirement else {
            throw ParserError.invalid(description: "Tokens could not be resolved to a singular requirement")
        }
        
        return (requirement, tokens)
    }
    
    private static func resolveNegations(parsedElements: [Any]) throws -> [Any] {
        // Iterates backwards through the parsed elements resolving negations more easily for cases like:
        //    !!info[FooBar] <= hello.world.yeah
        //
        // The first NegationSymbol is a modifier of the NegationRequirement containing the second one, so by iterating
        // backwards we can resolve these in place in a single pass.
        var parsedElements = parsedElements
        var currIndex = parsedElements.index(before: parsedElements.endIndex)
        while currIndex >= parsedElements.startIndex {
            let currElement = parsedElements[currIndex]
            let afterCurrIndex = parsedElements.index(after: currIndex)
            let afterCurrElement = afterCurrIndex < parsedElements.endIndex ? parsedElements[afterCurrIndex] : nil
            
            if let negationSymbol = currElement as? NegationSymbol {
                guard let expresion = afterCurrElement as? Requirement else {
                    throw ParserError.invalidNegation(description: "! must be followed by an expression")
                }
                
                let negationRequirement = NegationRequirement(negationSymbol: negationSymbol, requirement: expresion)
                
                // Remove the two elements we just turned into the NegationRequirement, insert that expression where the
                // first one was located
                parsedElements.remove(at: afterCurrIndex)
                parsedElements.remove(at: currIndex)
                parsedElements.insert(negationRequirement, at: currIndex)
            }
            
            // Continue iterating backwards
            currIndex = parsedElements.index(before: currIndex)
        }
        
        return parsedElements
    }
    
    private static func resolveInfixOperators<T: Symbol>(
        parsedElements: [Any],
        symbolType: T.Type, // AndSymbol or OrSymbol
        createCombinedRequirement: (Requirement, T, Requirement) -> Requirement // AndRequirement or OrRequirement
    ) throws -> [Any] {
        // Iterate forwards through the elements, creating requirements whenever the current element is of type T. This
        // requires the previous and next elements to already be requirements; if they're not then the input is invalid.
        var parsedElements = parsedElements
        var currIndex = parsedElements.startIndex
        while currIndex < parsedElements.endIndex {
            let beforeCurrIndex = parsedElements.index(before: currIndex)
            let beforeCurrElement = beforeCurrIndex < parsedElements.startIndex ? nil : parsedElements[beforeCurrIndex]
            let currElement = parsedElements[currIndex]
            let afterCurrIndex = parsedElements.index(after: currIndex)
            let afterCurrElement = afterCurrIndex < parsedElements.endIndex ? parsedElements[afterCurrIndex] : nil
            
            if let symbol = currElement as? T {
                guard let beforeRequirement = beforeCurrElement as? Requirement,
                      let afterRequirement = afterCurrElement as? Requirement else {
                      let description = "\(symbol.sourceToken.rawValue) must be placed between two requirements"
                      throw ParserError.invalid(description: description)
                }
                
                let combinedRequirement = createCombinedRequirement(beforeRequirement, symbol, afterRequirement)
                
                // Remove the three elements we turned into the combined requirement, insert that requirement where the
                // first one was located
                parsedElements.remove(at: afterCurrIndex)
                parsedElements.remove(at: currIndex)
                parsedElements.remove(at: beforeCurrIndex)
                parsedElements.insert(combinedRequirement, at: beforeCurrIndex)
                
                // currIndex now refers to the next element, so don't advance it
            } else {
                currIndex = afterCurrIndex
            }
        }
        
        return parsedElements
    }
}

/// The abstract syntax tree result of parsing a requirement or requirement set.
public enum ParseResult {
    /// A ``Requirement`` result.
    case requirement(Requirement)
    
    /// A ``RequirementSet`` result.
    case requirementSet(RequirementSet)
    
    /// The textual representation of this requirement or requirement set.
    ///
    /// The returned string will not necessarily match the initial text provided, for example comments are not preserved, but will be semantically equivalent.
    public var textForm: String {
        switch self {
            case .requirement(let requirement):       return requirement.textForm
            case .requirementSet(let requirementSet): return requirementSet.textForm
        }
    }
    
    /// A description of this parse result which visualizes itself as an ASCII tree.
    ///
    /// The exact format of the returned string is subject to change and is only intended to be used for display purposes.
    ///
    /// The returned description is not valid for parsing purposes, see ``textForm`` if that is needed.
    public var prettyDescription: String {
        switch self {
            case .requirement(let requirement):       return requirement.prettyDescription
            case .requirementSet(let requirementSet): return requirementSet.prettyDescription
        }
    }
}
