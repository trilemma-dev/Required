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
// TODO: implemenent entitlements, they're basically the same as info

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


struct Parser {
    private init() { }
    
    static func parse(tokens: [Token]) throws -> Expression {
        try parseInternal(tokens: tokens.strippingWhitespaceAndComments(), depth: 0).0
    }
    
    private static func parseInternal(tokens: [Token], depth: UInt) throws -> (Expression, [Token]) {
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
                let parenthesesExpression = ParenthesesExpression(leftParenthesis: leftParenthesis,
                                                       expression: recursionResult.0,
                                                       rightParenthesis: rightParenthesis)
                parsedElements.append(parenthesesExpression)
                
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
                let parsers = [IdentifierExpression.attemptParse(tokens:),
                               InfoExpression.attemptParse(tokens:),
                               // TODO: entitlement parser
                               CertificateExpression.attemptParse(tokens:),
                               CodeDirectoryHashExpression.attemptParse(tokens:)]
                
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
        //   Expression (specifically various types which conformt to this protocol)
        //   NegationSymbol
        //   AndSymbol
        //   OrSymbol
        
        // Now it's time to combine these together (if possible) into a valid expression, potentially a deeply nested
        // one, following the logical operator precedence order. In order of decreasing precedence:
        //   ! (negation)
        //   and (logical AND)
        //   or (logical OR)
        parsedElements = try resolveNegations(parsedElements: parsedElements)
        parsedElements = try resolveInfixOperators(parsedElements: parsedElements,
                                                   symbolType: AndSymbol.self) { lhs, symbol, rhs in
            AndExpression(lhsExpression: lhs, andSymbol: symbol, rhsExpression: rhs)
        }
        parsedElements = try resolveInfixOperators(parsedElements: parsedElements,
                                                   symbolType: OrSymbol.self) { lhs, symbol, rhs in
            OrExpression(lhsExpression: lhs, orSymbol: symbol, rhsExpression: rhs)
        }
        
        // If the tokens represent a semanticly valid input, then there should now be exactly one element in
        // parsedElements and it should be an expression. Otherwise, this is not valid.
        guard parsedElements.count == 1, let expression = parsedElements.first as? Expression else {
            throw ParserError.invalid(description: "Tokens could not be resolved to a singular expression")
        }
        
        return (expression, tokens)
    }
    
    private static func resolveNegations(parsedElements: [Any]) throws -> [Any] {
        // Iterates backwards through the parsed elements resolving negations more easily for cases like:
        //    !!info[FooBar] <= hello.world.yeah
        //
        // The first NegationSymbol is a modifier of the NegationExpression containing the second one, so by iterating
        // backwards we can resolve these in place in a single pass.
        var parsedElements = parsedElements
        var currIndex = parsedElements.index(before: parsedElements.endIndex)
        while currIndex >= parsedElements.startIndex {
            let currElement = parsedElements[currIndex]
            let afterCurrIndex = parsedElements.index(after: currIndex)
            let afterCurrElement = afterCurrIndex < parsedElements.endIndex ? parsedElements[afterCurrIndex] : nil
            
            if let negationSymbol = currElement as? NegationSymbol {
                guard let expresion = afterCurrElement as? Expression else {
                    throw ParserError.invalidNegation(description: "! must be followed by an expression")
                }
                
                let negationExpression = NegationExpression(negationSymbol: negationSymbol, expression: expresion)
                
                // Remove the two elements we just turned into the NegationExpression, insert that expression where the
                // first one was located
                parsedElements.remove(at: afterCurrIndex)
                parsedElements.remove(at: currIndex)
                parsedElements.insert(negationExpression, at: currIndex)
            }
            
            // Continue iterating backwards
            currIndex = parsedElements.index(before: currIndex)
        }
        
        return parsedElements
    }
    
