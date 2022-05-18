//
//  Parser Tests.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-14
//

import XCTest
@testable import Required

final class ParserTests: XCTestCase {
    
    // MARK: Overall parser tests
    
    func testParse_SafariDesignatedRequirement() throws {
        /* Parse tree:
         and
         |--identifier com.apple.Safari
         \--anchor apple
         */
        let requirement =
        """
        identifier "com.apple.Safari" and anchor apple
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        let expression = try Parser.parse(tokens: tokens)
        
        XCTAssert(expression is AndStatement)
        let andExpression = expression as! AndStatement
        
        XCTAssert(andExpression.lhs is IdentifierConstraint)
        let identifierConstraint = andExpression.lhs as! IdentifierConstraint
        XCTAssertEqual(identifierConstraint.constant.value, "com.apple.Safari")
        
        XCTAssert(andExpression.rhs is CertificateConstraint)
        let certificateConstraint = andExpression.rhs as! CertificateConstraint
        switch certificateConstraint {
            case .wholeApple(_, _):
                break
            default:
                XCTFail("Expected wholeApple")
        }
    }
    
    func testParse_ElaborateRequirement() throws {
        /* Parse tree:
         and
         |--()
         |  \--or
         |     |--and
         |     |  |--anchor trusted
         |     |  \--cdhash d5800a216ffd83b116b7b0f6047cb7f570f49329
         |     \--and
         |        |--and
         |        |  |--and
         |        |  |  |--anchor apple generic
         |        |  |  \--certificate - 1 [ field.1.2.840.113635.100.6.2.6 ]
         |        |  \--info [ CFBundleVersion ] >= 17.4.2
         |        \--certificate leaf [ subject.OU ] = 59GAB85EFG
         \--!
            \--!
               \--identifier com.apple.dt.Xcode
         */
        let requirement =
        """
        (anchor trusted and cdhash H"d5800a216ffd83b116b7b0f6047cb7f570f49329" or anchor apple generic and certificate -1[field.1.2.840.113635.100.6.2.6] /* exists */ and info[CFBundleVersion] >= "17.4.2" and certificate leaf[subject.OU] = "59GAB85EFG") and !!identifier "com.apple.dt.Xcode"
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        let expression = try Parser.parse(tokens: tokens)
        
        // and between initial parentheses and negated identifier expresion
        XCTAssert(expression is AndStatement)
        let andExpression = expression as! AndStatement
        
        // parentheses expression
        XCTAssert(andExpression.lhs is ParenthesesStatement)
        let parenthesesExpression = andExpression.lhs as! ParenthesesStatement
        
        // or expression in parentheses expression
        XCTAssert(parenthesesExpression.statement is OrStatement)
        let orExpression = parenthesesExpression.statement as! OrStatement
        
        // and expression before the or
        XCTAssert(orExpression.lhs is AndStatement)
        let lhsAndExpresion = orExpression.lhs as! AndStatement
        
        // anchor apple generic
        XCTAssert(lhsAndExpresion.lhs is CertificateConstraint)
        switch (lhsAndExpresion.lhs as! CertificateConstraint) {
            case .trusted(_, _):
                break
            default:
                XCTFail("Expected trusted")
        }
        
        // cdhash H"d5800a216ffd83b116b7b0f6047cb7f570f49329"
        XCTAssert(lhsAndExpresion.rhs is CodeDirectoryHashConstraint)
        switch (lhsAndExpresion.rhs as! CodeDirectoryHashConstraint) {
            case .hashConstant(_, let hashConstant):
                XCTAssertEqual(hashConstant.value, "d5800a216ffd83b116b7b0f6047cb7f570f49329")
            default:
                XCTFail("Expected hashConstant")
        }
        
        // Last and after the or expression
        XCTAssert(orExpression.rhs is AndStatement)
        let rhsAnd1Expression = orExpression.rhs as! AndStatement
        
        // certificate leaf[subject.OU] = "59GAB85EFG"
        XCTAssert(rhsAnd1Expression.rhs is CertificateConstraint)
        switch (rhsAnd1Expression.rhs as! CertificateConstraint) {
            case .element(let position, let element, let match):
                switch position {
                    case .leaf(_, _):
                        break
                    default:
                        XCTFail("Expected leaf")
                }
                XCTAssertEqual(element.value, "subject.OU")
                
                switch match {
                    case .infix(let operation, let string):
                        XCTAssert(operation is EqualsSymbol)
                        XCTAssertEqual(string.value, "59GAB85EFG")
                    default:
                        XCTFail("Expected infix")
                }
            default:
                XCTFail("Expected element")
        }
        
        // Second to last and after the or expression
        XCTAssert(rhsAnd1Expression.lhs is AndStatement)
        let rhsAnd2Expression = (rhsAnd1Expression.lhs as! AndStatement)
        
        // info[CFBundleVersion] >= 17.4.2
        XCTAssert(rhsAnd2Expression.rhs is InfoConstraint)
        let infoConstraint = (rhsAnd2Expression.rhs as! InfoConstraint)
        XCTAssertEqual(infoConstraint.key.value, "CFBundleVersion")
        switch infoConstraint.match {
            case .infix(let operation, let string):
                XCTAssert(operation is GreaterThanOrEqualToSymbol)
                XCTAssertEqual(string.value, "17.4.2")
            default:
                XCTFail("Expected infix")
        }
        
        // First and after the or expression
        XCTAssert(rhsAnd2Expression.lhs is AndStatement)
        let rhsAnd3Expression = (rhsAnd2Expression.lhs as! AndStatement)
        
        // anchor apple generic
        XCTAssert(rhsAnd3Expression.lhs is CertificateConstraint)
        switch (rhsAnd3Expression.lhs as! CertificateConstraint) {
            case .wholeAppleGeneric(_, _, _):
                break
            default:
                XCTFail("Expected wholeAppleGeneric")
        }
        
        // certificate -1[field.1.2.840.113635.100.6.2.6]
        XCTAssert(rhsAnd3Expression.rhs is CertificateConstraint)
        switch (rhsAnd3Expression.rhs as! CertificateConstraint) {
            case .elementImplicitExists(let position, let element):
                switch position {
                    case .negativeFromAnchor(_, _, let integer):
                        XCTAssertEqual(integer.value, 1)
                    default:
                        XCTFail("Expected negativeFromAnchor")
                }
                XCTAssertEqual(element.value, "field.1.2.840.113635.100.6.2.6")
            default:
                XCTFail("Expected elementImplicitExists")
        }
        
        // initial negation after the first and
        XCTAssert(andExpression.rhs is NegationStatement)
        let negation1 = andExpression.rhs as! NegationStatement
        
        // second negation
        XCTAssert(negation1.statement is NegationStatement)
        let negation2 = negation1.statement as! NegationStatement
        
        // identifier com.apple.dt.Xcode
        XCTAssert(negation2.statement is IdentifierConstraint)
        let identifierConstraint = negation2.statement as! IdentifierConstraint
        switch identifierConstraint {
            case .implicitEquality(_, let string):
                XCTAssertEqual(string.value, "com.apple.dt.Xcode")
            default:
                XCTFail("Expected implicitEquality")
        }
    }
    
    
    
