//
//  Validation Tests.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-19
//

import XCTest
import Required

final class EvaluationTests: XCTestCase {
    
    // MARK: Identifier
    
    func testIdentifierConstraint_evaluateForSelf_satisfied() throws {
        let identifierConstraint = try parse(
        """
        identifier "com.apple.xctest"
        """, asType: IdentifierConstraint.self)
        
        XCTAssertTrue(try identifierConstraint.evaluateForSelf().isSatisfied)
    }
    
    func testIdentifierConstraint_evaluateForSelf_notSatisfied() throws {
        let identifierConstraint = try parse(
        """
        identifier "com.apple.Safari"
        """, asType: IdentifierConstraint.self)
        
        XCTAssertFalse(try identifierConstraint.evaluateForSelf().isSatisfied)
    }
    
    func testIdentifierConstraint_evaluateForStaticCode_satisfied() throws {
        let identifierConstraint = try parse(
        """
        identifier com.example.TestCLT
        """, asType: IdentifierConstraint.self)
        
        XCTAssertTrue(try identifierConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    // MARK: Info
    
    func testInfoConstraint_evaluateForSelf_comparison() throws {
        let infoConstraint = try parse(
        """
        info[CFBundleVersion] > 196
        """, asType: InfoConstraint.self)
        
        XCTAssertTrue(try infoConstraint.evaluateForSelf().isSatisfied)
    }
    
    func testInfoConstraint_evaluateForStaticCode_comparison() throws {
        let infoConstraint = try parse(
        """
        info[CFBundleVersion] > 5.2.4
        """, asType: InfoConstraint.self)
        
        XCTAssertTrue(try infoConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    func testInfoConstraint_evaluateForStaticCode_doesNotExist() throws {
        let infoConstraint = try parse(
        """
        info[CFBundleSuperPower] exists
        """, asType: InfoConstraint.self)
        
        XCTAssertFalse(try infoConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
        
    // MARK: Entitlement
    
    func testEntitlementConstraint_evaluateForSelf_satisfied() throws {
        let entitlementConstraint = try parse(
        """
        entitlement["com.apple.security.get-task-allow"] exists
        """, asType: EntitlementConstraint.self)
        
        XCTAssertTrue(try entitlementConstraint.evaluateForSelf().isSatisfied)
    }
    
    func testEntitlementConstraint_evaluateForSelf_notSatisfied() throws {
        let entitlementConstraint = try parse(
        """
        entitlement["com.foobar.not-an-entitlement"] >= imagination.land
        """, asType: EntitlementConstraint.self)
        
        XCTAssertFalse(try entitlementConstraint.evaluateForSelf().isSatisfied)
    }
    
    func testEntitlementConstraint_evaluateForStaticCode_satisfied() throws {
        let entitlementConstraint = try parse(
        """
        entitlement["com.apple.developer.ClassKit-environment"] = *elop*
        """, asType: EntitlementConstraint.self)
        
        XCTAssertTrue(try entitlementConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    // MARK: Code directory
    
    func testCodeDirectoryHashConstraint() throws {
        let codeDirectoryHashConstraint = try parse(
        """
        cdhash H"2d95d400f14e84b7f2c08449d1fd6f9751f752f4"
        """, asType: CodeDirectoryHashConstraint.self)
        
        XCTAssert(try codeDirectoryHashConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    // MARK: Certificate
    
    func testCertificateConstraint_anchorApple() throws {
        let certificateConstraint = try parse(
        """
        anchor apple
        """, asType: CertificateConstraint.self)
        
        // We need to test this against an application from Apple that's "part of macOS"
        // Safari meets this criteria and should commonly exist on the system
        var staticCode: SecStaticCode?
        let path = URL(fileURLWithPath: "/Applications/Safari.app") as CFURL
        SecStaticCodeCreateWithPath(path, SecCSFlags(), &staticCode)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCode!).isSatisfied)
    }
    
    func testCertificateConstraint_anchorAppleGeneric() throws {
        let certificateConstraint = try parse(
        """
        anchor apple generic
        """, asType: CertificateConstraint.self)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    func testCertificateConstraint_hashConstant() throws {
        // This is SHA1 hash of the Apple Root CA cert
        let certificateConstraint = try parse(
        """
        anchor = H"611e5b662c593a08ff58d14ae22452d198df6c60"
        """, asType: CertificateConstraint.self)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    func testCertificateConstraint_hashFilePath() throws {
        // Construct a path to the certificate which is quoted and represents spaces as spaces (not percent encoded)
        let containingDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
        let certificateURL = URL(fileURLWithPath: "Apple Root CA.cer", relativeTo: containingDir).absoluteURL
        var pathComponents = certificateURL.pathComponents
        pathComponents.removeFirst() // removes the first element which is /
        let quotedCertificateString = "\"/\(pathComponents.joined(separator: "/"))\""
        
        let certificateConstraint = try parse(
        """
        anchor = \(quotedCertificateString)
        """, asType: CertificateConstraint.self)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    func testCertificateConstraint_element_match() throws {
        let certificateConstraint = try parse(
        """
        certificate leaf[subject.OU] = "R96J7HJPH8"
        """, asType: CertificateConstraint.self)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    func testCertificateConstraint_element_implicitExists() throws {
        let certificateConstraint = try parse(
        """
        certificate 1[field.1.2.840.113635.100.6.2.1]
        """, asType: CertificateConstraint.self)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    func testCertificateConstraint_trusted() throws {
        let certificateConstraint = try parse(
        """
        anchor trusted
        """, asType: CertificateConstraint.self)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    // MARK: Logical and
    
    func testLogicalAnd_bothTrue() throws {
        let andRequirement = try parse(
        """
        certificate leaf[subject.OU] = "R96J7HJPH8" and certificate 1[field.1.2.840.113635.100.6.2.1]
        """, asType: AndRequirement.self)
        
        XCTAssertTrue(try andRequirement.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    func testLogicalAnd_oneTrue() throws {
        let andRequirement = try parse(
        """
        certificate leaf[subject.OU] = "R96J7HJPH8" and entitlement["com.apple.developer.ClassKit-environment"] = prod
        """, asType: AndRequirement.self)
        
        XCTAssertFalse(try andRequirement.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    func testLogicalAnd_bothFalse() throws {
        let andRequirement = try parse(
        """
        certificate leaf[subject.OU] = "HELLO_WORLD" and entitlement["com.apple.developer.ClassKit-environment"] = prod
        """, asType: AndRequirement.self)
        
        XCTAssertFalse(try andRequirement.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    // MARK: Logical or
    
    func testLogicalOr_bothTrue() throws {
        let orRequirement = try parse(
        """
        certificate leaf[subject.OU] = "R96J7HJPH8" or certificate 1[field.1.2.840.113635.100.6.2.1]
        """, asType: OrRequirement.self)
        
        XCTAssertTrue(try orRequirement.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    func testLogicalOr_oneTrue() throws {
        let orRequirement = try parse(
        """
        certificate leaf[subject.OU] = "R96J7HJPH8" or entitlement["com.apple.developer.ClassKit-environment"] = prod
        """, asType: OrRequirement.self)
        
        XCTAssertTrue(try orRequirement.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    func testLogicalOr_bothFalse() throws {
        let orRequirement = try parse(
        """
        certificate leaf[subject.OU] = "HELLO_WORLD" or entitlement["com.apple.developer.ClassKit-environment"] = prod
        """, asType: OrRequirement.self)
        
        XCTAssertFalse(try orRequirement.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    // MARK: Negation
    
    func testNegation_nestedRequirementTrue() throws {
        let negatedRequirement = try parse(
        """
        !certificate leaf[subject.OU] = "R96J7HJPH8"
        """, asType: NegationRequirement.self)
        
        XCTAssertFalse(try negatedRequirement.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    func testNegation_nestedRequirementFalse() throws {
        let negatedRequirement = try parse(
        """
        !certificate leaf[subject.OU] = "HELLO_WORLD"
        """, asType: NegationRequirement.self)
        
        XCTAssertTrue(try negatedRequirement.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    // MARK: Parentheses
    
    func testParentheses_nestedRequirementTrue() throws {
        let parenthesesRequirement = try parse(
        """
        (certificate leaf[subject.OU] = "R96J7HJPH8")
        """, asType: ParenthesesRequirement.self)
        
        XCTAssertTrue(try parenthesesRequirement.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    func testParentheses_nestedRequirementFalse() throws {
        let parenthesesRequirement = try parse(
        """
        (certificate leaf[subject.OU] = "HELLO_WORLD")
        """, asType: ParenthesesRequirement.self)
        
        XCTAssertFalse(try parenthesesRequirement.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    // MARK: helper functions
    
    // Some tests are written against "self" which is the xctest runner which executes these tests:
    // /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Xcode/Agents/xctest
    
    // This is the command line tool TestCLT
    func staticCodeForTestExecutable() -> SecStaticCode {
        /*
         `codesign -dvvv` output:
         
         Identifier=com.example.TestCLT
         Format=Mach-O thin (x86_64)
         CodeDirectory v=20500 size=799 flags=0x10000(runtime) hashes=14+7 location=embedded
         Hash type=sha256 size=32
         CandidateCDHash sha256=2d95d400f14e84b7f2c08449d1fd6f9751f752f4
         CandidateCDHashFull sha256=2d95d400f14e84b7f2c08449d1fd6f9751f752f40c9a6fdc425da760f449de3c
         Hash choices=sha256
         CMSDigest=2d95d400f14e84b7f2c08449d1fd6f9751f752f40c9a6fdc425da760f449de3c
         CMSDigestType=2
         CDHash=2d95d400f14e84b7f2c08449d1fd6f9751f752f4
         Signature size=4783
         Authority=Apple Development: Joshua Kaplan (3U3GZ847WW)
         Authority=Apple Worldwide Developer Relations Certification Authority
         Authority=Apple Root CA
         Signed Time=Jun 9, 2022 at 11:12:00 PM
         Info.plist entries=2
         TeamIdentifier=R96J7HJPH8
         Runtime Version=12.1.0
         Sealed Resources=none
         Internal requirements count=1 size=184
         */
        
        /*
         `codesign -d --entitlements :-` output:
         
         <?xml version="1.0" encoding="UTF-8"?>
         <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
         <plist version="1.0">
         <dict>
             <key>com.apple.developer.ClassKit-environment</key>
             <string>development</string>
             <key>com.apple.security.app-sandbox</key>
             <true/>
             <key>com.apple.security.get-task-allow</key>
             <true/>
         </dict>
         </plist>
         */
        
        /*
         Designated requirement as visualized by this package:
         
         and
         |--and
         |  |--and
         |  |  |--identifier "com.example.TestCLT"
         |  |  \--anchor apple generic
         |  \--certificate leaf[subject.CN] = "Apple Development: Joshua Kaplan (3U3GZ847WW)"
         \--certificate 1[field.1.2.840.113635.100.6.2.1]
         */
        
        let containingDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
        let executableURL = URL(fileURLWithPath: "TestCLT", relativeTo: containingDir).absoluteURL
        
        var staticCode: SecStaticCode?
        SecStaticCodeCreateWithPath(executableURL as CFURL, SecCSFlags(), &staticCode)
        
        return staticCode!
    }
}