    private static func resolveInfixOperators<T: Symbol>(
        parsedElements: [Any],
        symbolType: T.Type, // AndSymbol or OrSymbol
        createCombinedExpression: (Expression, T, Expression) -> Expression // Create AndExpression or OrExpression
    ) throws -> [Any] {
        // Iterate forwards through the elements, creating expressions whenever the current element is of type T. This
        // requires the previous and next elements to already be expressions; if they're not then the input is invalid.
        var parsedElements = parsedElements
        var currIndex = parsedElements.startIndex
        while currIndex < parsedElements.endIndex {
            let beforeCurrIndex = parsedElements.index(before: currIndex)
            let beforeCurrElement = beforeCurrIndex < parsedElements.startIndex ? nil : parsedElements[beforeCurrIndex]
            let currElement = parsedElements[currIndex]
            let afterCurrIndex = parsedElements.index(after: currIndex)
            let afterCurrElement = afterCurrIndex < parsedElements.endIndex ? parsedElements[afterCurrIndex] : nil
            
            if let symbol = currElement as? T {
                guard let beforeExpression = beforeCurrElement as? Expression,
                      let afterExpression = afterCurrElement as? Expression else {
                          throw ParserError.invalid(description: "\(symbol.sourceToken.rawValue) must be placed " +
                                                    "between two expressions")
                }
                
                let combinedExpression = createCombinedExpression(beforeExpression, symbol, afterExpression)
                
                // Remove the three elements we turned into the combined expression, insert that expression where the
                // first one was located
                parsedElements.remove(at: afterCurrIndex)
                parsedElements.remove(at: currIndex)
                parsedElements.remove(at: beforeCurrIndex)
                parsedElements.insert(combinedExpression, at: beforeCurrIndex)
                
                // currIndex now refers to the next element, so don't advance it
            } else {
                currIndex = afterCurrIndex
            }
        }
        
        return parsedElements
    }
}


enum ParserError: Error {
    case invalidToken(description: String)
    
    case invalid(description: String)
    
    case invalidAnd(description: String)
    case invalidOr(description: String)
    case invalidNegation(description: String)
    case invalidIdentifierExpression(description: String)
    case invalidMatchExpresion(description: String)
    case invalidInfoExpression(description: String)
    case invalidCodeDirectoryHashExpression(description: String)
    case invalidCertificateExpression(description: String)
}