    // MARK: Identifier
    
    func testIdentifier_ExplicitEquality() throws {
        let requirement =
        """
        identifier = com.apple.Safari
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try IdentifierConstraint.attemptParse(tokens: tokens)!.0 as! IdentifierConstraint
        switch constraint {
            case .explicitEquality(_, _, let string):
                XCTAssertEqual(string.value, "com.apple.Safari")
            default:
                XCTFail("Expected explicitEquality operation")
        }
    }
    
    func testIdentifier_ImplicitEquality() throws {
        let requirement =
        """
        identifier "com.apple.Safari"
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try IdentifierConstraint.attemptParse(tokens: tokens)!.0 as! IdentifierConstraint
        switch constraint {
            case .implicitEquality(_, let string):
                XCTAssertEqual(string.value, "com.apple.Safari")
            default:
                XCTFail("Expected implicitEquality operation")
                
        }
    }
    
    // MARK: Info
    
    func testInfo_Exists() throws {
        let requirement =
        """
        info [MySpecialMarker] exists
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try InfoConstraint.attemptParse(tokens: tokens)!.0 as! InfoConstraint
        XCTAssertEqual(constraint.key.value, "MySpecialMarker")
        switch constraint.match {
            case .unarySuffix(_):
                break
            default:
                XCTFail("Expected unarySuffix operation")
        }
    }
    
    func testInfo_LessThan() throws {
        let requirement =
        """
        info [CFBundleShortVersionString] < "17.4"
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try InfoConstraint.attemptParse(tokens: tokens)!.0 as! InfoConstraint
        XCTAssertEqual(constraint.key.value, "CFBundleShortVersionString")
        switch constraint.match {
            case .infix(let comparison, let string):
                XCTAssert(comparison is LessThanSymbol)
                XCTAssertEqual(string.value, "17.4")
            default:
                XCTFail("Expected infix operation")
        }
    }
    
