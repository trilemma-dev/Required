//
//  Parser.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-14
//

// Constants:
//   String
//     In some circumstances, can include wildcard operators
//   Integer
//   Hash

// Comparison Operators:
//   = (equals)
//   < (less than)
//   > (greater than)
//   <= (less than or equal to)
//   >= (greater than or equal to)
//   exists (value is present)

// Constraints:
//   Identifier
//   Info
//   Certificate
//   Entitlement
//   Code Directory Hash

// Logical Operators
//   ! (negation)
//   and (logical AND)
//   or (logical OR)
//
//   Above is in order of decreasing precedence; parentheses can be used to override the precedence of the operators.

// TODO: add support for requirement sets
// Requirement Sets
//   tag => requirement
//
// All of the above make up a requirement

public struct Parser {
    private init() { }
    
    public static func parse(tokens: [Token]) throws -> Statement {
        try parseInternal(tokens: tokens.strippingWhitespaceAndComments(), depth: 0).0
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

public protocol Statement {
    func prettyPrint()
}

public extension Statement {
    func prettyPrint() {
        (self as! StatementDescribable).description.prettyPrint()
    }
}

protocol StatementDescribable {
    var description: StatementDescription { get }
}

public protocol Symbol: CustomStringConvertible {
    var sourceToken: Token { get }
}

extension Symbol {
    public var description: String {
        self.sourceToken.rawValue
    }
}

public struct NegationStatement: Statement, StatementDescribable {
    let negationSymbol: NegationSymbol
    let statement: Statement
    
    var description: StatementDescription {
        .logicalOperator("!", [(statement as! StatementDescribable).description])
    }
}

public struct NegationSymbol: Symbol {
    public let sourceToken: Token
}

public struct ParenthesesStatement: Statement, StatementDescribable {
    let leftParenthesis: Token
    let statement: Statement
    let rightParenthesis: Token
    
    var description: StatementDescription {
        .logicalOperator("()", [(statement as! StatementDescribable).description])
    }
}

public struct AndSymbol: Symbol {
    public let sourceToken: Token
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

public struct OrSymbol: Symbol {
    public let sourceToken: Token
}

public struct OrStatement: Statement, StatementDescribable {
    let lhs: Statement
    let orSymbol: OrSymbol
    let rhs: Statement
    
    var description: StatementDescription {
        .logicalOperator("or", [(lhs as! StatementDescribable).description,
                                (rhs as! StatementDescribable).description])
    }
}

// From Apple:
//   In match expressions (see Info, Part of a Certificate, and Entitlement), substrings of string constants can be
//   matched by using the * wildcard character.
//
//   Info:
//     where match expression can include any of the operators listed in Logical Operators and Comparison Operations
//
//   Certificate:
//     where match expression can include the * wildcard character and any of the operators listed in Logical Operators
//     and Comparison Operations
//
//   Entitlement:
//     where match expression can include the * wildcard character and any of the operators listed in Logical Operators
//     and Comparison Operations
//
//   Logical Operators:
//     ! (negation)
//     and (logical AND)
//     or (logical OR)
//
//   Comparison Operators:
//     = (equals)
//     < (less than)
//     > (greater than)
//     <= (less than or equal to)
//     >= (greater than or equal to)
//     exists (value is present)
//
//   Examples shown throughout:
//     thunderbolt = *thunder*
//     thunderbolt = thunder*
//     thunderbolt = *bolt
//     info [CFBundleShortVersionString] < "17.4"
//     info [MySpecialMarker] exists
//
// Interpretation:
//  - The logical operators can't actually be used in match expression (and there are no examples showing how to do so)
//  - The wildcard character can only be used with equality comparison
//  - The lack of wildcard character mentions for info dictionaries is an oversight, not behavioral difference
//  - Only string constants (plus wildcards) can be matched against
//    - Based on testing, hash constants are only for `cdhash` and integer constants for cert position
public enum MatchFragment {
    case infix(InfixComparisonOperatorSymbol, StringSymbol)
    case infixEquals(EqualsSymbol, WildcardString)
    case unarySuffix(ExistsSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (MatchFragment, [Token])? {
        guard let firstToken = tokens.first else {
            return nil
        }
        var remainingTokens = tokens
        
        // unarySuffix - exists
        if firstToken.type == .identifier, firstToken.rawValue == "exists" {
            let existsOperator = ExistsSymbol(sourceToken: remainingTokens.removeFirst())
            
            return (.unarySuffix(existsOperator), remainingTokens)
        }
        
        // infix or not a match fragment
        let infixOperator: InfixComparisonOperatorSymbol
        switch firstToken.type {
            case .equals:
                infixOperator = EqualsSymbol(sourceToken: remainingTokens.removeFirst())
            case .lessThan:
                infixOperator = LessThanSymbol(sourceToken: remainingTokens.removeFirst())
            case .greaterThan:
                infixOperator = GreaterThanSymbol(sourceToken: remainingTokens.removeFirst())
            case .lessThanOrEqualTo:
                infixOperator = LessThanOrEqualToSymbol(sourceToken: remainingTokens.removeFirst())
            case .greaterThanOrEqualTo:
                infixOperator = GreaterThanOrEqualToSymbol(sourceToken: remainingTokens.removeFirst())
            // Not a comparison operator, so can't be parsed as a match fragment
            default:
                return nil
        }
        
        guard let secondToken = remainingTokens.first else {
            throw ParserError.invalidMatchFragment(description: "No token present after comparison operator")
        }
        
        let fragment: MatchFragment
        // Equals comparison allows for wildcard strings
        if let equalsOperator = infixOperator as? EqualsSymbol {
            if secondToken.type == .identifier {
                let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
                if let thirdToken = remainingTokens.first, thirdToken.type == .wildcard { // constant*
                    let wildcardSymbol = WildcardSymbol(sourceToken: remainingTokens.removeFirst())
                    fragment = .infixEquals(equalsOperator, .postfixWildcard(stringSymbol, wildcardSymbol))
                } else { // constant
                    fragment = .infix(equalsOperator, stringSymbol)
                }
            } else if secondToken.type == .wildcard {
                let wildcardSymbol = WildcardSymbol(sourceToken: remainingTokens.removeFirst())
                guard let thirdToken = remainingTokens.first, thirdToken.type == .identifier else {
                    throw ParserError.invalidMatchFragment(description: "No identifier token present after wildcard " +
                                                            "token: \(secondToken)")
                }
                
                let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
                if let fourthToken = remainingTokens.first, fourthToken.type == .wildcard { // *constant*
                    let secondWildcardSymbol = WildcardSymbol(sourceToken: remainingTokens.removeFirst())
                    fragment = .infixEquals(equalsOperator, .prefixAndPostfixWildcard(wildcardSymbol,
                                                                                             stringSymbol,
                                                                                             secondWildcardSymbol))
                } else { // *constant
                    fragment = .infixEquals(equalsOperator, .prefixWildcard(wildcardSymbol, stringSymbol))
                }
            } else {
                throw ParserError.invalidMatchFragment(description: "Token after comparison operator neither a " +
                                                        "wildcard nor an identifier. Token: \(secondToken).")
            }
        } else { // All other comparisons only allow for string symbol comparisons (no wildcards)
            guard secondToken.type == .identifier else {
                throw ParserError.invalidMatchFragment(description: "Token after comparison operator is not " +
                                                        "an identifier. Token: \(secondToken)")
            }
            fragment = .infix(infixOperator, StringSymbol(sourceToken: remainingTokens.removeFirst()))
        }
        
        return (fragment, remainingTokens)
    }
    
    
    var description: [String] {
        switch self {
            case .infix(let infixComparisonOperator, let stringSymbol):
                return [infixComparisonOperator.sourceToken.rawValue, stringSymbol.value]
            case .infixEquals(_, let wildcardString):
                return ["="] + wildcardString.description
            case .unarySuffix(_):
                return ["exists"]
        }
    }
}

public protocol InfixComparisonOperatorSymbol: Symbol { }

public struct EqualsSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

public struct LessThanSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

public struct GreaterThanSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

public struct LessThanOrEqualToSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

public struct GreaterThanOrEqualToSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

public struct ExistsSymbol: Symbol {
    public let sourceToken: Token
}

public enum WildcardString {
    case prefixWildcard(WildcardSymbol, StringSymbol)
    case postfixWildcard(StringSymbol, WildcardSymbol)
    case prefixAndPostfixWildcard(WildcardSymbol, StringSymbol, WildcardSymbol)
    
    var description: [String] {
        switch self {
            case .prefixWildcard(_, let stringSymbol):
                return ["*", stringSymbol.value]
            case .postfixWildcard(let stringSymbol, _):
                return [stringSymbol.value, "*"]
            case .prefixAndPostfixWildcard(_, let stringSymbol, _):
                return ["*", stringSymbol.value, "*"]
        }
    }
}

public struct StringSymbol: Symbol {
    public let sourceToken: Token
    public let rawValue: String
    public let value: String
    
    init(sourceToken: Token) {
        self.sourceToken = sourceToken
        self.rawValue = sourceToken.rawValue
        
        if self.rawValue.hasPrefix("\""), self.rawValue.hasSuffix("\"") {
            let secondIndex = self.rawValue.index(after: rawValue.startIndex)
            let secondToLastIndex = self.rawValue.index(before: rawValue.endIndex)
            self.value = String(self.rawValue[secondIndex..<secondToLastIndex])
        } else {
            self.value = self.rawValue
        }
    }
}

public struct WildcardSymbol: Symbol {
    public let sourceToken: Token
}

// MARK: Info

// TODO: make this more generic so it can also be used for entitlements?

// The expression
//
//   info [key]match expression
//
// succeeds if the value associated with the top-level key in the code’s info.plist file matches match expression, where
// match expression can include any of the operators listed in Logical Operators and Comparison Operations. For example:
//
//   info [CFBundleShortVersionString] < "17.4"
//
// or
//
//   info [MySpecialMarker] exists
//
// Specify key as a string constant.

public struct InfoConstraint: Statement, StatementDescribable {
    public let infoSymbol: InfoSymbol
    public let key: KeyFragment
    public let match: MatchFragment
    
    static func attemptParse(tokens: [Token]) throws -> (Statement, [Token])? {
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "info" else {
            return nil
        }
        
        var remainingTokens = tokens
        let infoSymbol = InfoSymbol(sourceToken: remainingTokens.removeFirst())
        let keyFragmentResult = try KeyFragment.attemptParse(tokens: remainingTokens)
        remainingTokens = keyFragmentResult.1
        guard let matchResult = try MatchFragment.attemptParse(tokens: remainingTokens) else {
            throw ParserError.invalidInfo(description: "End tokens not a match expression")
        }
        let constraint = InfoConstraint(infoSymbol: infoSymbol, key: keyFragmentResult.0, match: matchResult.0)
        
        return (constraint, matchResult.1)
    }
    
    var description: StatementDescription {
        .constraint(["info"] +  key.description + match.description)
    }
}

public struct InfoSymbol: Symbol {
    public let sourceToken: Token
}

// MARK: entitlement

public struct EntitlementConstraint: Statement, StatementDescribable {
    public let entitlementSymbol: EntitlementSymbol
    public let key: KeyFragment
    public let match: MatchFragment
    
    static func attemptParse(tokens: [Token]) throws -> (Statement, [Token])? {
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "entitlement" else {
            return nil
        }
        
        var remainingTokens = tokens
        let infoSymbol = EntitlementSymbol(sourceToken: remainingTokens.removeFirst())
        let keyFragmentResult = try KeyFragment.attemptParse(tokens: remainingTokens)
        remainingTokens = keyFragmentResult.1
        guard let matchResult = try MatchFragment.attemptParse(tokens: remainingTokens) else {
            throw ParserError.invalidInfo(description: "End tokens not a match expression")
        }
        let constraint = EntitlementConstraint(entitlementSymbol: infoSymbol,
                                               key: keyFragmentResult.0,
                                               match: matchResult.0)
        
        return (constraint, matchResult.1)
    }
    
    var description: StatementDescription {
        .constraint(["entitlement"] +  key.description + match.description)
    }
}


public struct EntitlementSymbol: Symbol {
    public let sourceToken: Token
}

public struct KeyFragment {
    public let leftBracket: Token
    public let keySymbol: StringSymbol
    public let rightBracket: Token
    
    static func attemptParse(tokens: [Token]) throws -> (KeyFragment, [Token]) {
        var remainingTokens = tokens
        
        guard remainingTokens.first?.type == .leftBracket else {
            throw ParserError.invalidKeyFragment(description: "First token is not [")
        }
        let leftBracket = remainingTokens.removeFirst()
        
        guard remainingTokens.first?.type == .identifier else {
            throw ParserError.invalidKeyFragment(description: "Second token is not an identifier")
        }
        let keySymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
        
        guard remainingTokens.first?.type == .rightBracket else {
            throw ParserError.invalidKeyFragment(description: "Third token is not ]")
        }
        let rightBracket = remainingTokens.removeFirst()
        
        return (KeyFragment(leftBracket: leftBracket, keySymbol: keySymbol, rightBracket: rightBracket),
                remainingTokens)
    }
    
    var value: String {
        keySymbol.value
    }
    
    var description: [String] {
        return ["[", keySymbol.value, "]"]
    }
}

// The expression
//   identifier = constant
//
// succeeds if the unique identifier string embedded in the code signature is exactly equal to constant. The equal sign
// is optional in identifier expressions. Signing identifiers can be tested only for exact equality; the wildcard
// character (*) can not be used with the identifier constraint, nor can identifiers be tested for inequality.
public enum IdentifierConstraint: Statement, StatementDescribable {
    case explicitEquality(IdentifierSymbol, EqualsSymbol, StringSymbol)
    case implicitEquality(IdentifierSymbol, StringSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (Statement, [Token])? {
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "identifier" else {
            return nil
        }
        
        let identifierConstraint: IdentifierConstraint
        var remainingTokens = tokens
        let identifierSymbol = IdentifierSymbol(sourceToken: remainingTokens.removeFirst())
        // Next element must exist and can either be an equality symbol or a string symbol
        guard let secondToken = remainingTokens.first else {
            throw ParserError.invalidIdentifier(description: "No token after identifier")
        }
        if secondToken.type == .equals {
            let equalsOperator = EqualsSymbol(sourceToken: remainingTokens.removeFirst())
            // Third token must be a string symbol
            guard let thirdToken = remainingTokens.first else {
                throw ParserError.invalidIdentifier(description: "No token after identifier =")
            }
            if thirdToken.type == .identifier {
                let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
                identifierConstraint = .explicitEquality(identifierSymbol, equalsOperator, stringSymbol)
            } else {
                throw ParserError.invalidIdentifier(description: "Token after identifier = is not an identifier. " +
                                                                 "Token: \(thirdToken)")
            }
        } else if secondToken.type == .identifier {
            let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
            identifierConstraint = .implicitEquality(identifierSymbol, stringSymbol)
        } else {
            throw ParserError.invalidIdentifier(description: "Token after identifier is not an identifier. " +
                                                             "Token: \(secondToken)")
        }
        
        return (identifierConstraint, remainingTokens)
    }
    
    var constant: StringSymbol {
        switch self {
            case .explicitEquality(_, _, let stringSymbol):
                return stringSymbol
            case .implicitEquality(_, let stringSymbol):
                return stringSymbol
        }
    }
    
    var description: StatementDescription {
        switch self {
            case .explicitEquality(_, _, let stringSymbol):
                return .constraint(["identifier", "=", stringSymbol.value ])
            case .implicitEquality(_, let stringSymbol):
                return .constraint(["identifier", stringSymbol.value])
        }
    }
}

/// Literally the symbol for the `identifier` keyword
public struct IdentifierSymbol: Symbol {
    public let sourceToken: Token
}

// MARK: cdhash

// The expression
//
//   cdhash hash-constant
//
// computes the canonical hash of the program’s CodeDirectory resource and succeeds if the value of this hash exactly
// equals the specified hash constant.
public enum CodeDirectoryHashConstraint: Statement, StatementDescribable {
    case filePath(CodeDirectoryHashSymbol, StringSymbol)
    case hashConstant(CodeDirectoryHashSymbol, HashConstantSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (Statement, [Token])? {
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "cdhash" else {
            return nil
        }
        
        var remainingTokens = tokens
        let cdHashSymbol = CodeDirectoryHashSymbol(sourceToken: remainingTokens.removeFirst())
        if remainingTokens.first?.type == .hashConstant { // hash constant
            let hashConstantSymbol = HashConstantSymbol(sourceToken: remainingTokens.removeFirst())
            
            return (CodeDirectoryHashConstraint.hashConstant(cdHashSymbol, hashConstantSymbol), remainingTokens)
        } else if remainingTokens.first?.type == .identifier { // could be a path
            // It's intentional no actual validation is happening as to whether this identifier is actually a path. The
            // full validation would happen as part of compilation whether this value needs to be a valid path, the path
            // needs to exist on disk, and the path needs to refer to to a file containing an X.509 DER encoded
            // certificate. However, none of that needs to be true to build a valid syntax tree.
            let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
            
            return (CodeDirectoryHashConstraint.filePath(cdHashSymbol, stringSymbol), remainingTokens)
        } else {
            throw ParserError.invalidCodeDirectoryHash(description: "Token after cdhash is not a hash " +
                                                                "constant or an identifier")
        }
    }
    
    var description: StatementDescription {
        switch self {
            case .filePath(_, let stringSymbol):
                return .constraint(["cdhash", stringSymbol.value])
            case .hashConstant(_, let hashConstantSymbol):
                return .constraint(["cdhash", hashConstantSymbol.value])
        }
    }
}

public struct CodeDirectoryHashSymbol: Symbol {
    public let sourceToken: Token
}

// MARK: Certificate

public enum CertificateConstraint: Statement, StatementDescribable {
    // anchor apple
    case wholeApple(AnchorSymbol, AppleSymbol)
    // anchor apple generic
    case wholeAppleGeneric(AnchorSymbol, AppleSymbol, GenericSymbol)
    // certificate position = hash
    case whole(CertificatePosition, EqualsSymbol, HashConstantSymbol)
    // certificate position[element] match expression
    case element(CertificatePosition, KeyFragment, MatchFragment)
    // certificate position[element] <- undocumented, frequently seen for designated requirements
    case elementImplicitExists(CertificatePosition, KeyFragment)
    // certificate position trusted
    case trusted(CertificatePosition, TrustedSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (Statement, [Token])? {
        guard let firstToken = tokens.first,
              firstToken.type == .identifier,
              ["cert", "certificate", "anchor"].contains(firstToken.rawValue) else {
            return nil
        }
        
        let certificateConstraint: CertificateConstraint
        
        let positionParseResult = try CertificatePosition.attemptParse(tokens: tokens)
        let position = positionParseResult.0
        var remainingTokens = positionParseResult.1
        
        // Apple's documentation claims that "anchor" is equivalent to "certificate root", but unfortunately testing
        // shows this to be false because while "anchor apple" is valid, "certificate root apple" is not. So special
        // casing is needed for:
        //   anchor apple
        //   anchor apple generic
        if case .anchor(let anchorSymbol) = position,
           remainingTokens.first?.type == .identifier,
           remainingTokens.first?.rawValue == "apple" {
            let appleSymbol = AppleSymbol(sourceToken: remainingTokens.removeFirst())
            if remainingTokens.first?.type == .identifier, remainingTokens.first?.rawValue == "generic" {
                let genericSymbol = GenericSymbol(sourceToken: remainingTokens.removeFirst())
                certificateConstraint = .wholeAppleGeneric(anchorSymbol, appleSymbol, genericSymbol)
            } else {
                certificateConstraint = .wholeApple(anchorSymbol, appleSymbol)
            }
            
            return (certificateConstraint, remainingTokens)
        }
        
        // All other cases
        guard let nextToken = remainingTokens.first else {
            throw ParserError.invalidCertificate(description: "No token after certificate position")
        }
                
        if nextToken.type == .identifier, nextToken.rawValue == "trusted" { // certificate position trusted
            let trustedSymbol = TrustedSymbol(sourceToken: remainingTokens.removeFirst())
            certificateConstraint = .trusted(position, trustedSymbol)
        } else if nextToken.type == .equals { // certificate position = hash
            let equalsOperator = EqualsSymbol(sourceToken: remainingTokens.removeFirst())
            
            guard remainingTokens.first?.type == .hashConstant else {
                throw ParserError.invalidCertificate(description: "No hash constant token after =")
            }
            let hashConstantSymbol = HashConstantSymbol(sourceToken: remainingTokens.removeFirst())
            certificateConstraint = .whole(position, equalsOperator, hashConstantSymbol)
        } else if nextToken.type == .leftBracket { // certificate position[element] match expression
                                                   //                   OR
                                                   // certificate position[element]
            let elementFragmentResult = try KeyFragment.attemptParse(tokens: remainingTokens)
            remainingTokens = elementFragmentResult.1
            
            // certificate position[element] match expression
            if let matchResult = try MatchFragment.attemptParse(tokens: remainingTokens) {
                certificateConstraint = .element(position, elementFragmentResult.0, matchResult.0)
                remainingTokens = matchResult.1
            } else { // certificate position[element]
                certificateConstraint = .elementImplicitExists(position, elementFragmentResult.0)
            }
        } else {
            throw ParserError.invalidCertificate(description: "Token after certificiate position not one of: " +
                                                 "trusted, =, or [")
        }
        
        return (certificateConstraint, remainingTokens)
    }
    
    var description: StatementDescription {
        switch self {
            case .whole(let certificatePosition, _, let hashConstantSymbol):
                return .constraint(certificatePosition.description + ["=", hashConstantSymbol.value])
            case .wholeApple(_, _):
                return .constraint(["anchor", "apple"])
            case .wholeAppleGeneric(_, _, _):
                return .constraint(["anchor", "apple", "generic"])
            case .element(let certificatePosition, let element, let match):
                return .constraint(certificatePosition.description + element.description + match.description)
            case .elementImplicitExists(let certificatePosition, let element):
                return .constraint(certificatePosition.description + element.description)
            case .trusted(let certificatePosition, _):
                return .constraint(certificatePosition.description + ["trusted"])
        }
    }
}

public struct AppleSymbol: Symbol {
    public let sourceToken: Token
}

public struct GenericSymbol: Symbol {
    public let sourceToken: Token
}

public struct TrustedSymbol: Symbol {
    public let sourceToken: Token
}

public enum CertificatePosition {
    case root(CertificateSymbol, RootPositionSymbol) // certificate root
    case leaf(CertificateSymbol, LeafPositionSymbol) // certificate leaf
    case positiveFromLeaf(CertificateSymbol, IntegerSymbol) // certificate 2
    case negativeFromAnchor(CertificateSymbol, NegativePositionSymbol, IntegerSymbol) // certificate -3
    case anchor(AnchorSymbol) // anchor
    
    // Note that it's not possible to express `certificate anchor` with the above despite the documentation implying
    // such is possible. However, trying to create security requirement of `certificate anchor trusted` fails to
    // compile.
    //
    // From Apple:
    //   The syntax `anchor trusted` is not a synonym for `certificate anchor trusted`. Whereas the former checks all
    //   certificates in the signature, the latter checks only the anchor certificate.
    
    // This assumes that CertificateStatement.attemptParse(...) already determined this should be a position expression
    static func attemptParse(tokens: [Token]) throws -> (CertificatePosition, [Token]) {
        var remainingTokens = tokens
        
        let position: CertificatePosition
        if remainingTokens.first?.rawValue == "anchor" {
            position = .anchor(AnchorSymbol(sourceToken: remainingTokens.removeFirst()))
        } else {
            let certificateSymbol = CertificateSymbol(sourceToken: remainingTokens.removeFirst())
            guard let secondToken = remainingTokens.first else {
                throw ParserError.invalidCertificate(description: "Missing token after certificate")
            }
            
            if secondToken.type == .identifier {
                if secondToken.rawValue == "root" {
                    position = .root(certificateSymbol, RootPositionSymbol(sourceToken: remainingTokens.removeFirst()))
                } else if secondToken.rawValue == "leaf" {
                    position = .leaf(certificateSymbol, LeafPositionSymbol(sourceToken: remainingTokens.removeFirst()))
                } else if UInt(secondToken.rawValue) != nil {
                    position = .positiveFromLeaf(certificateSymbol,
                                                 IntegerSymbol(sourceToken: remainingTokens.removeFirst()))
                } else {
                    throw ParserError.invalidCertificate(description: "Identifier token after certificate " +
                                                                   "is not root, leaf, or an unsigned integer")
                }
            } else if secondToken.type == .negativePosition {
                let negativePositionSymbol = NegativePositionSymbol(sourceToken: remainingTokens.removeFirst())
                
                if let thirdToken = remainingTokens.first,
                   thirdToken.type == .identifier,
                   UInt(thirdToken.rawValue) != nil {
                    position = .negativeFromAnchor(certificateSymbol,
                                                   negativePositionSymbol,
                                                   IntegerSymbol(sourceToken: remainingTokens.removeFirst()))
                } else {
                    throw ParserError.invalidCertificate(description: "Identifier token after - is not an unsigned " +
                                                         "integer")
                }
            } else {
                throw ParserError.invalidCertificate(description: "Token after certificate is not an identifier or " +
                                                     "negative position")
            }
        }
        
        return (position, remainingTokens)
    }
    
    var description: [String] {
        switch self {
            case .root(_, _):
                return ["certificate", "root"]
            case .leaf(_, _):
                return ["certificate", "leaf"]
            case .positiveFromLeaf(_, let integerSymbol):
                return ["certificate", integerSymbol.sourceToken.rawValue]
            case .negativeFromAnchor(_, _, let integerSymbol):
                return ["certificate", "-", integerSymbol.sourceToken.rawValue]
            case .anchor(_):
                return ["anchor"]
        }
    }
}

// Used exclusively for certificate positions, optionally with NegativePositionSymbol
public struct IntegerSymbol: Symbol {
    public let sourceToken: Token
    public let value: UInt
    
    init(sourceToken: Token) {
        self.sourceToken = sourceToken
        self.value = UInt(sourceToken.rawValue)!
    }
}

public struct NegativePositionSymbol: Symbol {
    public let sourceToken: Token
}

public struct RootPositionSymbol: Symbol {
    public let sourceToken: Token
}

public struct LeafPositionSymbol: Symbol {
    public let sourceToken: Token
}

// certificate or cert
public struct CertificateSymbol: Symbol {
    public let sourceToken: Token
}

// equivalent to: certificate root
public struct AnchorSymbol: Symbol {
    public let sourceToken: Token
}

public struct HashConstantSymbol: Symbol {
    public let sourceToken: Token
    public let value: String
    
    init(sourceToken: Token) {
        self.sourceToken = sourceToken
        
        // Extract value by removing leading H" and trailing "
        let rawValue = sourceToken.rawValue
        let thirdIndex = rawValue.index(after: rawValue.index(after: rawValue.startIndex))
        let secondToLastIndex = rawValue.index(before: rawValue.endIndex)
        self.value = String(rawValue[thirdIndex..<secondToLastIndex])
    }
}
