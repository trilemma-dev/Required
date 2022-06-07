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
         |--identifier "com.apple.Safari"
         \--anchor apple
         */
        let andRequirement = try parse(
        """
        identifier "com.apple.Safari" and anchor apple
        """, asType: AndRequirement.self)
        
        // identifier "com.apple.Safari"
        XCTAssert(andRequirement.lhs is IdentifierConstraint)
        let identifierConstraint = andRequirement.lhs as! IdentifierConstraint
        XCTAssertEqual(identifierConstraint.constant.value, "com.apple.Safari")
        
        // anchor apple
        XCTAssert(andRequirement.rhs is CertificateConstraint)
        let certificateConstraint = andRequirement.rhs as! CertificateConstraint
        switch certificateConstraint {
            case .wholeApple(_, _):
                break
            default:
                XCTFail("Expected wholeApple")
        }
    }
    
    func testParse_ElaborateRequirement() throws {
        /* Parse tree:
         or
         |--and
         |  |--()
         |  |  \--or
         |  |     |--and
         |  |     |  |--anchor trusted
         |  |     |  \--cdhash H"d5800a216ffd83b116b7b0f6047cb7f570f49329"
         |  |     \--and
         |  |        |--and
         |  |        |  |--and
         |  |        |  |  |--anchor apple generic
         |  |        |  |  \--certificate -1[field.1.2.840.113635.100.6.2.6]
         |  |        |  \--info[CFBundleVersion] >= "17.4.2"
         |  |        \--certificate leaf[subject.OU] = "59GAB85EFG"
         |  \--!
         |     \--!
         |        \--identifier "com.apple.dt.Xcode"
         \--entitlement["com.apple.security.app-sandbox"] exists
         */
        let orRequirement = try parse(
        """
        (anchor trusted and cdhash H"d5800a216ffd83b116b7b0f6047cb7f570f49329" or anchor apple generic and certificate -1[field.1.2.840.113635.100.6.2.6] /* exists */ and info[CFBundleVersion] >= "17.4.2" and certificate leaf[subject.OU] = "59GAB85EFG") and !!identifier "com.apple.dt.Xcode" or entitlement["com.apple.security.app-sandbox"] exists
        """, asType: OrRequirement.self)
        
        // and between initial parentheses and negated identifier requirement
        XCTAssert(orRequirement.lhs is AndRequirement)
        let andRequirement = orRequirement.lhs as! AndRequirement
        
        // parentheses requirement
        XCTAssert(andRequirement.lhs is ParenthesesRequirement)
        let parenthesesRequirement = andRequirement.lhs as! ParenthesesRequirement
        
        // or requirement in parentheses requirement
        XCTAssert(parenthesesRequirement.requirement is OrRequirement)
        let orInParenthesesRequirement = parenthesesRequirement.requirement as! OrRequirement
        
        // and requirement before the or
        XCTAssert(orInParenthesesRequirement.lhs is AndRequirement)
        let lhsAndRequirement = orInParenthesesRequirement.lhs as! AndRequirement
        
        // anchor apple generic
        XCTAssert(lhsAndRequirement.lhs is CertificateConstraint)
        switch (lhsAndRequirement.lhs as! CertificateConstraint) {
            case .trusted(_, _):
                break
            default:
                XCTFail("Expected trusted")
        }
        
        // cdhash H"d5800a216ffd83b116b7b0f6047cb7f570f49329"
        XCTAssert(lhsAndRequirement.rhs is CodeDirectoryHashConstraint)
        let cdHashConstraint = lhsAndRequirement.rhs as! CodeDirectoryHashConstraint
        XCTAssertEqual(cdHashConstraint.hashConstantSymbol.value, "d5800a216ffd83b116b7b0f6047cb7f570f49329")
        
        // Last and after the or in parentheses requirement
        XCTAssert(orInParenthesesRequirement.rhs is AndRequirement)
        let rhsAnd1Requirement = orInParenthesesRequirement.rhs as! AndRequirement
        
        // certificate leaf[subject.OU] = "59GAB85EFG"
        XCTAssert(rhsAnd1Requirement.rhs is CertificateConstraint)
        switch (rhsAnd1Requirement.rhs as! CertificateConstraint) {
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
        
        // Second to last and after the or requirement
        XCTAssert(rhsAnd1Requirement.lhs is AndRequirement)
        let rhsAnd2Requirement = (rhsAnd1Requirement.lhs as! AndRequirement)
        
        // info[CFBundleVersion] >= 17.4.2
        XCTAssert(rhsAnd2Requirement.rhs is InfoConstraint)
        let infoConstraint = (rhsAnd2Requirement.rhs as! InfoConstraint)
        XCTAssertEqual(infoConstraint.key.value, "CFBundleVersion")
        switch infoConstraint.match {
            case .infix(let operation, let string):
                XCTAssert(operation is GreaterThanOrEqualToSymbol)
                XCTAssertEqual(string.value, "17.4.2")
            default:
                XCTFail("Expected infix")
        }
        
        // First and after the or requirement
        XCTAssert(rhsAnd2Requirement.lhs is AndRequirement)
        let rhsAnd3Requirement = (rhsAnd2Requirement.lhs as! AndRequirement)
        
        // anchor apple generic
        XCTAssert(rhsAnd3Requirement.lhs is CertificateConstraint)
        switch (rhsAnd3Requirement.lhs as! CertificateConstraint) {
            case .wholeAppleGeneric(_, _, _):
                break
            default:
                XCTFail("Expected wholeAppleGeneric")
        }
        
        // certificate -1[field.1.2.840.113635.100.6.2.6]
        XCTAssert(rhsAnd3Requirement.rhs is CertificateConstraint)
        switch (rhsAnd3Requirement.rhs as! CertificateConstraint) {
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
        XCTAssert(andRequirement.rhs is NegationRequirement)
        let negation1 = andRequirement.rhs as! NegationRequirement
        
        // second negation
        XCTAssert(negation1.requirement is NegationRequirement)
        let negation2 = negation1.requirement as! NegationRequirement
        
        // identifier com.apple.dt.Xcode
        XCTAssert(negation2.requirement is IdentifierConstraint)
        let identifierConstraint = negation2.requirement as! IdentifierConstraint
        switch identifierConstraint {
            case .implicitEquality(_, let string):
                XCTAssertEqual(string.value, "com.apple.dt.Xcode")
            default:
                XCTFail("Expected implicitEquality")
        }
        
        // entitlement [ com.apple.security.app-sandbox ] exists
        XCTAssert(orRequirement.rhs is EntitlementConstraint)
        let entitlementConstraint = orRequirement.rhs as! EntitlementConstraint
        XCTAssertEqual(entitlementConstraint.key.value, "com.apple.security.app-sandbox")
        switch entitlementConstraint.match {
            case .unarySuffix(_):
                break
            default:
                XCTFail("Expected unarySuffix")
        }
    }
    
    func testParse_requirementSet() throws {
        let requirementSet = try parseRequirementSet(
        """
        designated => entitlement["com.apple.security.app-sandbox"] = true
        """)
        
        // designated => entitlement["com.apple.security.app-sandbox"] = true
        XCTAssertNotNil(requirementSet.requirements[.designated])
        let designatedRequirement = requirementSet.requirements[.designated]!
        
        // entitlement["com.apple.security.app-sandbox"] = true
        XCTAssert(designatedRequirement.requirement is EntitlementConstraint)
        let entitlementConstraint = designatedRequirement.requirement as! EntitlementConstraint
        XCTAssertEqual(entitlementConstraint.key.value, "com.apple.security.app-sandbox")
        switch entitlementConstraint.match {
            case .infix(_, let string):
                XCTAssertEqual(string.value, "true")
            default:
                XCTFail("Expected infix")
        }
    }
    
    // MARK: Identifier
    
    func testIdentifier_ExplicitEquality() throws {
        let requirement =
        """
        identifier = com.apple.Safari
        """
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CertificateConstraint.attemptParse(tokens: tokens)!.0 as! CertificateConstraint
        switch constraint {
            case .wholeHashConstant(let positionExpression, _, let hashConstant):
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CertificateConstraint.attemptParse(tokens: tokens)!.0 as! CertificateConstraint
        switch constraint {
            case .wholeHashConstant(let positionExpression, _, let hashConstant):
                switch positionExpression {
                    case .leaf(_, _):
                        break
                    default:
                        XCTFail("Expected leaf case")
                }
                XCTAssertEqual(hashConstant.value, "0123456789ABCDEFFEDCBA98765432100A2BC5DA")
            default:
                XCTFail("Expected wholeHashConstant case")
        }
    }
    
    func testCertificate_certificatePositionEqualHash_filePath() throws {
        let requirement =
        """
        certificate leaf = "/path/to/cert"
        """
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CertificateConstraint.attemptParse(tokens: tokens)!.0 as! CertificateConstraint
        switch constraint {
            case .wholeHashFilePath(let positionExpression, _, let filePath):
                switch positionExpression {
                    case .leaf(_, _):
                        break
                    default:
                        XCTFail("Expected leaf case")
                }
                XCTAssertEqual(filePath.value, "/path/to/cert")
            default:
                XCTFail("Expected wholeHashFilePath case")
        }
    }
    
    func testCertificate_elementMatchExpression() throws {
        let requirement =
        """
        certificate 2[field.42] = hello.world*
        """
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
    
    func testCodeDirectoryHash() throws {
        let requirement =
        """
        cdhash H"d5800a216ffd83b116b7b0f6047cb7f570f49329"
        """
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
        let constraint = try CodeDirectoryHashConstraint.attemptParse(tokens: tokens)!.0 as! CodeDirectoryHashConstraint
        XCTAssertEqual(constraint.hashConstantSymbol.value, "d5800a216ffd83b116b7b0f6047cb7f570f49329")
    }
    
    // MARK: match
    
    func testMatch_equal_noWildcards() throws {
        let requirement =
        """
        = hello
        """
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
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
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        
        let fragment = try MatchFragment.attemptParse(tokens: tokens)!.0
        switch fragment {
            case .infix(let comparison, let string):
                XCTAssert(comparison is GreaterThanOrEqualToSymbol)
                XCTAssertEqual(string.value, "hello")
            default:
                XCTFail("Expected infix operation")
        }
    }
    
    // MARK: RequirementSet
    
    func testRequirementSet_oneRequirement() throws {
        let requirement =
        """
        designated => entitlement["com.apple.security.app-sandbox"] = true
        """
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        let requirementSet = try RequirementSet.attemptParse(tokens: tokens)!
        
        // designated => entitlement["com.apple.security.app-sandbox"] = true
        XCTAssertNotNil(requirementSet.requirements[.designated])
        let designatedRequirement = requirementSet.requirements[.designated]!
        
        // entitlement["com.apple.security.app-sandbox"] = true
        XCTAssert(designatedRequirement.requirement is EntitlementConstraint)
        let entitlementConstraint = designatedRequirement.requirement as! EntitlementConstraint
        XCTAssertEqual(entitlementConstraint.key.value, "com.apple.security.app-sandbox")
        switch entitlementConstraint.match {
            case .infix(_, let string):
                XCTAssertEqual(string.value, "true")
            default:
                XCTFail("Expected infix")
        }
    }
    
    func testRequirementSet_twoRequirements() throws {
        let requirement =
        """
        host => anchor apple and identifier com.apple.perl designated => entitlement["com.apple.security.app-sandbox"] = true
        """
        let tokens = try Tokenizer.tokenize(text: requirement).strippingWhitespaceAndComments()
        let requirementSet = try RequirementSet.attemptParse(tokens: tokens)!
        
        // host => anchor apple and identifier com.apple.perl
        XCTAssertNotNil(requirementSet.requirements[.host])
        let hostRequirement = requirementSet.requirements[.host]!
        
        // anchor apple and identifier com.apple.perl
        XCTAssert(hostRequirement.requirement is AndRequirement)
        let hostAndStatement = hostRequirement.requirement as! AndRequirement
        
        // anchor apple
        XCTAssert(hostAndStatement.lhs is CertificateConstraint)
        let certificateConstraint = hostAndStatement.lhs as! CertificateConstraint
        switch certificateConstraint {
            case .wholeApple(_, _):
                break
            default:
                XCTFail("expected wholeApple")
        }
        
        // identifier com.apple.perl
        XCTAssert(hostAndStatement.rhs is IdentifierConstraint)
        let identifierConstraint = hostAndStatement.rhs as! IdentifierConstraint
        switch identifierConstraint {
            case .implicitEquality(_, let string):
                XCTAssertEqual(string.value, "com.apple.perl")
            default:
                XCTFail("Expected implicitEquality")
        }
        
        
        // designated => entitlement["com.apple.security.app-sandbox"] = true
        XCTAssertNotNil(requirementSet.requirements[.designated])
        let designatedRequirement = requirementSet.requirements[.designated]!
        
        // entitlement["com.apple.security.app-sandbox"] = true
        XCTAssert(designatedRequirement.requirement is EntitlementConstraint)
        let entitlementConstraint = designatedRequirement.requirement as! EntitlementConstraint
        XCTAssertEqual(entitlementConstraint.key.value, "com.apple.security.app-sandbox")
        switch entitlementConstraint.match {
            case .infix(_, let string):
                XCTAssertEqual(string.value, "true")
            default:
                XCTFail("Expected infix")
        }
    }
}
