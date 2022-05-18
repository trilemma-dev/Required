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
        expression.description.prettyPrint()
        
        XCTAssert(expression is AndExpression)
        let andExpression = expression as! AndExpression
        
        XCTAssert(andExpression.lhsExpression is IdentifierExpression)
        let identifierExpression = andExpression.lhsExpression as! IdentifierExpression
        XCTAssertEqual(identifierExpression.constant.value, "com.apple.Safari")
        
        XCTAssert(andExpression.rhsExpression is CertificateExpression)
        let certificateExpression = andExpression.rhsExpression as! CertificateExpression
        switch certificateExpression {
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
        XCTAssert(expression is AndExpression)
        let andExpression = expression as! AndExpression
        
        // parentheses expression
        XCTAssert(andExpression.lhsExpression is ParenthesesExpression)
        let parenthesesExpression = andExpression.lhsExpression as! ParenthesesExpression
        
        // or expression in parentheses expression
        XCTAssert(parenthesesExpression.expression is OrExpression)
        let orExpression = parenthesesExpression.expression as! OrExpression
        
        // and expression before the or
        XCTAssert(orExpression.lhsExpression is AndExpression)
        let lhsAndExpresion = orExpression.lhsExpression as! AndExpression
        
        // anchor apple generic
        XCTAssert(lhsAndExpresion.lhsExpression is CertificateExpression)
        switch (lhsAndExpresion.lhsExpression as! CertificateExpression) {
            case .trusted(_, _):
                break
            default:
                XCTFail("Expected trusted")
        }
        
        // cdhash H"d5800a216ffd83b116b7b0f6047cb7f570f49329"
        XCTAssert(lhsAndExpresion.rhsExpression is CodeDirectoryHashExpression)
        switch (lhsAndExpresion.rhsExpression as! CodeDirectoryHashExpression) {
            case .hashConstant(_, let hashConstant):
                XCTAssertEqual(hashConstant.value, "d5800a216ffd83b116b7b0f6047cb7f570f49329")
            default:
                XCTFail("Expected hashConstant")
        }
        
        // Last and after the or expression
        XCTAssert(orExpression.rhsExpression is AndExpression)
        let rhsAnd1Expression = orExpression.rhsExpression as! AndExpression
        
        // certificate leaf[subject.OU] = "59GAB85EFG"
        XCTAssert(rhsAnd1Expression.rhsExpression is CertificateExpression)
        switch (rhsAnd1Expression.rhsExpression as! CertificateExpression) {
            case .element(let position, _, let key, _, let match):
                switch position {
                    case .leaf(_, _):
                        break
                    default:
                        XCTFail("Expected leaf")
                }
                XCTAssertEqual(key.value, "subject.OU")
                
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
        XCTAssert(rhsAnd1Expression.lhsExpression is AndExpression)
        let rhsAnd2Expression = (rhsAnd1Expression.lhsExpression as! AndExpression)
        
        // info[CFBundleVersion] >= 17.4.2
        XCTAssert(rhsAnd2Expression.rhsExpression is InfoExpression)
        let infoExpression = (rhsAnd2Expression.rhsExpression as! InfoExpression)
        XCTAssertEqual(infoExpression.keySymbol.value, "CFBundleVersion")
        switch infoExpression.matchExpression {
            case .infix(let operation, let string):
                XCTAssert(operation is GreaterThanOrEqualToSymbol)
                XCTAssertEqual(string.value, "17.4.2")
            default:
                XCTFail("Expected infix")
        }
        
        // First and after the or expression
        XCTAssert(rhsAnd2Expression.lhsExpression is AndExpression)
        let rhsAnd3Expression = (rhsAnd2Expression.lhsExpression as! AndExpression)
        
        // anchor apple generic
        XCTAssert(rhsAnd3Expression.lhsExpression is CertificateExpression)
        switch (rhsAnd3Expression.lhsExpression as! CertificateExpression) {
            case .wholeAppleGeneric(_, _, _):
                break
            default:
                XCTFail("Expected wholeAppleGeneric")
        }
        
        // certificate -1[field.1.2.840.113635.100.6.2.6]
        XCTAssert(rhsAnd3Expression.rhsExpression is CertificateExpression)
        switch (rhsAnd3Expression.rhsExpression as! CertificateExpression) {
            case .elementImplicitExists(let position, _, let string, _):
                switch position {
                    case .negativeFromAnchor(_, _, let integer):
                        XCTAssertEqual(integer.value, 1)
                    default:
                        XCTFail("Expected negativeFromAnchor")
                }
                XCTAssertEqual(string.value, "field.1.2.840.113635.100.6.2.6")
            default:
                XCTFail("Expected elementImplicitExists")
        }
        
        // initial negation after the first and
        XCTAssert(andExpression.rhsExpression is NegationExpression)
        let negation1 = andExpression.rhsExpression as! NegationExpression
        
        // second negation
        XCTAssert(negation1.expression is NegationExpression)
        let negation2 = negation1.expression as! NegationExpression
        
        // identifier com.apple.dt.Xcode
        XCTAssert(negation2.expression is IdentifierExpression)
        let identifierExpression = negation2.expression as! IdentifierExpression
        switch identifierExpression {
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
        
        let expression = try IdentifierExpression.attemptParse(tokens: tokens)!.0 as! IdentifierExpression
        switch expression {
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
        
        let expression = try IdentifierExpression.attemptParse(tokens: tokens)!.0 as! IdentifierExpression
        switch expression {
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
        
        let expression = try InfoExpression.attemptParse(tokens: tokens)!.0 as! InfoExpression
        XCTAssertEqual(expression.keySymbol.value, "MySpecialMarker")
        switch expression.matchExpression {
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
        
        let expression = try InfoExpression.attemptParse(tokens: tokens)!.0 as! InfoExpression
        XCTAssertEqual(expression.keySymbol.value, "CFBundleShortVersionString")
        switch expression.matchExpression {
            case .infix(let comparison, let string):
                XCTAssert(comparison is LessThanSymbol)
                XCTAssertEqual(string.rawValue, "\"17.4\"")
                XCTAssertEqual(string.value, "17.4")
            default:
                XCTFail("Expected infix operation")
        }
    }
    
    // MARK: Certificate
    
    func testCertificate_anchorTrusted() throws {
        let requirement =
        """
        anchor trusted
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let expression = try CertificateExpression.attemptParse(tokens: tokens)!.0 as! CertificateExpression
        switch expression {
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
        
        let expression = try CertificateExpression.attemptParse(tokens: tokens)!.0 as! CertificateExpression
        switch expression {
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
        
        let expression = try CertificateExpression.attemptParse(tokens: tokens)!.0 as! CertificateExpression
        switch expression {
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
        
        let expression = try CertificateExpression.attemptParse(tokens: tokens)!.0 as! CertificateExpression
        switch expression {
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
        
        let expression = try CertificateExpression.attemptParse(tokens: tokens)!.0 as! CertificateExpression
        switch expression {
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
        
        let expression = try CertificateExpression.attemptParse(tokens: tokens)!.0 as! CertificateExpression
        switch expression {
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
        
        let expression = try CertificateExpression.attemptParse(tokens: tokens)!.0 as! CertificateExpression
        switch expression {
            case .element(let position, _, let element, _, let match):
                switch position {
                    case .positiveFromLeaf(_, let integerSymbol):
                        XCTAssertEqual(integerSymbol.value, 2)
                    default:
                        XCTFail("Expected positiveFromLeaf case")
                }
                
                XCTAssertEqual(element.value, "field.42")
                
                switch match {
                    case .infixEquals(_, let stringExpression):
                        switch stringExpression {
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
        
        let expression = try CodeDirectoryHashExpression.attemptParse(tokens: tokens)!.0 as! CodeDirectoryHashExpression
        switch expression {
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
        
        let expression = try CodeDirectoryHashExpression.attemptParse(tokens: tokens)!.0 as! CodeDirectoryHashExpression
        switch expression {
            case .hashConstant(_, let hashConstant):
                XCTAssertEqual(hashConstant.value, "d5800a216ffd83b116b7b0f6047cb7f570f49329")
            default:
                XCTFail("Expected hashConstant case")
        }
    }
    
    // MARK: match expression
    
    func testMatchExpression_equal_noWildcards() throws {
        let requirement =
        """
        = hello
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let expression = try MatchExpression.attemptParse(tokens: tokens)!.0
        switch expression {
            case .infix(let comparison, let string):
                XCTAssert(comparison is EqualsSymbol)
                XCTAssertEqual(string.value, "hello")
            default:
                XCTFail("Expected infix operation")
        }
    }
    
    func testMatchExpression_equal_bothWildcards() throws {
        let requirement =
        """
        = *hello*
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let expression = try MatchExpression.attemptParse(tokens: tokens)!.0
        switch expression {
            case .infixEquals(_, let stringExpression):
                switch stringExpression {
                    case .prefixAndPostfixWildcard(_, let string, _):
                        XCTAssertEqual(string.value, "hello")
                    default:
                        XCTFail("Expected prefixAndPostfixWildcard")
                }
            default:
                XCTFail("Expected infixEquals operation")
        }
    }
    
    func testMatchExpression_equal_prefixWildcard() throws {
        let requirement =
        """
        = *hello
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let expression = try MatchExpression.attemptParse(tokens: tokens)!.0
        switch expression {
            case .infixEquals(_, let stringExpression):
                switch stringExpression {
                    case .prefixWildcard(_, let string):
                        XCTAssertEqual(string.value, "hello")
                    default:
                        XCTFail("Expected prefixWildcard")
                }
            default:
                XCTFail("Expected infixEquals operation")
        }
    }
    
    func testMatchExpression_equal_postfixWildcard() throws {
        let requirement =
        """
        = hello*
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let expression = try MatchExpression.attemptParse(tokens: tokens)!.0
        switch expression {
            case .infixEquals(_, let stringExpression):
                switch stringExpression {
                    case .postfixWildcard(let string, _):
                        XCTAssertEqual(string.value, "hello")
                    default:
                        XCTFail("Expected prefixWildcard")
                }
            default:
                XCTFail("Expected infixEquals operation")
        }
    }
    
    func testMatchExpression_exists() throws {
        let requirement =
        """
        exists
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let expression = try MatchExpression.attemptParse(tokens: tokens)!.0
        switch expression {
            case .unarySuffix(_):
                break
            default:
                XCTFail("Expected unarySuffix operation")
        }
    }
    
    func testMatchExpression_greaterThanOrEqualTo() throws {
        let requirement =
        """
        >= hello
        """
        let tokens = try Tokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        
        let expression = try MatchExpression.attemptParse(tokens: tokens)!.0
        switch expression {
            case .infix(let comparison, let string):
                XCTAssert(comparison is GreaterThanOrEqualToSymbol)
                XCTAssertEqual(string.value, "hello")
            default:
                XCTFail("Expected infix operation")
        }
    }    
    
    
    func testThisIsARequirement3() {
        //!!entitlement["foo bar"] <= hello.world.yeah
        // certificate root[field.100] >= hello
        // anchor[field.100] > goodbye
        let text = """
        anchor[field.42]
        """ as CFString
        var requirement: SecRequirement?
        let result = SecRequirementCreateWithString(text, SecCSFlags(), &requirement)
        
        print(result, requirement)
        
        // Succeeds:
        //  anchor[field.42] = hello.world*
        //  anchor = H"d5800a216ffd83b116b7b0f6047cb7f570f49329"
        //  anchor[field.42]
        //  anchor[field.42] exists
    }

    
    /*
    
    
    func testThisIsARequirement() {
        let text = """
        !entitlement["foo bar"] <= hello.world.yeah
        """ as CFString
        var requirement: SecRequirement?
        let result = SecRequirementCreateWithString(text, SecCSFlags(), &requirement)
        
        print(result, requirement)
    }
    
    func testThisIsARequirement2() {
        // info[MyValue] = H"0123456789ABCDEFFEDCBA98765432100A2BC5DA"
        let text = """
        info[MyValue] = hello.world*
        """ as CFString
        var requirement: SecRequirement?
        let result = SecRequirementCreateWithString(text, SecCSFlags(), &requirement)
        
        print(result, requirement)
    }
    
    
    func testWhatever() throws {
        let requirement =
        """
        identifier "com.apple.Safari" and anchor apple
        """
        let tokens = try CSRTokenizer.tokenize(requirement: requirement)
        
        CSRParser.parse(tokens: tokens)
    }
    
    func testIdentifier() throws {
        let requirement =
        """
        identifier "com.apple.Safari"
        """
        let tokens = try CSRTokenizer.tokenize(requirement: requirement).strippingWhitespaceAndComments()
        for token in tokens {
            print(token)
        }
        print("-------")
        let result = try IdentifierExpression.attemptParse(tokens: tokens)
        print(result)
    }
     */
}
