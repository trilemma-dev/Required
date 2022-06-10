//
//  CertificateConstraint+Evaluate.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-20
//

import Foundation
import Security

extension CertificateConstraint {
    func evaluateForSelf() throws -> Evaluation {
        try evaluateForStaticCode(try SecCode.current.asStaticCode())
    }
    
    func evaluateForStaticCode(_ staticCode: SecStaticCode) throws -> Evaluation {
        let signingInfo = try staticCode.readSigningInformation(options: [.signingInformation])
        guard let certificates = signingInfo[.infoCertificates] as? [SecCertificate], !certificates.isEmpty else {
            return .constraintNotSatisfied(self, explanation: "No certificates present")
        }
        
        switch self {
            case .wholeApple(_, _):
                return try evaluateAnchorApple(staticCode: staticCode)
            case .wholeAppleGeneric(_, _, _):
                return try evaluateAnchorAppleGeneric(certificates: certificates)
            case .wholeHashConstant(let position, _, let hashConstant):
                return try evaluateCertificateEqualsHash(position: position,
                                                         hashValue: hashConstant.value,
                                                         certificates: certificates)
            case .wholeHashFilePath(let position, _, let filePath):
                return try evaluateCertificateEqualsHashOfFilePath(position: position,
                                                                   filePath: filePath.value,
                                                                   certificates: certificates)
            case .element(let position, let element, let match):
                return try evaluateCertificatePartMatch(staticCode: staticCode,
                                                        position: position,
                                                        element: element,
                                                        match: match,
                                                        certificates: certificates)
            case .elementImplicitExists(let position, let element):
                return try evaluateCertificatePartMatchImplicitExists(staticCode: staticCode,
                                                                      position: position,
                                                                      element: element,
                                                                      certificates: certificates)
            case .trusted(let position, _):
                return try evaluateTrusted(staticCode: staticCode, position: position, certificates: certificates)
        }
    }
    
    private func evaluateAnchorApple(staticCode: SecStaticCode) throws -> Evaluation {
        // For Apple’s own code, signed by Apple, you can use the short form
        //   anchor apple
        //
        // Based on the open source implementation in `reqinterp.cpp` there are 3 different ways this can be satisified:
        // - If the code directory hash is in the trust cache
        //     - Apple publicly talks about it: https://support.apple.com/guide/security/trust-caches-sec7d38fbf97/
        //     - Under the hood this is AMFI (Apple Mobile File Integrity) which is entirely private
        //     - It might be possible to implement this, but it looks like it'd involve considerably private API usage
        // - If the root cert is a Apple Root CA and the intermediate cert has a specific common name and organization
        //     - This is relatively simple to implement
        // - If the leaf certificate is one of the "additional trusted certificates" available on the system
        //     - This involves making IORegistry calls with lots of undocumented string values
        //
        // Open source implementation: https://github.com/apple-oss-distributions/Security/blob/888e4834f996c2ab296402fa547edc47a842f484/OSX/libsecurity_codesigning/lib/reqinterp.cpp#L497
        //
        // So we'll rely on SecStaticCodeCheckValidity and try to generate a helpful explanation if it fails.
        try evaluateWithValidityCheck(staticCode: staticCode) {
            "This was not recognized as Apple's own code. To do so one of the following must be true:\n" +
            "The code directory hash (cdhash) is in the trust cache.\n" +
            "The root cert is an Apple Root CA and the intermediate cert's common name is Apple Code Signing " +
            "Certification Authority while its organization value is Apple Inc.\n" +
            "The leaf certificate is one of the additionally trusted certificates on this Mac."
        }
    }
    
