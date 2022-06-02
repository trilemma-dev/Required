//
//  Tokenizer Tests.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-14
//

import XCTest
@testable import Required

final class TokenizerTests: XCTestCase {
    
    func testSafariDesignatedRequirement() throws {
        let requirement =
        """
        identifier "com.apple.Safari" and anchor apple
        """
        
        let tokenDescriptions: [(TokenType, String)] = [
            (.identifier, "identifier"),
            (.whitespace, " "),
            (.identifier, "\"com.apple.Safari\""),
            (.whitespace, " "),
            (.identifier, "and"),
            (.whitespace, " "),
            (.identifier, "anchor"),
            (.whitespace, " "),
            (.identifier, "apple")
        ]
        let expectedTokens = createTokens(requirement: requirement, tokenDescriptions: tokenDescriptions)
        let tokens = try Tokenizer.tokenize(requirement: requirement)
        XCTAssertEqual(tokens, expectedTokens)
    }
    
    func testXcodeDesignatedRequirement() throws {
        let requirement =
        """
        (anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "59GAB85EFG") and identifier "com.apple.dt.Xcode"
        """
        
        let tokenDescriptions: [(TokenType, String)] = [
            (.leftParenthesis, "("),
            (.identifier, "anchor"),
            (.whitespace, " "),
            (.identifier, "apple"),
            (.whitespace, " "),
            (.identifier, "generic"),
            (.whitespace, " "),
            (.identifier, "and"),
            (.whitespace, " "),
            (.identifier, "certificate"),
            (.whitespace, " "),
            (.identifier, "leaf"),
            (.leftBracket, "["),
            (.identifier, "field.1.2.840.113635.100.6.1.9"),
            (.rightBracket, "]"),
            (.whitespace, " "),
            (.comment, "/* exists */"),
            (.whitespace, " "),
            (.identifier, "or"),
            (.whitespace, " "),
            (.identifier, "anchor"),
            (.whitespace, " "),
            (.identifier, "apple"),
            (.whitespace, " "),
            (.identifier, "generic"),
            (.whitespace, " "),
            (.identifier, "and"),
            (.whitespace, " "),
            (.identifier, "certificate"),
            (.whitespace, " "),
            (.identifier, "1"),
            (.leftBracket, "["),
            (.identifier, "field.1.2.840.113635.100.6.2.6"),
            (.rightBracket, "]"),
            (.whitespace, " "),
            (.comment, "/* exists */"),
            (.whitespace, " "),
            (.identifier, "and"),
            (.whitespace, " "),
            (.identifier, "certificate"),
            (.whitespace, " "),
            (.identifier, "leaf"),
            (.leftBracket, "["),
            (.identifier, "field.1.2.840.113635.100.6.1.13"),
            (.rightBracket, "]"),
            (.whitespace, " "),
            (.comment, "/* exists */"),
            (.whitespace, " "),
            (.identifier, "and"),
            (.whitespace, " "),
            (.identifier, "certificate"),
            (.whitespace, " "),
            (.identifier, "leaf"),
            (.leftBracket, "["),
            (.identifier, "subject.OU"),
            (.rightBracket, "]"),
            (.whitespace, " "),
            (.equals, "="),
            (.whitespace, " "),
            (.identifier, "\"59GAB85EFG\""),
            (.rightParenthesis, ")"),
            (.whitespace, " "),
            (.identifier, "and"),
            (.whitespace, " "),
            (.identifier, "identifier"),
            (.whitespace, " "),
            (.identifier, "\"com.apple.dt.Xcode\"")
        ]
        
        let expectedTokens = createTokens(requirement: requirement, tokenDescriptions: tokenDescriptions)
        let tokens = try Tokenizer.tokenize(requirement: requirement)
        XCTAssertEqual(expectedTokens, tokens)
    }
    
    func testHashRequirement() throws {
        let requirement =
        """
        // better equal this hash
        cdhash H"d5800a216ffd83b116b7b0f6047cb7f570f49329" or
        // or this hash is fine too
        cdhash H"a5b39bed9962577c102af7ed540b28e66cd3cecb"
        """
        
        let tokenDescriptions: [(TokenType, String)] = [
            (.comment, "// better equal this hash\n"),
            (.identifier, "cdhash"),
            (.whitespace, " "),
            (.hashConstant, "H\"d5800a216ffd83b116b7b0f6047cb7f570f49329\""),
            (.whitespace, " "),
            (.identifier, "or"),
            (.whitespace, "\n"),
            (.comment, "// or this hash is fine too\n"),
            (.identifier, "cdhash"),
            (.whitespace, " "),
            (.hashConstant, "H\"a5b39bed9962577c102af7ed540b28e66cd3cecb\"")
        ]
        
        let expectedTokens = createTokens(requirement: requirement, tokenDescriptions: tokenDescriptions)
        let tokens = try Tokenizer.tokenize(requirement: requirement)
        XCTAssertEqual(expectedTokens, tokens)
    }
    
    // MARK: helper functions
    
    func createToken(requirement: String, type: TokenType, value: String, prevToken: Token?) -> Token {
        let startIndex: String.Index
        if let prevToken = prevToken {
            startIndex = prevToken.range.upperBound
        } else {
            startIndex = requirement.startIndex
        }
        let range = startIndex..<requirement.index(startIndex, offsetBy: value.count)
        
        return Token(type: type, rawValue: value, range: range)
    }
    
    func createTokens(requirement: String, tokenDescriptions: [(TokenType, String)]) -> [Token] {
        var tokens = [Token]()
        var currentToken: Token? = nil
        for description in tokenDescriptions {
            currentToken = createToken(requirement: requirement,
                                       type: description.0,
                                       value: description.1,
                                       prevToken: currentToken)
            tokens.append(currentToken!)
        }
        
        return tokens
    }
}
