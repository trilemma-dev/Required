//
//  Tokenizer.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-14
//

// Language definition:
// https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html

public struct Tokenizer {
    private init() { }
    
    private static let tokenizationOrder: [TokenType] = [
        .whitespace,            // Whitespace is always allowed between tokens, so must be parsed first
        .comment,
        .hashConstant,
        .identifier,
        .requirementSet,        // Must come before equals or will be parsed as '=' and then '>'
        .negation,
        .equals,
        .lessThanOrEqualTo,     // Must come before lessThan or will be parsed as '<' and then '="
        .lessThan,
        .greaterThanOrEqualTo, // Must come before greaterThan or will be parsed as '>' and then '="
        .greaterThan,
        .wildcard,
        .negativePosition,
        .leftParenthesis,
        .rightParenthesis,
        .leftBracket,
        .rightBracket
    ]
    
    /// Creates a tokenized form of the `requirement` string if possible, or throws a `TokenizationError` if not.
    ///
    /// Just because it is possible to create a valid tokenization does not mean the requirement is semantically valid.
    public static func tokenize(requirement: String) throws -> [Token] {
        var tokens = [Token]()
        var currentIndex = requirement.startIndex
        while currentIndex <= requirement.index(before: requirement.endIndex) {
            let substring = requirement[currentIndex..<requirement.endIndex]
            let tokenCount = tokens.count
            for tokenType in tokenizationOrder {
                if let token = tokenType.tokenize(substring: substring) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    break
                }
            }
            if tokens.count == tokenCount { // didn't append any tokens
                throw TokenizationError(requirement: requirement, failureIndex: currentIndex)
            }
        }

        return tokens
    }
}

/// What the token represents in the source string.
public enum TokenType: Hashable {
    case whitespace
    case comment
    case hashConstant
    case identifier
    case negation             // !
    case equals               // =
    case lessThan             // <
    case greaterThan          // >
    case lessThanOrEqualTo    // <=
    case greaterThanOrEqualTo // >=
    case wildcard             // *
    case negativePosition     // -
    case requirementSet       // =>
    case leftParenthesis      // (
    case rightParenthesis     // )
    case leftBracket          // [
    case rightBracket         // ]
    
    /// Attempts to represent the `substring` into a `Token` with this type, or `nil` if that's not possible.
    fileprivate func tokenize(substring: Substring) -> Token? {
        let tokenizationFunction: (Substring) -> Range<String.Index>?
        switch self {
            case .whitespace:           tokenizationFunction = Whitespace.range(substring:)
            case .comment:              tokenizationFunction = rangeForComment(substring:)
            case .hashConstant:         tokenizationFunction = HashConstant.range(substring:)
            case .identifier:           tokenizationFunction = Identifier.range(substring:)
            case .negation:             tokenizationFunction = { rangeForExactValue("!",  substring: $0) }
            case .equals:               tokenizationFunction = { rangeForExactValue("=",  substring: $0) }
            case .lessThan:             tokenizationFunction = { rangeForExactValue("<",  substring: $0) }
            case .greaterThan:          tokenizationFunction = { rangeForExactValue(">",  substring: $0) }
            case .lessThanOrEqualTo:    tokenizationFunction = { rangeForExactValue("<=", substring: $0) }
            case .greaterThanOrEqualTo: tokenizationFunction = { rangeForExactValue(">=", substring: $0) }
            case .wildcard:             tokenizationFunction = { rangeForExactValue("*",  substring: $0) }
            case .negativePosition:     tokenizationFunction = { rangeForExactValue("-",  substring: $0) }
            case .requirementSet:       tokenizationFunction = { rangeForExactValue("=>", substring: $0) }
            case .leftParenthesis:      tokenizationFunction = { rangeForExactValue("(",  substring: $0) }
            case .rightParenthesis:     tokenizationFunction = { rangeForExactValue(")",  substring: $0) }
            case .leftBracket:          tokenizationFunction = { rangeForExactValue("[",  substring: $0) }
            case .rightBracket:         tokenizationFunction = { rangeForExactValue("]",  substring: $0) }
        }
        guard let range = tokenizationFunction(substring) else {
            return nil
        }
        
        return Token(type: self, rawValue: String(substring[..<range.upperBound]), range: range)
    }
}

