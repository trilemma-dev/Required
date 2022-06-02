//
//  Requirements Validation.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-17
//

import XCTest

// This file doesn't test the Required framework, instead it's using Apple's Security framework to assert that
// various reqirements are in fact valid or invalid. The results of these are used in `ParserTests` and to inform the
// parser itself based on real world results.
final class RequirementsValidation: XCTestCase {
    
    func assertValidRequirement(_ text: String) {
        var requirement: SecRequirement?
        let result = SecRequirementCreateWithString(text as CFString, SecCSFlags(), &requirement)
        XCTAssertNotNil(requirement)
        XCTAssertEqual(result, errSecSuccess)
    }
    
    func assertInvalidRequirement(_ text: String) {
        var requirement: SecRequirement?
        let result = SecRequirementCreateWithString(text as CFString, SecCSFlags(), &requirement)
        XCTAssertNil(requirement)
        XCTAssertEqual(result, errSecCSReqInvalid)
    }
    
    // This tests various bugs with Apple's compiler relative to the public documentation
    func testAppleCompilerBugs() {
        // Apple's claim:
        //   String constants must be enclosed by double quotes (" ") unless the string contains only letters, digits,
        //   and periods (.), in which case the quotes are optional
        //
        // Observed:
        //   String constants starting with digits must be quoted
        assertInvalidRequirement(
        """
        info[CFBundleVersion] >= 17.4.2
        """
        )
        
        assertValidRequirement(
        """
        info[CFBundleVersion] >= "17.4.2"
        """
        )
        
        assertValidRequirement(
        """
        info[CFBundleVersion] >= hello
        """
        )
        
        assertInvalidRequirement(
        """
        certificate leaf[subject.OU] = 59GAB85EFG
        """
        )
        
        assertValidRequirement(
        """
        certificate leaf[subject.OU] = "59GAB85EFG"
        """
        )
        
        assertValidRequirement(
        """
        certificate leaf[subject.OU] = GA59B85EFG
        """
        )
        
        // Apple's claim:
        //   anchor — same as certificate root
        //
        // Observed:
        //   Only "anchor" can be used with "apple" and "apple generic"
        assertInvalidRequirement(
        """
        certificate root apple
        """
        )
        
        assertValidRequirement(
        """
        anchor apple
        """
        )
        
        assertInvalidRequirement(
        """
        certificate root apple generic
        """
        )
        
        assertValidRequirement(
        """
        anchor apple generic
        """
        )
        
        // Apple's claim:
        //   To check for the existence of any certificate field identified by its X.509 object identifier (OID), use
        //   the form
        //
        //     certificate position [field.OID] exists
        //
        // Observed:
        //   While this claim is true, there is an undocumented variant of this that omits the "exists" operator and is
        //   still valid while (seemingly) having the same semantics
        assertValidRequirement(
        """
        certificate leaf [field.1.2.840.113635.100.6.2.6]
        """
        )
        
        // Apple's claim:
        //   To check for the existence of any certificate field identified by its X.509 object identifier (OID), use
        //   the form
        //
        //     certificate position [field.OID] exists
        //
        // Observed:
        //   While this claim is true, it's also possible to perform (in)equality comparisons on such fields
        assertValidRequirement(
        """
        certificate leaf [field.1.2.840.113635.100.6.2.6] > hello
        """
        )
        
        // Apple's claim:
        //   The syntax "anchor trusted" is not a synonym for "certificate anchor trusted". Whereas the former checks
        //   all certificates in the signature, the latter checks only the anchor certificate.
        //
        // Observed:
        //   "certificate anchor trusted" is invalid.
        assertInvalidRequirement(
        """
        certificate anchor trusted
        """
        )
        
        // Apple's claim:
        //   The expression
        //
        //     info [key] match expression
        //
        //   succeeds if the value associated with the top-level key in the code’s info.plist file matches match
        //   expression, where match expression can include any of the operators listed in Logical Operators and
        //   Comparison Operations.
        //
        // Observed:
        //   Despite no mention of wildcard matching (which is mentioned for identifier, entitlement, and part of a
        //   certificate), such matching is supported.
        assertValidRequirement(
        """
        info[CFBundleIdentifier] = *hello*
        """
        )
    }
    
    func testValidRequirements() {
        assertValidRequirement(
        """
        identifier "com.apple.Safari" and anchor apple
        """
        )
        
        assertValidRequirement(
        """
        (anchor trusted and cdhash H"d5800a216ffd83b116b7b0f6047cb7f570f49329" or anchor apple generic and certificate -1[field.1.2.840.113635.100.6.2.6] /* exists */ and info[CFBundleVersion] >= "17.4.2" and certificate leaf[subject.OU] = "59GAB85EFG") and !!identifier "com.apple.dt.Xcode"
        """
        )
        
        assertValidRequirement(
        """
        identifier = com.apple.Safari
        """
        )
        
        assertValidRequirement(
        """
        identifier "com.apple.Safari"
        """
        )
        
        assertValidRequirement(
        """
        info [MySpecialMarker] exists
        """
        )
        
        assertValidRequirement(
        """
        info [CFBundleShortVersionString] < "17.4"
        """
        )
        
        assertValidRequirement(
        """
        anchor trusted
        """
        )
        
        assertValidRequirement(
        """
        certificate -4 trusted
        """
        )
        
        assertValidRequirement(
        """
        anchor apple
        """
        )
        
        assertValidRequirement(
        """
        anchor apple generic
        """
        )
        
        assertValidRequirement(
        """
        anchor = H"0123456789ABCDEFFEDCBA98765432100A2BC5DA"
        """
        )
        
        assertValidRequirement(
        """
        certificate leaf = H"0123456789ABCDEFFEDCBA98765432100A2BC5DA"
        """
        )
        
        assertValidRequirement(
        """
        certificate 2[field.42] = hello.world*
        """
        )
        
        assertValidRequirement(
        """
        cdhash H"d5800a216ffd83b116b7b0f6047cb7f570f49329"
        """
        )
    }
    
    
    /*
    func testEvaluationOfRequirements() {
        let text =
        """
        certificate leaf [field.1.2.840.113635.100.6.2.6] = hello
        """
    
        var requirement: SecRequirement?
        let result = SecRequirementCreateWithString(text as CFString, SecCSFlags(), &requirement)
        XCTAssertNotNil(requirement)
        XCTAssertEqual(result, errSecSuccess)
        
        var code: SecCode?
        SecCodeCopySelf(SecCSFlags(), &code)
        
        var staticCode: SecStaticCode?
        SecCodeCopyStaticCode(code!, SecCSFlags(), &staticCode)
        
        let validityResult = SecStaticCodeCheckValidity(staticCode!, SecCSFlags(), requirement)
        print(validityResult)
    }*/
}