enum ExpressionDescription {
    case constraint([String])
    case logicalOperator(String, [ExpressionDescription])
    
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
            } else if ancestorDepths.contains(i) { // whether a | needs to be drawn to an ancestor
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

protocol Expression {
    var description: ExpressionDescription { get }
}

protocol Symbol: CustomStringConvertible {
    var sourceToken: Token { get }
}

extension Symbol {
    var description: String {
        self.sourceToken.rawValue
    }
}

struct NegationExpression: Expression {
    let negationSymbol: NegationSymbol
    let expression: Expression
    
    var description: ExpressionDescription {
        .logicalOperator("!", [expression.description])
    }
}

struct NegationSymbol: Symbol {
    let sourceToken: Token
}

struct ParenthesesExpression: Expression {
    let leftParenthesis: Token
    let expression: Expression
    let rightParenthesis: Token
    
    var description: ExpressionDescription {
        .logicalOperator("()", [expression.description])
    }
}

struct AndSymbol: Symbol {
    let sourceToken: Token
}

struct AndExpression: Expression {
    let lhsExpression: Expression
    let andSymbol: AndSymbol
    let rhsExpression: Expression
    
    var description: ExpressionDescription {
        .logicalOperator("and", [lhsExpression.description, rhsExpression.description])
    }
}

struct OrSymbol: Symbol {
    let sourceToken: Token
}

struct OrExpression: Expression {
    let lhsExpression: Expression
    let orSymbol: OrSymbol
    let rhsExpression: Expression
    
    var description: ExpressionDescription {
        .logicalOperator("or", [lhsExpression.description, rhsExpression.description])
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
enum MatchExpression {
    case infix(InfixComparisonOperator, StringSymbol)
    case infixEquals(EqualsSymbol, StringExpression)
    case unarySuffix(ExistsSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (MatchExpression, [Token])? {
        guard let firstToken = tokens.first else {
            return nil
        }
        var remainingTokens = tokens
        
        // unarySuffix - exists
        if firstToken.type == .identifier, firstToken.rawValue == "exists" {
            let existsOperator = ExistsSymbol(sourceToken: remainingTokens.removeFirst())
            
            return (.unarySuffix(existsOperator), remainingTokens)
        }
        
        // infix or not a match expression
        let infixOperator: InfixComparisonOperator
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
            // Not a comparison operator, so can't be parsed as a match expression
            default:
                return nil
        }
        
        guard let secondToken = remainingTokens.first else {
            throw ParserError.invalidMatchExpresion(description: "No token present after comparison operator")
        }
        
        let matchExpression: MatchExpression
        // Equals comparison allows for wildcard string expressions
        if let equalsOperator = infixOperator as? EqualsSymbol {
            if secondToken.type == .identifier {
                let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
                if let thirdToken = remainingTokens.first, thirdToken.type == .wildcard { // constant*
                    let wildcardSymbol = WildcardSymbol(sourceToken: remainingTokens.removeFirst())
                    matchExpression = .infixEquals(equalsOperator, .postfixWildcard(stringSymbol, wildcardSymbol))
                } else { // constant
                    matchExpression = .infix(equalsOperator, stringSymbol)
                }
            } else if secondToken.type == .wildcard {
                let wildcardSymbol = WildcardSymbol(sourceToken: remainingTokens.removeFirst())
                guard let thirdToken = remainingTokens.first, thirdToken.type == .identifier else {
                    throw ParserError.invalidMatchExpresion(description: "No identifier token present after wildcard " +
                                                            "token: \(secondToken)")
                }
                
                let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
                if let fourthToken = remainingTokens.first, fourthToken.type == .wildcard { // *constant*
                    let secondWildcardSymbol = WildcardSymbol(sourceToken: remainingTokens.removeFirst())
                    matchExpression = .infixEquals(equalsOperator, .prefixAndPostfixWildcard(wildcardSymbol,
                                                                                             stringSymbol,
                                                                                             secondWildcardSymbol))
                } else { // *constant
                    matchExpression = .infixEquals(equalsOperator, .prefixWildcard(wildcardSymbol, stringSymbol))
                }
            } else {
                throw ParserError.invalidMatchExpresion(description: "Token after comparison operator neither a " +
                                                        "wildcard nor an identifier. Token: \(secondToken).")
            }
        } else { // All other comparisons only allow for string symbol comparisons (no wildcards)
            guard secondToken.type == .identifier else {
                throw ParserError.invalidMatchExpresion(description: "Token after comparison operator is not " +
                                                        "an identifier. Token: \(secondToken)")
            }
            matchExpression = .infix(infixOperator, StringSymbol(sourceToken: remainingTokens.removeFirst()))
        }
        
        return (matchExpression, remainingTokens)
    }
    
    
    var description: [String] {
        switch self {
            case .infix(let infixComparisonOperator, let stringSymbol):
                return [infixComparisonOperator.sourceToken.rawValue, stringSymbol.value]
            case .infixEquals(_, let stringExpression):
                return ["="] + stringExpression.description
            case .unarySuffix(_):
                return ["exists"]
        }
    }
}

protocol InfixComparisonOperator: Symbol { }

struct EqualsSymbol: InfixComparisonOperator {
    let sourceToken: Token
}

struct LessThanSymbol: InfixComparisonOperator {
    let sourceToken: Token
}

struct GreaterThanSymbol: InfixComparisonOperator {
    let sourceToken: Token
}

struct LessThanOrEqualToSymbol: InfixComparisonOperator {
    let sourceToken: Token
}

struct GreaterThanOrEqualToSymbol: InfixComparisonOperator {
    let sourceToken: Token
}

struct ExistsSymbol: Symbol {
    let sourceToken: Token
}

enum StringExpression {
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

struct StringSymbol: Symbol {
    let sourceToken: Token
    let rawValue: String
    let value: String
    
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

struct WildcardSymbol: Symbol {
    let sourceToken: Token
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

struct InfoExpression: Expression {
    let infoSymbol: InfoSymbol
    let leftBracket: Token
    let keySymbol: StringSymbol
    let rightBracket: Token
    let matchExpression: MatchExpression
    
    static func attemptParse(tokens: [Token]) throws -> (Expression, [Token])? {
        guard let firstToken = tokens.first, firstToken.type == .identifier, firstToken.rawValue == "info" else {
            return nil
        }
        
        var remainingTokens = tokens
        let infoSymbol = InfoSymbol(sourceToken: remainingTokens.removeFirst())
        
        guard let secondToken = remainingTokens.first, secondToken.type == .leftBracket else {
            throw ParserError.invalidInfoExpression(description: "Second token is not [")
        }
        let leftBracket = remainingTokens.removeFirst()
        
        guard let thirdToken = remainingTokens.first, thirdToken.type == .identifier else {
            throw ParserError.invalidInfoExpression(description: "Third token is not an identifier")
        }
        let keySymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
        
        guard let fourthToken = remainingTokens.first, fourthToken.type == .rightBracket else {
            throw ParserError.invalidInfoExpression(description: "Fourth token is not ]")
        }
        let rightBracket = remainingTokens.removeFirst()
        
        guard let matchResult = try MatchExpression.attemptParse(tokens: remainingTokens) else {
            throw ParserError.invalidInfoExpression(description: "Fifth and beyond tokens not a match expression")
        }
        let infoExpression = InfoExpression(infoSymbol: infoSymbol,
                                           leftBracket: leftBracket,
                                           keySymbol: keySymbol,
                                           rightBracket: rightBracket,
                                           matchExpression: matchResult.0)
        
        return (infoExpression, matchResult.1)
    }
    
    var description: ExpressionDescription {
        .constraint([ "info", "[", keySymbol.value, "]" ] + matchExpression.description)
    }
}

struct InfoSymbol: Symbol {
    let sourceToken: Token
}

// The expression
//   identifier = constant
//
// succeeds if the unique identifier string embedded in the code signature is exactly equal to constant. The equal sign
// is optional in identifier expressions. Signing identifiers can be tested only for exact equality; the wildcard
// character (*) can not be used with the identifier constraint, nor can identifiers be tested for inequality.
enum IdentifierExpression: Expression {
    case explicitEquality(IdentifierSymbol, EqualsSymbol, StringSymbol)
    case implicitEquality(IdentifierSymbol, StringSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (Expression, [Token])? {
        // Okay to not be an identifier expression
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "identifier" else {
            return nil
        }
        
        let identifierExpression: IdentifierExpression
        var remainingTokens = tokens
        let identifierSymbol = IdentifierSymbol(sourceToken: remainingTokens.removeFirst())
        // Next element must exist and can either be an equality symbol or a string symbol
        guard let secondToken = remainingTokens.first else {
            throw ParserError.invalidIdentifierExpression(description: "No token after identifier")
        }
        if secondToken.type == .equals {
            let equalsOperator = EqualsSymbol(sourceToken: remainingTokens.removeFirst())
            // Third token must be a string symbol
            guard let thirdToken = remainingTokens.first else {
                throw ParserError.invalidIdentifierExpression(description: "No token after identifier =")
            }
            if thirdToken.type == .identifier {
                let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
                identifierExpression = .explicitEquality(identifierSymbol, equalsOperator, stringSymbol)
            } else {
                throw ParserError.invalidIdentifierExpression(description: "Token after identifier = is not an " +
                                                                           "identifier. Token: \(thirdToken)")
            }
        } else if secondToken.type == .identifier {
            let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
            identifierExpression = .implicitEquality(identifierSymbol, stringSymbol)
        } else {
            throw ParserError.invalidIdentifierExpression(description: "Token after identifier is not an " +
                                                                       "identifier. Token: \(secondToken)")
        }
        
        return (identifierExpression, remainingTokens)
    }
    
    var constant: StringSymbol {
        switch self {
            case .explicitEquality(_, _, let stringSymbol):
                return stringSymbol
            case .implicitEquality(_, let stringSymbol):
                return stringSymbol
        }
    }
    
    var description: ExpressionDescription {
        switch self {
            case .explicitEquality(_, _, let stringSymbol):
                return .constraint(["identifier", "=", stringSymbol.value ])
            case .implicitEquality(_, let stringSymbol):
                return .constraint(["identifier", stringSymbol.value])
        }
    }
}

/// Literally the symbol for the `identifier` keyword
struct IdentifierSymbol: Symbol {
    let sourceToken: Token
}



// MARK: cdhash

// The expression
//
//   cdhash hash-constant
//
// computes the canonical hash of the program’s CodeDirectory resource and succeeds if the value of this hash exactly
// equals the specified hash constant.
enum CodeDirectoryHashExpression: Expression {
    case filePath(CodeDirectoryHashSymbol, StringSymbol)
    case hashConstant(CodeDirectoryHashSymbol, HashConstantSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (Expression, [Token])? {
        guard tokens.first?.type == .identifier, tokens.first?.rawValue == "cdhash" else {
            return nil
        }
        
        var remainingTokens = tokens
        let cdHashSymbol = CodeDirectoryHashSymbol(sourceToken: remainingTokens.removeFirst())
        if remainingTokens.first?.type == .hashConstant { // hash constant
            let hashConstantSymbol = HashConstantSymbol(sourceToken: remainingTokens.removeFirst())
            
            return (CodeDirectoryHashExpression.hashConstant(cdHashSymbol, hashConstantSymbol), remainingTokens)
        } else if remainingTokens.first?.type == .identifier { // could be a path
            // It's intentional no actual validation is happening as to whether this identifier is actually a path. The
            // full validation would happen as part of compilation whether this value needs to be a valid path, the path
            // needs to exist on disk, and the path needs to refer to to a file containing an X.509 DER encoded
            // certificate. However, none of that needs to be true to build a valid syntax tree.
            let stringSymbol = StringSymbol(sourceToken: remainingTokens.removeFirst())
            
            return (CodeDirectoryHashExpression.filePath(cdHashSymbol, stringSymbol), remainingTokens)
        } else {
            throw ParserError.invalidCodeDirectoryHashExpression(description: "Token after cdhash is not a hash " +
                                                                "constant or an identifier")
        }
    }
    
    var description: ExpressionDescription {
        switch self {
            case .filePath(_, let stringSymbol):
                return .constraint(["cdhash", stringSymbol.value])
            case .hashConstant(_, let hashConstantSymbol):
                return .constraint(["cdhash", hashConstantSymbol.value])
        }
    }
}

struct CodeDirectoryHashSymbol: Symbol {
    let sourceToken: Token
}

// MARK: Certificate

enum CertificateExpression: Expression {
    // anchor apple
    case wholeApple(AnchorSymbol, AppleSymbol)
    // anchor apple generic
    case wholeAppleGeneric(AnchorSymbol, AppleSymbol, GenericSymbol)
    // certificate position = hash
    case whole(CertificatePosition, EqualsSymbol, HashConstantSymbol)
    // certificate position[element] match expression
    case element(CertificatePosition, Token, StringSymbol, Token, MatchExpression)
    // certificate position[element] <- undocumented, frequently seen for designated requirements
    case elementImplicitExists(CertificatePosition, Token, StringSymbol, Token)
    // certificate position trusted
    case trusted(CertificatePosition, TrustedSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (Expression, [Token])? {
        guard let firstToken = tokens.first,
              firstToken.type == .identifier,
              ["cert", "certificate", "anchor"].contains(firstToken.rawValue) else {
            return nil
        }
        
        let certificateExpression: CertificateExpression
        
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
                certificateExpression = .wholeAppleGeneric(anchorSymbol, appleSymbol, genericSymbol)
            } else {
                certificateExpression = .wholeApple(anchorSymbol, appleSymbol)
            }
            
            return (certificateExpression, remainingTokens)
        }
        
        // All other cases
        guard let nextToken = remainingTokens.first else {
            throw ParserError.invalidCertificateExpression(description: "No token after certificate position")
        }
                
        if nextToken.type == .identifier, nextToken.rawValue == "trusted" { // certificate position trusted
            let trustedSymbol = TrustedSymbol(sourceToken: remainingTokens.removeFirst())
            certificateExpression = .trusted(position, trustedSymbol)
        } else if nextToken.type == .equals { // certificate position = hash
            let equalsOperator = EqualsSymbol(sourceToken: remainingTokens.removeFirst())
            
            guard remainingTokens.first?.type == .hashConstant else {
                throw ParserError.invalidCertificateExpression(description: "No hash constant token after =")
            }
            let hashConstantSymbol = HashConstantSymbol(sourceToken: remainingTokens.removeFirst())
            certificateExpression = .whole(position, equalsOperator, hashConstantSymbol)
        } else if nextToken.type == .leftBracket { // certificate position[element] match expression
                                                   //                   OR
                                                   // certificate position[element]
            let leftBracketToken = remainingTokens.removeFirst()
            
            guard let elementToken = remainingTokens.first, elementToken.type == .identifier else {
                throw ParserError.invalidCertificateExpression(description: "No identifier token after [")
            }
            let element = StringSymbol(sourceToken: remainingTokens.removeFirst())
            
            guard remainingTokens.first?.type == .rightBracket else {
                throw ParserError.invalidCertificateExpression(description: "No ] token after identifier")
            }
            let rightBracketToken = remainingTokens.removeFirst()
            
            // certificate position[element] match expression
            if let matchResult = try MatchExpression.attemptParse(tokens: remainingTokens) {
                certificateExpression = .element(position, leftBracketToken, element, rightBracketToken, matchResult.0)
                remainingTokens = matchResult.1
            } else { // certificate position[element]
                certificateExpression = .elementImplicitExists(position, leftBracketToken, element, rightBracketToken)
            }
        } else {
            throw ParserError.invalidCertificateExpression(description: "Token after certificiate position not " +
                                                           "one of: trusted, =, or [")
        }
        
        return (certificateExpression, remainingTokens)
    }
    
    var description: ExpressionDescription {
        switch self {
            case .whole(let certificatePosition, _, let hashConstantSymbol):
                return .constraint(certificatePosition.description + ["=", hashConstantSymbol.value])
            case .wholeApple(_, _):
                return .constraint(["anchor", "apple"])
            case .wholeAppleGeneric(_, _, _):
                return .constraint(["anchor", "apple", "generic"])
            case .element(let certificatePosition, _, let stringSymbol, _, let matchExpression):
                return .constraint(certificatePosition.description + ["[", stringSymbol.value, "]"] +
                                   matchExpression.description)
            case .elementImplicitExists(let certificatePosition, _, let stringSymbol, _):
                return .constraint(certificatePosition.description + ["[", stringSymbol.value, "]"])
            case .trusted(let certificatePosition, _):
                return .constraint(certificatePosition.description + ["trusted"])
        }
    }
}

struct AppleSymbol: Symbol {
    let sourceToken: Token
}

struct GenericSymbol: Symbol {
    let sourceToken: Token
}

struct TrustedSymbol: Symbol {
    let sourceToken: Token
}

enum CertificatePosition {
    case root(CertificateSymbol, RootPositionSymbol) // certificate root
    case leaf(CertificateSymbol, LeafPositionSymbol) // certificate leaf
    case positiveFromLeaf(CertificateSymbol, IntegerSymbol) // certificate 2
    case negativeFromAnchor(CertificateSymbol, NegativePositionSymbol, IntegerSymbol) // certificate -3
    case anchor(AnchorSymbol) // anchor
    
    // Note that it's not possible to express `certificate anchor` with the above despite the documentation implying
    // such an expression is possible. However, trying to create security requirement of `certificate anchor trusted`
    // fails to compile.
    //
    // From Apple:
    //   The syntax `anchor trusted` is not a synonym for `certificate anchor trusted`. Whereas the former checks all
    //   certificates in the signature, the latter checks only the anchor certificate.
    
    // This assumes that CertificateExpression.attemptParse(...) already determined this should be a position expression
    static func attemptParse(tokens: [Token]) throws -> (CertificatePosition, [Token]) {
        var remainingTokens = tokens
        
        let position: CertificatePosition
        if remainingTokens.first?.rawValue == "anchor" {
            position = .anchor(AnchorSymbol(sourceToken: remainingTokens.removeFirst()))
        } else {
            let certificateSymbol = CertificateSymbol(sourceToken: remainingTokens.removeFirst())
            guard let secondToken = remainingTokens.first else {
                throw ParserError.invalidCertificateExpression(description: "Missing token after certificate")
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
                    throw ParserError.invalidCertificateExpression(description: "Identifier token after certificate " +
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
                    throw ParserError.invalidCertificateExpression(description: "Identifier token after - is not an " +
                                                                   "unsigned integer")
                }
            } else {
                throw ParserError.invalidCertificateExpression(description: "Token after certificate is not an " +
                                                               "identifier or negative position")
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
struct IntegerSymbol: Symbol {
    let sourceToken: Token
    let value: UInt
    
    init(sourceToken: Token) {
        self.sourceToken = sourceToken
        self.value = UInt(sourceToken.rawValue)!
    }
}

struct NegativePositionSymbol: Symbol {
    let sourceToken: Token
}

struct RootPositionSymbol: Symbol {
    let sourceToken: Token
}

struct LeafPositionSymbol: Symbol {
    let sourceToken: Token
}

// certificate or cert
struct CertificateSymbol: Symbol {
    let sourceToken: Token
}

// equivalent to: certificate root
struct AnchorSymbol: Symbol {
    let sourceToken: Token
}

struct HashConstantSymbol: Symbol {
    let sourceToken: Token
    let value: String
    
    init(sourceToken: Token) {
        self.sourceToken = sourceToken
        
        // Extract value by removing leading H" and trailing "
        let rawValue = sourceToken.rawValue
        let thirdIndex = rawValue.index(after: rawValue.index(after: rawValue.startIndex))
        let secondToLastIndex = rawValue.index(before: rawValue.endIndex)
        self.value = String(rawValue[thirdIndex..<secondToLastIndex])
    }
}