// MARK: Range finders

/// Returns the range for the exact `value` provided if `substring` starts with the `value`. Otherwise `nil` is returned.
func rangeForExactValue(_ value: String, substring: Substring) -> Range<String.Index>? {
    if substring.starts(with: value) {
        return substring.startIndex..<substring.index(substring.startIndex, offsetBy: value.count)
    }
    
    return nil
}

// Apple documentation:
//   Comments are allowed in C, Objective C, and C++.
//
// Assumptions made about the above:
// - C++ comments can look like one of:
//   - /* This is a comment */
//   - // This is a comment
// - C comments differ depending on the version of C, but regardless are a subset of the above C++ comments
// - Objective C comments are the same as those for C++
func rangeForComment(substring: Substring) -> Range<String.Index>? {
    if substring.starts(with: "//"), let firstIndex = substring.firstIndex(of: "\n") {
        return substring.startIndex..<substring.index(after: firstIndex)
    } else if substring.starts(with: "/*") {
        for index in substring.indices {
            if index == substring.startIndex || index == substring.index(after: substring.startIndex) { // Starting /*
                continue
            }
            
            // Lookg for ending */
            let nextIndex = substring.index(after: index)
            if substring[index] == "*", nextIndex != substring.endIndex, substring[nextIndex] == "/" {
                return substring.startIndex..<substring.index(after: nextIndex)
            }
        }
        
        return nil
    } else {
        return nil
    }
}

// Apple documentation:
//   Unquoted whitespace is allowed between tokens
//   Line endings have no special meaning and are treated as whitespace
//
// There is no mention of specifically which whitespace characters are valid; assuming this is space, tab, and new line.
fileprivate struct Whitespace {
    private static let whitespaceCharacters: Set<Character> = [" ", "\n", "\t"]
    
    static func range(substring: Substring) -> Range<String.Index>? {
        guard let firstCharacter = substring.first, whitespaceCharacters.contains(firstCharacter) else {
            return nil
        }
        
        return substring.startIndex..<substring.index(after: substring.startIndex)
    }
}

// Apple documentation:
//   Hash values are written as a hexadecimal number in quotes preceded by an H. You can use either uppercase or
//   lowercase letters (A..F or a..f) in the hexadecimal numbers.
fileprivate struct HashConstant {
    private static let startSequence: String = "H\""
    private static let endSequence: Character = "\""
    private static let validCharacters: Set<Character> = [
        "0","1","2","3","4","5","6","7","8","9",
        "a","b","c","d","e","f",
        "A","B","C","D","E","F",
    ]
    
    static func range(substring: Substring) -> Range<String.Index>? {
        guard substring.starts(with: startSequence) else {
            return nil
        }
        
        for index in substring.indices {
            if index == substring.startIndex || index == substring.index(after: substring.startIndex) { // Starting H"
                continue
            }
            if substring[index] == endSequence { // Ending "
                return substring.startIndex..<substring.index(after: index)
            }
            if !validCharacters.contains(substring[index]) { // Bail if invalid character encountered
                return nil
            }
        }
        
        return nil
    }
}

