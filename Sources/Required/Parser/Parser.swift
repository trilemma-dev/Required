//
//  Parser.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-14
//

public protocol ParseResult {
    func prettyPrint()
}

public struct Parser {
    private init() { }
    
    public static func parse(tokens: [Token]) throws -> ParseResult {
        let strippedTokens = tokens.strippingWhitespaceAndComments()
        if let requirementSet = try RequirementSet.attemptParse(tokens: strippedTokens) {
            return requirementSet
        } else {
            return try parseInternal(tokens: tokens, depth: 0).0
        }
    }
    
    private static func parseInternal(tokens: [Token], depth: UInt) throws -> (Statement, [Token]) {
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
                let parenthesesStatement = ParenthesesStatement(leftParenthesis: leftParenthesis,
                                                                statement: recursionResult.0,
                                                                rightParenthesis: rightParenthesis)
                parsedElements.append(parenthesesStatement)
                
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
        //   Statement (specifically various types which conformt to this protocol)
        //   NegationSymbol
        //   AndSymbol
        //   OrSymbol
        
        // Now it's time to combine these together (if possible) into a valid statement, potentially a deeply nested
        // one, following the logical operator precedence order. In order of decreasing precedence:
        //   ! (negation)
        //   and (logical AND)
        //   or (logical OR)
        parsedElements = try resolveNegations(parsedElements: parsedElements)
        parsedElements = try resolveInfixOperators(parsedElements: parsedElements,
                                                   symbolType: AndSymbol.self) { lhs, symbol, rhs in
            AndStatement(lhs: lhs, andSymbol: symbol, rhs: rhs)
        }
        parsedElements = try resolveInfixOperators(parsedElements: parsedElements,
                                                   symbolType: OrSymbol.self) { lhs, symbol, rhs in
            OrStatement(lhs: lhs, orSymbol: symbol, rhs: rhs)
        }
        
        // If the tokens represent a semanticly valid input, then there should now be exactly one element in
        // parsedElements and it should be a statement. Otherwise, this is not valid.
        guard parsedElements.count == 1, let statement = parsedElements.first as? Statement else {
            throw ParserError.invalid(description: "Tokens could not be resolved to a singular statement")
        }
        
        return (statement, tokens)
    }
    
    private static func resolveNegations(parsedElements: [Any]) throws -> [Any] {
        // Iterates backwards through the parsed elements resolving negations more easily for cases like:
        //    !!info[FooBar] <= hello.world.yeah
        //
        // The first NegationSymbol is a modifier of the NegationStatement containing the second one, so by iterating
        // backwards we can resolve these in place in a single pass.
        var parsedElements = parsedElements
        var currIndex = parsedElements.index(before: parsedElements.endIndex)
        while currIndex >= parsedElements.startIndex {
            let currElement = parsedElements[currIndex]
            let afterCurrIndex = parsedElements.index(after: currIndex)
            let afterCurrElement = afterCurrIndex < parsedElements.endIndex ? parsedElements[afterCurrIndex] : nil
            
            if let negationSymbol = currElement as? NegationSymbol {
                guard let expresion = afterCurrElement as? Statement else {
                    throw ParserError.invalidNegation(description: "! must be followed by an expression")
                }
                
                let negationStatement = NegationStatement(negationSymbol: negationSymbol, statement: expresion)
                
                // Remove the two elements we just turned into the NegationExpression, insert that expression where the
                // first one was located
                parsedElements.remove(at: afterCurrIndex)
                parsedElements.remove(at: currIndex)
                parsedElements.insert(negationStatement, at: currIndex)
            }
            
            // Continue iterating backwards
            currIndex = parsedElements.index(before: currIndex)
        }
        
        return parsedElements
    }
    
