//
//  Validation Tests.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-19
//

import XCTest
import Required

final class EvaluationTests: XCTestCase {
    
    // MARK: helper functions
    
    // Some tests are written against "self" which is the xctest runner which executes these tests:
    // /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Xcode/Agents/xctest
    
    // This is a command line tool which lacks a certificate chain
    func staticCodeForTestExecutable() -> SecStaticCode {
        var staticCode: SecStaticCode?
        SecStaticCodeCreateWithPath(TestExecutables.intelx86_64, SecCSFlags(), &staticCode)
        
        return staticCode!
    }
    
    // TODO: stop testing against Safari for anything besides "anchor apple" and "anchor trusted"
    // Use a test bundle instead
    func staticCodeForSafari() -> SecStaticCode {
        var staticCode: SecStaticCode?
        let path = URL(fileURLWithPath: "/Applications/Safari.app") as CFURL
        SecStaticCodeCreateWithPath(path, SecCSFlags(), &staticCode)
        
        return staticCode!
    }
    
    // TODO: replace this with a test bundle
    func staticCodeForSpotify() -> SecStaticCode {
        var staticCode: SecStaticCode?
        let path = URL(fileURLWithPath: "/Applications/Spotify.app") as CFURL
        SecStaticCodeCreateWithPath(path, SecCSFlags(), &staticCode)
        
        return staticCode!
    }
    
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
        identifier "\(TestExecutables.Properties.Info.bundleIdentifier)"
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
        info[CFBundleVersion] > 1.2.0
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
        entitlement["com.foobar.not-an-entitlement"] = imagination.land
        """, asType: EntitlementConstraint.self)
        
        XCTAssertFalse(try entitlementConstraint.evaluateForSelf().isSatisfied)
    }
    
    func testEntitlementConstraint_evaluateForStaticCode_satisfied() throws {
        let entitlementConstraint = try parse(
        """
        entitlement["com.apple.security.get-task-allow"] exists
        """, asType: EntitlementConstraint.self)
        
        XCTAssertTrue(try entitlementConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    // MARK: Code directory
    
    func testCodeDirectoryHashConstraint() throws {
        let codeDirectoryHashConstraint = try parse(
        """
        cdhash H"1ddfea9341b8f664067f714970b4283ed315700f"
        """, asType: CodeDirectoryHashConstraint.self)
        
        XCTAssert(try codeDirectoryHashConstraint.evaluateForStaticCode(staticCodeForTestExecutable()).isSatisfied)
    }
    
    // MARK: Certificate
    
    func testCertificateConstraint_anchorApple() throws {
        let certificateConstraint = try parse(
        """
        anchor apple
        """, asType: CertificateConstraint.self)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForSafari()).isSatisfied)
    }
    
    func testCertificateConstraint_anchorAppleGeneric() throws {
        let certificateConstraint = try parse(
        """
        anchor apple generic
        """, asType: CertificateConstraint.self)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForSpotify()).isSatisfied)
    }
    
    func testCertificateConstraint_hashConstant() throws {
        // This is SHA1 hash of the Apple Root CA cert
        let certificateConstraint = try parse(
        """
        anchor = H"611e5b662c593a08ff58d14ae22452d198df6c60"
        """, asType: CertificateConstraint.self)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForSafari()).isSatisfied)
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
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForSafari()).isSatisfied)
    }
    
    func testCertificateConstraint_element_match() throws {
        let certificateConstraint = try parse(
        """
        certificate leaf[subject.OU] = "2FNC3A47ZF"
        """, asType: CertificateConstraint.self)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForSpotify()).isSatisfied)
    }
    
    func testCertificateConstraint_element_implicitExists() throws {
        let certificateConstraint = try parse(
        """
        certificate leaf[field.1.2.840.113635.100.6.1.13]
        """, asType: CertificateConstraint.self)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForSpotify()).isSatisfied)
    }
    
    func testCertificateConstraint_trusted() throws {
        let certificateConstraint = try parse(
        """
        anchor trusted
        """, asType: CertificateConstraint.self)
        
        XCTAssertTrue(try certificateConstraint.evaluateForStaticCode(staticCodeForSafari()).isSatisfied)
    }
}