// Identifier represents multiple different portions of the language which without semantic interpretation either
// cannot be distinguished (e.g. a keyword and a unquoted string) or adds non-beneficial complexity to distinguish
// (e.g. unquoted absolute file paths vs quoted absolute file paths).
//
// An identifiers can represent:
// - quoted string constants, example: "hello world"
// - unquoted string constants, example: hello.world
// - keywords, example: certificate
// - operators, example: and
// - unquoted absolute file paths, example: /hello/world
// - quoted absolute file paths, example: "/hello to the/world"
// - integer constants, example: 5
// - certificate element names, example: subject.STREET
// - certificiate field OIDs, example: field.1.2.840.113635.100.6.2.6
// - entitlement keys
// - info dictionary keys
//
// From Apple:
//   String constants must be enclosed by double quotes (" ") unless the string contains only letters, digits, and
//   periods (.), in which case the quotes are optional. Absolute file paths, which start with a slash, do not require
//   quotes unless they contain spaces. For example:
//
//   com.apple.mail                       // no quotes are required
//   "com.apple.mail"                     // quotes are optional
//   "My Company's signing identity"      // requires quotes for spaces and apostrophe
//   /Volumes/myCA/root.crt               // no quotes are required
//   "/Volumes/my CA/root.crt"            // space requires quotes
//   "/Volumes/my_CA/root.crt"            // underscore requires quotes
//
//   It’s never incorrect to enclose the string in quotes—if in doubt, use quotes.
//   Use a backslash to “escape” any character. For example:
//
//   "one \" embedded quote"              // one " embedded quote
//   "one \\ embedded backslash"          // one \ embedded backslash
//
//   The apostrophe, or single quote (') is not a special character, in the sense that it does not need to be escaped,
//   but it must be enclosed in double quotes when present in a string constant, as in the "My Company's signing
//   identity" example above.
//
// Assumptions made about the above:
// - Letter means the 52 upper and lower case letter characters present in English, not including those like ñ
// - Digits means the 10 Western Arabic numerals, not including those like ५ (which is 5 in Devanagari numerals)
fileprivate struct Identifier {
    /// Valid start and end of quoted string constants
    private static let quotationMark: Character = "\""
    /// Valid characters to create an unquoted string
    private static let validUnquotedCharacters: Set<Character> = [
        ".",
        "0","1","2","3","4","5","6","7","8","9",
        "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
        "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
    ]
    /// Escape character when in a quote
    private static let escapeCharacter: Character = "\\"
    /// Path seperator for file paths, only applicable when starting with a path separator
    private static let pathSeperator: Character = "/"
    /// Valid characters for unquoted file paths
    private static let validUnquotedCharactersAndPathSeperator = validUnquotedCharacters.union([pathSeperator])
    
    static func range(substring: Substring) -> Range<String.Index>? {
        guard let firstCharacter = substring.first else {
            return nil
        }
        
        if firstCharacter == Identifier.quotationMark { // quote block, find the last
            return quotationRange(substring: substring)
        } else if firstCharacter == Identifier.pathSeperator { // unquoted absolute path
            return validRange(substring: substring, validCharacters: validUnquotedCharactersAndPathSeperator)
        } else {
            // see if it's a valid unquoted string (or keyword, operator, etc)
            return validRange(substring: substring, validCharacters: validUnquotedCharacters)
        }
    }
    
    private static func quotationRange(substring: Substring) -> Range<String.Index>? {
        guard let firstCharacter = substring.first, firstCharacter == quotationMark else {
            return nil
        }
        
        var previousCharacterIsEscape = false
        for index in substring.indices {
            if index == substring.startIndex {
                continue
            }
            
            if previousCharacterIsEscape {
                previousCharacterIsEscape = false
                continue
            } else {
                if substring[index] == escapeCharacter {
                    previousCharacterIsEscape = true
                    continue
                } else if substring[index] == quotationMark {
                    return substring.startIndex..<substring.index(after: index)
                }
            }
        }
        
        return nil
    }
    
    private static func validRange(substring: Substring, validCharacters: Set<Character>) ->  Range<String.Index>? {
        guard let firstCharacter = substring.first, validCharacters.contains(firstCharacter) else {
            return nil
        }
        
        for index in substring.indices {
            if !validCharacters.contains(substring[index])  { // reached the end of the valid characters
                return substring.startIndex..<index
            } else if index == substring.index(before: substring.endIndex) { // Reached the end of the substring
                return substring.startIndex..<substring.endIndex
            }
        }
        
        return nil
    }
}

extension Array where Element == Token {
    func strippingWhitespaceAndComments() -> [Token] {
        self.compactMap { ($0.type == .whitespace || $0.type == .comment) ? nil : $0 }
    }
}