    private static func resolveInfixOperators<T: Symbol>(
        parsedElements: [Any],
        symbolType: T.Type, // AndSymbol or OrSymbol
        createCombinedStatment: (Statement, T, Statement) -> Statement // Create AndStatement or OrStatement
    ) throws -> [Any] {
        // Iterate forwards through the elements, creating statements whenever the current element is of type T. This
        // requires the previous and next elements to already be statements; if they're not then the input is invalid.
        var parsedElements = parsedElements
        var currIndex = parsedElements.startIndex
        while currIndex < parsedElements.endIndex {
            let beforeCurrIndex = parsedElements.index(before: currIndex)
            let beforeCurrElement = beforeCurrIndex < parsedElements.startIndex ? nil : parsedElements[beforeCurrIndex]
            let currElement = parsedElements[currIndex]
            let afterCurrIndex = parsedElements.index(after: currIndex)
            let afterCurrElement = afterCurrIndex < parsedElements.endIndex ? parsedElements[afterCurrIndex] : nil
            
            if let symbol = currElement as? T {
                guard let beforeStatement = beforeCurrElement as? Statement,
                      let afterStatement = afterCurrElement as? Statement else {
                          throw ParserError.invalid(description: "\(symbol.sourceToken.rawValue) must be placed " +
                                                    "between two statements")
                }
                
                let combinedStatement = createCombinedStatment(beforeStatement, symbol, afterStatement)
                
                // Remove the three elements we turned into the combined statement, insert that statement where the
                // first one was located
                parsedElements.remove(at: afterCurrIndex)
                parsedElements.remove(at: currIndex)
                parsedElements.remove(at: beforeCurrIndex)
                parsedElements.insert(combinedStatement, at: beforeCurrIndex)
                
                // currIndex now refers to the next element, so don't advance it
            } else {
                currIndex = afterCurrIndex
            }
        }
        
        return parsedElements
    }
}

public enum ParserError: Error {
    case invalid(description: String)
    case invalidToken(description: String)
    
    case invalidRequirementSet(description: String)
    
    case invalidKeyFragment(description: String)
    case invalidMatchFragment(description: String)
    
    case invalidAnd(description: String)
    case invalidOr(description: String)
    case invalidNegation(description: String)
    case invalidIdentifier(description: String)
    case invalidInfo(description: String)
    case invalidCodeDirectoryHash(description: String)
    case invalidCertificate(description: String)
}


public protocol Statement: ParseResult {
    func prettyPrint()
}

public struct ParenthesesStatement: Statement, StatementDescribable {
    let leftParenthesis: Token
    let statement: Statement
    let rightParenthesis: Token
    
    var description: StatementDescription {
        .logicalOperator("()", [(statement as! StatementDescribable).description])
    }
}

public struct NegationStatement: Statement, StatementDescribable {
    let negationSymbol: NegationSymbol
    let statement: Statement
    
    var description: StatementDescription {
        .logicalOperator("!", [(statement as! StatementDescribable).description])
    }
}

public struct AndStatement: Statement, StatementDescribable {
    let lhs: Statement
    let andSymbol: AndSymbol
    let rhs: Statement
    
    var description: StatementDescription {
        .logicalOperator("and", [(lhs as! StatementDescribable).description,
                                 (rhs as! StatementDescribable).description])
    }
}

public struct OrStatement: Statement, StatementDescribable {
    let lhs: Statement
    let orSymbol: OrSymbol
    let rhs: Statement
    
    var description: StatementDescription {
        .logicalOperator("or", [(lhs as! StatementDescribable).description, (rhs as! StatementDescribable).description])
    }
}

// MARK: pretty printing

public extension Statement {
    func prettyPrint() {
        (self as! StatementDescribable).description.prettyPrint()
    }
}

protocol StatementDescribable {
    var description: StatementDescription { get }
}

enum StatementDescription {
    case constraint([String])
    case logicalOperator(String, [StatementDescription])
    
    func prettyPrint() {
        prettyPrintInternal(depth: 0, ancestorDepths: [UInt](), isLastChildOfParent: false)
    }
    
    // Recursively pretty prints
    private func prettyPrintInternal(depth: UInt, ancestorDepths: [UInt], isLastChildOfParent: Bool) {
        // Padding per depth is three characters
        var lineStart = ""
        for i in 0..<depth {
            if i == depth - 1 { // portion right before this element will be displayed
                lineStart += isLastChildOfParent ? "\\--" : "|--"
            } else if ancestorDepths.contains(i) { // whether a | needs to be drawn for an ancestor
                lineStart += "|  "
            } else { // general padding
                lineStart += "   "
            }
        }
         
        switch self {
            case .constraint(let elements):
                print(lineStart + elements.joined(separator:  " "))
            case .logicalOperator(let operation, let children):
                print(lineStart + operation)
                for index in children.indices {
                    var ancestorDepths = ancestorDepths
                    if isLastChildOfParent {
                        ancestorDepths.removeLast()
                    }
                    ancestorDepths += [depth]
                    
                    let isLast = (index == children.index(before: children.endIndex))
                    
                    children[index].prettyPrintInternal(depth: depth + 1,
                                                        ancestorDepths: ancestorDepths,
                                                        isLastChildOfParent: isLast)
                }
        }
    }
}