    private func evaluateAnchorAppleGeneric(certificates: [SecCertificate]) throws -> Evaluation {
        // For code signed by Apple, including code signed using a signing certificate issued by Apple to
        // other developers, use the form
        //   anchor apple generic
        guard let rootCertificate = certificates.last else {
            return .constraintNotSatisfied(self, explanation: "No root certificate")
        }
        guard let rootCertificateDate = rootCertificate.data else {
            return .constraintNotSatisfied(self, explanation: "Root certificate contains no data")
        }
        
        // SHA256 hashes listed here: https://support.apple.com/en-us/HT212140
        let appleRootCAHashes = [
            // Apple Root CA
            Data([0xB0, 0xB1, 0x73, 0x0E, 0xCB, 0xC7, 0xFF, 0x45, 0x05, 0x14, 0x2C, 0x49, 0xF1, 0x29, 0x5E, 0x6E,
                  0xDA, 0x6B, 0xCA, 0xED, 0x7E, 0x2C, 0x68, 0xC5, 0xBE, 0x91, 0xB5, 0xA1, 0x10, 0x01, 0xF0, 0x24]),
            // Apple Root CA G2
            Data([0xC2, 0xB9, 0xB0, 0x42, 0xDD, 0x57, 0x83, 0x0E, 0x7D, 0x11, 0x7D, 0xAC, 0x55, 0xAC, 0x8A, 0xE1,
                  0x94, 0x07, 0xD3, 0x8E, 0x41, 0xD8, 0x8F, 0x32, 0x15, 0xBC, 0x3A, 0x89, 0x04, 0x44, 0xA0, 0x50]),
            // Apple Root CA G3
            Data([0x63, 0x34, 0x3A, 0xBF, 0xB8, 0x9A, 0x6A, 0x03, 0xEB, 0xB5, 0x7E, 0x9B, 0x3F, 0x5F, 0xA7, 0xBE,
                  0x7C, 0x4F, 0x5C, 0x75, 0x6F, 0x30, 0x17, 0xB3, 0xA8, 0xC4, 0x88, 0xC3, 0x65, 0x3E, 0x91, 0x79])
        ]
        
        guard appleRootCAHashes.contains(rootCertificateDate.sha256()) else {
            let commonName = (try? rootCertificate.commonName) ?? "common name could not be determined"
            let explanation = "Root certificate <\(commonName)> is not an Apple Root CA certificate"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
        
        return .constraintSatisfied(self)
    }
    
    private func evaluateCertificateEqualsHash(
        position: CertificatePosition,
        hashValue: String,
        certificates: [SecCertificate]
    ) throws -> Evaluation {
        guard let certificate = certificateForPosition(position, certificates: certificates) else {
            let explanation = "No certificate for position \(position.textForm)"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
        guard let certificateData = certificate.data else {
            let explanation = "No data representation for the certificate at position \(position.textForm)"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
        
        let actualHash = certificateData.sha1().hexEncodedString()
        let expectedHash = hashValue.lowercased()
        guard actualHash == expectedHash else {
            let commonName = (try? certificate.commonName) ?? "common name could not be determined"
            let explanation = "The certificate <\(commonName)>'s SHA1 hash did not match the expected value. " +
                              "Expected: \(expectedHash) Actual: \(actualHash)"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
        
        return .constraintSatisfied(self)
    }
    
    private func evaluateCertificateEqualsHashOfFilePath(
        position: CertificatePosition,
        filePath: String,
        certificates: [SecCertificate]
    ) throws -> Evaluation {
        do {
            // Attempt to hash and hexadecimal encode the certificate at the file path represented by the string
            let hashValue = try Data(contentsOf: URL(fileURLWithPath: filePath)).sha1().hexEncodedString()
            return try evaluateCertificateEqualsHash(position: position,
                                                     hashValue: hashValue,
                                                     certificates: certificates)
        } catch {
            let explanation = "Unable to hash file located at \(filePath)"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
    }
    
    private func evaluateCertificatePartMatch(
        staticCode: SecStaticCode,
        position: CertificatePosition,
        element: ElementExpression,
        match: MatchExpression,
        certificates: [SecCertificate]
    ) throws -> Evaluation {
        guard let certificate = certificateForPosition(position, certificates: certificates) else {
            let explanation = "No certificate present for position \(position.textForm)"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
        
        // Certificate field by OID
        if element.value.hasPrefix("field."), let periodIndex = element.value.firstIndex(of: ".") {
            // While a SecRequirement can be created with a field value and any match expression, the only case in which
            // it will satisfy a certificiate constraint is for an existence check. This is because the value associated
            // with an arbitrary OID field will be an arbitrary (and therefore unknown) format.
            switch match {
                case .unarySuffix(_):
                    // Short of parsing the certificate ourselves (or perhaps using OpenSSL), private functions will be
                    // needed to check for OID fields which are not returned by SecCertificateCopyValues (because
                    // they're not contained in Apple's public list of known OIDs).
                    //
                    // Doing this isn't too hard (it involves calling SecCertificateHasMarkerExtension and on older
                    // versions of macOS also requires calling CreateOidDataFromString first), but there's really no
                    // benefit to doing this as opposed to using SecStaticCodeCheckValidity.
                    return try evaluateWithValidityCheck(staticCode: staticCode) {
                        let oidStartIndex = element.value.index(after: periodIndex)
                        let oid = String(element.value[oidStartIndex..<element.value.endIndex])
                        let commonName = (try? certificate.commonName) ?? "common name could not be determined"
                        return "The certificate <\(commonName)> does not contain OID \(oid)"
                    }
                default:
                    let explanation = "Only `exists` comparisons satisfy OID fields"
                    return .constraintNotSatisfied(self, explanation: explanation)
            }
        } else { // Part of a certificate
            let actualValue: String?
            switch element.value {
                case "subject.CN":      actualValue = try certificate.commonName
                case "subject.C":       actualValue = try certificate.country
                case "subject.D":       actualValue = try certificate.description
                case "subject.L":       actualValue = try certificate.locality
                case "subject.O":       actualValue = try certificate.organization
                case "subject.OU":      actualValue = try certificate.organizationalUnit
                case "subject.STREET":  actualValue = try certificate.streetAddress
                default:
                    let explanation = "Invalid certificate element value: \(element.value). Value must be one of: " +
                        "subject.CN, subject.C, subject.D, subject.L, subject.O, subject.OU, or subject.STREET"
                    return .constraintNotSatisfied(self, explanation: explanation)
            }
            
            guard let actualValue = actualValue else {
                let commonName = (try? certificate.commonName) ?? "common name could not be determined"
                let explanation = "The certificate <\(commonName)> does not contain element \(element.value)"
                return .constraintNotSatisfied(self, explanation: explanation)
            }
            
            return match.evaluate(actualValue: actualValue, constraint: self)
        }
    }
    
    private func evaluateCertificatePartMatchImplicitExists(
        staticCode: SecStaticCode,
        position: CertificatePosition,
        element: ElementExpression,
        certificates: [SecCertificate]
    ) throws -> Evaluation {
        // Create a fake token such that a MatchExpression can be created which represents the implicit `exists`
        let fakeToken = Token(type: .identifier, rawValue: "exists", range: "".startIndex..<"".endIndex)
        let implicitExists = MatchExpression.unarySuffix(ExistsSymbol(sourceToken: fakeToken))
        
        return try evaluateCertificatePartMatch(staticCode: staticCode,
                                                position: position,
                                                element: element,
                                                match: implicitExists,
                                                certificates: certificates)
    }
    
    private func evaluateTrusted(
        staticCode: SecStaticCode,
        position: CertificatePosition,
        certificates: [SecCertificate]
    ) throws -> Evaluation {
        // The open source implementation for reqinterp shows that this is all implemented with private functions: https://github.com/apple-oss-distributions/Security/blob/888e4834f996c2ab296402fa547edc47a842f484/OSX/libsecurity_codesigning/lib/reqinterp.cpp#L575
        // SecTrustSettingsEvaluateCert is the function which ultimately performs the evaluation: https://github.com/apple-oss-distributions/Security/blob/154ef3d9d6f57f0374aa5d6c4b412e8653c1eebe/OSX/libsecurity_keychain/lib/SecTrustSettings.cpp#L527
        // Instead of calling these private functions, we'll fall back to SecStaticCodeCheckValidity.
        
        // But first check if the certificate exists, if it doesn't then we can provide a more specific explanation
        guard let certificate = certificateForPosition(position, certificates: certificates) else {
            let explanation = "No certificate present for position \(position.textForm)"
            return .constraintNotSatisfied(self, explanation: explanation)
        }
        
        return try evaluateWithValidityCheck(staticCode: staticCode) {
            "The certificate <\((try? certificate.commonName) ?? "common name could not be determined")> is not " +
            "marked as trusted in this system's Trust Settings database."
        }
    }
    
    // MARK: Helper functions
    
    private func certificateForPosition(
        _ position: CertificatePosition,
        certificates: [SecCertificate]
    ) -> SecCertificate? {
        // Certificate constraints refer to certificates in the certificate chain used to validate the signature.
        // Most uses of the certificate keyword accept an integer that indicates the position of the certificate in
        // the chain. Positive integers count from the leaf, the certificate that is part of the signer’s identity,
        // toward the anchor, the certificate of the trusted certificate authority. Negative integers count
        // backward from the anchor. For example, certificate 1 is the intermediate certificate that was used to
        // sign the leaf (that is, the signing certificate), which is itself certificate 0, while certificate -2
        // indicates the certificate that was directly signed by the anchor, which is represented as certificate
        // -1. This means that each certificate can be referenced in two different ways, depending on which way you
        // count from, as shown in Table 4-1.
        //
        //  ------------------------------------------------------------------------------
        //  | Anchor         | First intermediate | Second intermediate | Leaf           |
        //  -----------------+--------------------+---------------------+-----------------
        //  | certificate 3  | certificate 2      | certificate 1       | certificate 0  |
        //  -----------------+--------------------+---------------------+-----------------
        //  | certificate -1 | certificate -2     | certificate -3      | certificate -4 |
        //  ------------------------------------------------------------------------------
        //
        // For convenience, the following keywords are also defined:
        // - certificate root — the anchor certificate; same as certificate -1
        // - anchor - same as certificate root
        // - certificate leaf — the signing certificate; same as certificate 0
        
        // First certificate is leaf, last is root
        switch position {
            case .root(_, _):
                return certificates.last
            case .leaf(_, _):
                return certificates.first
            case .positiveFromLeaf(_, let integer):
                return integer.value < certificates.count ? certificates[Int(integer.value)] : nil
            case .negativeFromAnchor(_, _, let integer):
                let positiveFromLeafIndex = certificates.count - Int(integer.value)
                return positiveFromLeafIndex < certificates.count ? certificates[positiveFromLeafIndex] : nil
            case .anchor(_):
                return certificates.last
        }
    }
    
    private func evaluateWithValidityCheck(
        staticCode: SecStaticCode,
        explanationProvider: () -> String
    ) throws -> Evaluation {
        let result = SecStaticCodeCheckValidity(staticCode, SecCSFlags(), try SecRequirement.withString(self.textForm))
        if result == errSecSuccess {
            return .constraintSatisfied(self)
        } else if result == errSecCSReqFailed {
            return .constraintNotSatisfied(self, explanation: explanationProvider())
        } else if result == errSecCSBadResource {
            return .constraintNotSatisfied(self, explanation: "A sealed resource is missing or invalid")
        } else {
            throw SecurityError.statusCode(result)
        }
    }
}