    // MARK: entitlement
    
    func testEntitlement_WildcardEqual() throws {
        let requirement =
        """
        entitlement ["com.apple.security.personal-information.calendars"] = tru*
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try EntitlementConstraint.attemptParse(tokens: tokens)!.0 as! EntitlementConstraint
        XCTAssertEqual(constraint.key.value, "com.apple.security.personal-information.calendars")
        switch constraint.match {
            case .infixEquals(_, let wildcardString):
                switch wildcardString {
                    case .postfixWildcard(let string, _):
                        XCTAssertEqual(string.value, "tru")
                    default:
                        XCTFail("Expected postfixWildcard")
                }
            default:
                XCTFail("Expected infixEquals operation")
        }
    }
    
    // MARK: Certificate
    
    func testCertificate_anchorTrusted() throws {
        let requirement =
        """
        anchor trusted
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CertificateConstraint.attemptParse(tokens: tokens)!.0 as! CertificateConstraint
        switch constraint {
            case .trusted(let position, _):
                switch position {
                    case .anchor(_):
                        break
                    default:
                        XCTFail("Expected anchor case")
                }
            default:
                XCTFail("Expected trusted case")
        }
    }
    
    func testCertificate_positionTrusted() throws {
        let requirement =
        """
        certificate -4 trusted
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CertificateConstraint.attemptParse(tokens: tokens)!.0 as! CertificateConstraint
        switch constraint {
            case .trusted(let position, _):
                switch position {
                    case .negativeFromAnchor(_, _, let integerSymbol):
                        XCTAssertEqual(integerSymbol.value, 4)
                    default:
                        XCTFail("Expected negativeFromAnchor")
                }
            default:
                XCTFail("Expected trusted case")
        }
    }
    
    func testCertificate_anchorApple() throws {
        let requirement =
        """
        anchor apple
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CertificateConstraint.attemptParse(tokens: tokens)!.0 as! CertificateConstraint
        switch constraint {
            case .wholeApple(_, _):
                break
            default:
                XCTFail("Expected wholeApple case")
        }
    }
    
    func testCertificate_anchorAppleGeneric() throws {
        let requirement =
        """
        anchor apple generic
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CertificateConstraint.attemptParse(tokens: tokens)!.0 as! CertificateConstraint
        switch constraint {
            case .wholeAppleGeneric(_, _, _):
                break
            default:
                XCTFail("Expected wholeAppleGeneric case")
        }
    }
    
    func testCertificate_anchorEqualHash() throws {
        let requirement =
        """
        anchor = H"0123456789ABCDEFFEDCBA98765432100A2BC5DA"
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CertificateConstraint.attemptParse(tokens: tokens)!.0 as! CertificateConstraint
        switch constraint {
            case .whole(let positionExpression, _, let hashConstant):
                switch positionExpression {
                    case .anchor(_):
                        break
                    default:
                        XCTFail("Expected anchor")
                }
                XCTAssertEqual(hashConstant.value, "0123456789ABCDEFFEDCBA98765432100A2BC5DA")
            default:
                XCTFail("Expected whole")
        }
    }
    
    func testCertificate_certificatePositionEqualHash() throws {
        let requirement =
        """
        certificate leaf = H"0123456789ABCDEFFEDCBA98765432100A2BC5DA"
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CertificateConstraint.attemptParse(tokens: tokens)!.0 as! CertificateConstraint
        switch constraint {
            case .whole(let positionExpression, _, let hashConstant):
                switch positionExpression {
                    case .leaf(_, _):
                        break
                    default:
                        XCTFail("Expected leaf case")
                }
                XCTAssertEqual(hashConstant.value, "0123456789ABCDEFFEDCBA98765432100A2BC5DA")
            default:
                XCTFail("Expected whole case")
        }
    }
    
    func testCertificate_elementMatchExpression() throws {
        let requirement =
        """
        certificate 2[field.42] = hello.world*
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CertificateConstraint.attemptParse(tokens: tokens)!.0 as! CertificateConstraint
        switch constraint {
            case .element(let position, let element, let match):
                switch position {
                    case .positiveFromLeaf(_, let integerSymbol):
                        XCTAssertEqual(integerSymbol.value, 2)
                    default:
                        XCTFail("Expected positiveFromLeaf case")
                }
                
                XCTAssertEqual(element.value, "field.42")
                
                switch match {
                    case .infixEquals(_, let wildcardString):
                        switch wildcardString {
                            case .postfixWildcard(let string, _):
                                XCTAssertEqual(string.value, "hello.world")
                            default:
                                XCTFail("Expected postfixWildcard case")
                        }
                    default:
                        XCTFail("Expected infixEquals case")
                }
            default:
                XCTFail("Expected element case")
                
        }
    }
    
    // MARK: Code Directory Hash
    
    func testCodeDirectoryHash_filePath() throws {
        let requirement =
        """
        cdhash "/path/to the/certificate.cer"
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CodeDirectoryHashConstraint.attemptParse(tokens: tokens)!.0 as! CodeDirectoryHashConstraint
        switch constraint {
            case .filePath(_, let string):
                XCTAssertEqual(string.value, "/path/to the/certificate.cer")
            default:
                XCTFail("Expected filePath case")
        }
    }
    
    func testCodeDirectoryHash_hashConstant() throws {
        let requirement =
        """
        cdhash H"d5800a216ffd83b116b7b0f6047cb7f570f49329"
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CodeDirectoryHashConstraint.attemptParse(tokens: tokens)!.0 as! CodeDirectoryHashConstraint
        switch constraint {
            case .hashConstant(_, let hashConstant):
                XCTAssertEqual(hashConstant.value, "d5800a216ffd83b116b7b0f6047cb7f570f49329")
            default:
                XCTFail("Expected hashConstant case")
        }
    }
    
    // MARK: match
    
    func testMatch_equal_noWildcards() throws {
        let requirement =
        """
        = hello
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let fragment = try MatchFragment.attemptParse(tokens: tokens)!.0
        switch fragment {
            case .infix(let comparison, let string):
                XCTAssert(comparison is EqualsSymbol)
                XCTAssertEqual(string.value, "hello")
            default:
                XCTFail("Expected infix operation")
        }
    }
    
    func testMatch_equal_bothWildcards() throws {
        let requirement =
        """
        = *hello*
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let fragment = try MatchFragment.attemptParse(tokens: tokens)!.0
        switch fragment {
            case .infixEquals(_, let wildcardString):
                switch wildcardString {
                    case .prefixAndPostfixWildcard(_, let string, _):
                        XCTAssertEqual(string.value, "hello")
                    default:
                        XCTFail("Expected prefixAndPostfixWildcard")
                }
            default:
                XCTFail("Expected infixEquals operation")
        }
    }
    
    func testMatch_equal_prefixWildcard() throws {
        let requirement =
        """
        = *hello
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let fragment = try MatchFragment.attemptParse(tokens: tokens)!.0
        switch fragment {
            case .infixEquals(_, let wildcardString):
                switch wildcardString {
                    case .prefixWildcard(_, let string):
                        XCTAssertEqual(string.value, "hello")
                    default:
                        XCTFail("Expected prefixWildcard")
                }
            default:
                XCTFail("Expected infixEquals operation")
        }
    }
    
    func testMatch_equal_postfixWildcard() throws {
        let requirement =
        """
        = hello*
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let fragment = try MatchFragment.attemptParse(tokens: tokens)!.0
        switch fragment {
            case .infixEquals(_, let wildcardString):
                switch wildcardString {
                    case .postfixWildcard(let string, _):
                        XCTAssertEqual(string.value, "hello")
                    default:
                        XCTFail("Expected postfixWildcard")
                }
            default:
                XCTFail("Expected infixEquals operation")
        }
    }
    
    func testMatch_exists() throws {
        let requirement =
        """
        exists
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let fragment = try MatchFragment.attemptParse(tokens: tokens)!.0
        switch fragment {
            case .unarySuffix(_):
                break
            default:
                XCTFail("Expected unarySuffix operation")
        }
    }
    
    func testMatch_greaterThanOrEqualTo() throws {
        let requirement =
        """
        >= hello
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let fragment = try MatchFragment.attemptParse(tokens: tokens)!.0
        switch fragment {
            case .infix(let comparison, let string):
                XCTAssert(comparison is GreaterThanOrEqualToSymbol)
                XCTAssertEqual(string.value, "hello")
            default:
                XCTFail("Expected infix operation")
        }
    }
}
