//
//  SecCertificate+Extensions.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-20
//

import Foundation
import Security

extension SecCertificate {
    
    static func withData(_ data: Data) throws -> SecCertificate {
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            throw SecurityError.unknown
        }
        
        return certificate
    }
    
    var data: Data? {
        SecCertificateCopyData(self) as Data?
    }
    
    var subjectSummary: String? {
        SecCertificateCopySubjectSummary(self) as String?
    }
    
    // subject.CN
    var commonName: String? {
        get throws {
            try oidValueForx509V1SubjectName(oid: "2.5.4.3")
        }
    }
    
    // subject.C
    var country: String? {
        get throws {
            try oidValueForx509V1SubjectName(oid: "2.5.4.6")
        }
    }
    
    // subject.L
    var locality: String? {
        get throws {
            try oidValueForx509V1SubjectName(oid: "2.5.4.7")
        }
    }
    
    var stateOrProvince: String? {
        get throws {
            try oidValueForx509V1SubjectName(oid: "2.5.4.8")
        }
    }
    
    // subject.STREET
    var streetAddress: String? {
        get throws {
            try oidValueForx509V1SubjectName(oid: "2.5.4.9")
        }
    }
    
    // subject.O
    var organization: String? {
        get throws {
            try oidValueForx509V1SubjectName(oid: "2.5.4.10")
        }
    }
    
    // subject.OU
    // In Apple issued developer certificates, this field contains the developer’s Team Identifier.
    var organizationalUnit: String? {
        get throws {
            try oidValueForx509V1SubjectName(oid: "2.5.4.11")
        }
    }
    
    // subject.D
    var description: String? {
        get throws {
            try oidValueForx509V1SubjectName(oid: "2.5.4.13")
        }
    }

    
    
    private func oidValueForx509V1SubjectName(oid: String) throws -> String? {
        if let value = try self.properties[.x509V1SubjectName]?.value,
           case .section(let properties) = value,
           let matchingProperty = properties.first(where: { $0.label == oid }),
            case .string(let matchingPropertyValue) = matchingProperty.value {
            return matchingPropertyValue
        }
        
        return nil
    }
    
    var emailAddresses: [String] {
        get throws {
            let nsArray = try SecurityError.throwIfFailure { array in
                SecCertificateCopyEmailAddresses(self, &array)
            } as NSArray
            
            // Apple documentation:
            //   On return, an array of zero or more CFStringRef elements, each containing one email address found
            //   in the certificate subject.
            //
            // So force casting this to an array of Swift strings should always succeed.
            return nsArray as! [String]
        }
    }
    
    @available(macOS 10.12.4, *)
    var normalizedIssuerSequence: Data {
        get throws {
            if let data = SecCertificateCopyNormalizedIssuerSequence(self) as Data? {
                return data
            } else {
                throw SecurityError.unknown
            }
        }
    }
    
    @available(macOS 10.12.4, *)
    var normalizedSubjectSequence: Data {
        get throws {
            if let data = SecCertificateCopyNormalizedSubjectSequence(self) as Data? {
                return data
            } else {
                throw SecurityError.unknown
            }
        }
    }
    
    @available(macOS 10.13, *)
    var serialNumberData: Data {
        get throws {
            var unmanagedError: Unmanaged<CFError>?
            defer { unmanagedError?.release() }
            guard let data = SecCertificateCopySerialNumberData(self, &unmanagedError) as Data? else {
                throw SecurityError.fromUnmanagedCFError(unmanagedError)
            }
            
            return data
        }
    }
    
    @available(macOS 10.14, *)
    var publicKey: SecKey? {
        SecCertificateCopyKey(self)
    }
    
    var properties: [CertificateOID : Property] {
        get throws {
            var unmanagedError: Unmanaged<CFError>?
            defer { unmanagedError?.release() }
            let cfDictionary = SecCertificateCopyValues(self, nil, &unmanagedError)
            guard let nsDictionary = cfDictionary as NSDictionary? else {
                throw SecurityError.fromUnmanagedCFError(unmanagedError)
            }
            
            // Convert types
            var dictionary = [CertificateOID : Property]()
            for oid in CertificateOID.allCases {
                if let nestedNSDictionary = nsDictionary[oid.rawValue] as? NSDictionary {
                    dictionary[oid] = Property(dictionary: nestedNSDictionary)
                }
            }
            
            return dictionary
        }
    }
    
    struct Property {
        let value: Value
        let label: String
        let localizedLabel: String
        
        fileprivate init(dictionary: NSDictionary) {
            self.label = dictionary[kSecPropertyKeyLabel] as! String
            self.localizedLabel = dictionary[kSecPropertyKeyLocalizedLabel] as! String
            if let value = dictionary[kSecPropertyKeyValue],
               let type = dictionary[kSecPropertyKeyType] as! CFString? {
                self.value = Value.forValue(value, ofType: type)
            } else {
                self.value = .none
            }
        }
        
        enum Value: CustomStringConvertible {
            /// A string describing a trust evaluation warning.
            case warning(String)
            /// A string describing a trust evaluation success.
            case success(String)
            /// In practice, an array of certicate properties.
            ///
            /// Official (erroneous) documentation: a string describing the name of a field in the certificate (CFSTR("Subject Name"), for example).
            case section([Property])
            /// A data object.
            case data(Data)
            /// A string.
            case string(String)
            /// A URL.
            case url(URL)
            /// In practice, a date.
            ///
            /// Official (erroneous) documentation: A string containing a date (or a string listing the bytes of an invalid date).
            case date(Date)
            /// An array.
            case array(Array<Any>)
            /// A number.
            case number(Double)
            /// A string containing the title (display name) of the certificate.
            case title(String)
            /// A string containing the reason for a trust evaluation failure.
            case error(String)
            /// A value of an unknown type or a known type with a value not matching Apple's documentation.
            case unknown(type: String, value: Any)
            /// There is no value
            case none
            
            fileprivate static func forValue(_ value: Any, ofType type: CFString) -> Value {
                switch type {
                    case kSecPropertyTypeWarning:
                        if let value = value as? String {
                            return .warning(value)
                        }
                    case kSecPropertyTypeSuccess:
                        if let value = value as? String {
                            return .success(value)
                        }
                    // Sections are a recursive case, where its value is an array of dictionaries describing a property
                    case kSecPropertyTypeSection:
                        if let value = value as? Array<NSDictionary> {
                            return .section(value .map{ Property(dictionary: $0) })
                        }
                    case kSecPropertyTypeData:
                        if let value = value as? Data {
                            return .data(value)
                        }
                    case kSecPropertyTypeString:
                        if let value = value as? String {
                            return .string(value)
                        }
                    case kSecPropertyTypeURL:
                        if let value = value as? URL {
                            return .url(value)
                        }
                    case kSecPropertyTypeDate:
                        if let value = value as? Date {
                            return .date(value)
                        }
                    case kSecPropertyTypeTitle:
                        if let value = value as? String {
                            return .title(value)
                        }
                    case kSecPropertyTypeError:
                        if let value = value as? String {
                            return .error(value)
                        }
                    default:
                        if #available(macOS 10.15, *) {
                            switch type {
                                case kSecPropertyTypeArray:
                                    if let value = value as? Array<Any> {
                                        return .array(value)
                                    }
                                case kSecPropertyTypeNumber:
                                    if let value = value as? Double {
                                        return .number(value)
                                    }
                                default:
                                    break
                            }
                        }
                }
                
                return .unknown(type: type as String, value: value)
            }
            
            var description: String {
                switch self {
                    case .warning(let string):
                        return "<warning> \(string)"
                    case .success(let string):
                        return "<success> \(string)"
                    case .section(let array):
                        return "<section> \(array.count) element(s)"
                    case .data(let data):
                        return "<data> \(data)"
                    case .string(let string):
                        return "<string> \(string)"
                    case .url(let url):
                        return "<url> \(url)"
                    case .date(let date):
                        return "<date> \(date)"
                    case .array(let array):
                        return "<array> \(array.count) element(s)"
                    case .number(let double):
                        return "<number> \(double)"
                    case .title(let string):
                        return "<title> \(string)"
                    case .error(let string):
                        return "<error> \(string)"
                    case .unknown(type: let type, value: let value):
                        return "<\(type)> \(value)"
                    case .none:
                        return "<none>"
                }
            }
        }
    }
    
    enum CertificatePropertyValue {
        /// A string describing a trust evaluation warning.
        case warning(String)
        /// A string describing a trust evaluation success.
        case success(String)
        /// In practice, an array of certicate properties.
        ///
        /// Official (erroneous) documentation: a string describing the name of a field in the certificate (CFSTR("Subject Name"), for example).
        case section([Property])
        /// A data object.
        case data(Data)
        /// A string.
        case string(String)
        /// A URL.
        case url(URL)
        /// A string containing a date (or a string listing the bytes of an invalid date).
        case date(String)
        /// An array.
        case array(Array<Any>)
        /// A number.
        case number(Double)
        /// A string containing the title (display name) of the certificate.
        case title(String)
        /// A string containing the reason for a trust evaluation failure.
        case error(String)
    }
    
    enum CertificateOID: CaseIterable, RawRepresentable {
        case adcCertPolicy
        case appleCertPolicy
        case appleEKUCodeSigning
        case appleEKUCodeSigningDev
        case appleEKUiChatEncryption
        case appleEKUiChatSigning
        case appleEKUResourceSigning
        case appleEKUSystemIdentity
        case appleExtension
        case appleExtensionAAIIntermediate
        case appleExtensionADCAppleSigning
        case appleExtensionADCDevSigning
        case appleExtensionAppleIDIntermediate
        case appleExtensionAppleSigning
        case appleExtensionCodeSigning
        case appleExtensionIntermediateMarker
        case appleExtensionITMSIntermediate
        case appleExtensionWWDRIntermediate
        case authorityInfoAccess
        case authorityKeyIdentifier
        case basicConstraints
        case biometricInfo
        case ssmKeyStruct
        case certIssuer
        case certificatePolicies
        case clientAuth
        case collectiveStateProvinceName
        case collectiveStreetAddress
        case commonName
        case countryName
        case crlDistributionPoints
        case crlNumber
        case crlReason
        case dotMacCertEmailEncrypt
        case dotMacCertEmailSign
        case dotMacCertExtension
        case dotMacCertIdentity
        case dotMacCertPolicy
        case deltaCrlIndicator
        case description
        case ekuIPSec
        case emailAddress
        case emailProtection
        case extendedKeyUsage
        case extendedKeyUsageAny
        case extendedUseCodeSigning
        case givenName
        case holdInstructionCode
        case invalidityDate
        case issuerAltName
        case distributionPoint
        case issuingDistributionPoints
        case kerbV5PkinitKpClientAuth
        case kerbV5PkinitKpKdc
        case keyUsage
        case localityName
        case msNTPrincipalName
        case microsoftSGC
        case nameConstraints
        case netscapeCertSequence
        case netscapeCertType
        case netscapeSGC
        case cspSigning
        case organizationName
        case organizationalUnitName
        case policyConstraints
        case policyMappings
        case privateKeyUsagePeriod
        case dqcStatements
        case srvName
        case serialNumber
        case serverAuth
        case stateProvinceName
        case streetAddress
        case subjectAltName
        case subjectDirectoryAttributes
        case subjectEmailAddress
        case subjectInfoAccess
        case subjectKeyIdentifier
        case subjectPicture
        case subjectSignatureBitmap
        case surname
        case timeStamping
        case title
        case useExemptions
        case x509V1CertificateIssuerUniqueId
        case x509V1CertificateSubjectUniqueId
        case x509V1IssuerName
        case x509V1IssuerNameCStruct
        case x509V1IssuerNameLDAP
        case x509V1IssuerNameStd
        case x509V1SerialNumber
        case x509V1Signature
        case x509V1SignatureAlgorithm
        case x509V1SignatureAlgorithmParameters
        case x509V1SignatureAlgorithmTBS
        case x509V1SignatureCStruct
        case x509V1SignatureStruct
        case x509V1SubjectName
        case x509V1SubjectNameCStruct
        case x509V1SubjectNameLDAP
        case x509V1SubjectNameStd
        case x509V1SubjectPublicKey
        case x509V1SubjectPublicKeyAlgorithm
        case x509V1SubjectPublicKeyAlgorithmParameters
        case x509V1SubjectPublicKeyCStruct
        case x509V1ValidityNotAfter
        case x509V1ValidityNotBefore
        case x509V1Version
        case x509V3Certificate
        case x509V3CertificateCStruct
        case x509V3CertificateExtensionCStruct
        case x509V3CertificateExtensionCritical
        case x509V3CertificateExtensionId
        case x509V3CertificateExtensionStruct
        case x509V3CertificateExtensionType
        case x509V3CertificateExtensionValue
        case x509V3CertificateExtensionsCStruct
        case x509V3CertificateExtensionsStruct
        case x509V3CertificateNumberOfExtensions
        case x509V3SignedCertificate
        case x509V3SignedCertificateCStruct
        
        init?(rawValue: CFString) {
            if let certificate = CertificateOID.allCases.first(where: { $0.rawValue == rawValue }) {
                self = certificate
            }
            
            return nil
        }
        
        var rawValue: CFString {
            switch self {
                case .adcCertPolicy:                              return kSecOIDADC_CERT_POLICY
                case .appleCertPolicy:                            return kSecOIDAPPLE_CERT_POLICY
                case .appleEKUCodeSigning:                        return kSecOIDAPPLE_EKU_CODE_SIGNING
                case .appleEKUCodeSigningDev:                     return kSecOIDAPPLE_EKU_CODE_SIGNING_DEV
                case .appleEKUiChatEncryption:                    return kSecOIDAPPLE_EKU_ICHAT_ENCRYPTION
                case .appleEKUiChatSigning:                       return kSecOIDAPPLE_EKU_ICHAT_SIGNING
                case .appleEKUResourceSigning:                    return kSecOIDAPPLE_EKU_RESOURCE_SIGNING
                case .appleEKUSystemIdentity:                     return kSecOIDAPPLE_EKU_SYSTEM_IDENTITY
                case .appleExtension:                             return kSecOIDAPPLE_EXTENSION
                case .appleExtensionAAIIntermediate:              return kSecOIDAPPLE_EXTENSION_AAI_INTERMEDIATE
                case .appleExtensionADCAppleSigning:              return kSecOIDAPPLE_EXTENSION_ADC_APPLE_SIGNING
                case .appleExtensionADCDevSigning:                return kSecOIDAPPLE_EXTENSION_ADC_DEV_SIGNING
                case .appleExtensionAppleIDIntermediate:          return kSecOIDAPPLE_EXTENSION_APPLEID_INTERMEDIATE
                case .appleExtensionAppleSigning:                 return kSecOIDAPPLE_EXTENSION_APPLE_SIGNING
                case .appleExtensionCodeSigning:                  return kSecOIDAPPLE_EXTENSION_CODE_SIGNING
                case .appleExtensionIntermediateMarker:           return kSecOIDAPPLE_EXTENSION_INTERMEDIATE_MARKER
                case .appleExtensionITMSIntermediate:             return kSecOIDAPPLE_EXTENSION_ITMS_INTERMEDIATE
                case .appleExtensionWWDRIntermediate:             return kSecOIDAPPLE_EXTENSION_WWDR_INTERMEDIATE
                case .authorityInfoAccess:                        return kSecOIDAuthorityInfoAccess
                case .authorityKeyIdentifier:                     return kSecOIDAuthorityKeyIdentifier
                case .basicConstraints:                           return kSecOIDBasicConstraints
                case .biometricInfo:                              return kSecOIDBiometricInfo
                case .ssmKeyStruct:                               return kSecOIDCSSMKeyStruct
                case .certIssuer:                                 return kSecOIDCertIssuer
                case .certificatePolicies:                        return kSecOIDCertificatePolicies
                case .clientAuth:                                 return kSecOIDClientAuth
                case .collectiveStateProvinceName:                return kSecOIDCollectiveStateProvinceName
                case .collectiveStreetAddress:                    return kSecOIDCollectiveStreetAddress
                case .commonName:                                 return kSecOIDCommonName
                case .countryName:                                return kSecOIDCountryName
                case .crlDistributionPoints:                      return kSecOIDCrlDistributionPoints
                case .crlNumber:                                  return kSecOIDCrlNumber
                case .crlReason:                                  return kSecOIDCrlReason
                case .dotMacCertEmailEncrypt:                     return kSecOIDDOTMAC_CERT_EMAIL_ENCRYPT
                case .dotMacCertEmailSign:                        return kSecOIDDOTMAC_CERT_EMAIL_SIGN
                case .dotMacCertExtension:                        return kSecOIDDOTMAC_CERT_EXTENSION
                case .dotMacCertIdentity:                         return kSecOIDDOTMAC_CERT_IDENTITY
                case .dotMacCertPolicy:                           return kSecOIDDOTMAC_CERT_POLICY
                case .deltaCrlIndicator:                          return kSecOIDDeltaCrlIndicator
                case .description:                                return kSecOIDDescription
                case .ekuIPSec:                                   return kSecOIDEKU_IPSec
                case .emailAddress:                               return kSecOIDEmailAddress
                case .emailProtection:                            return kSecOIDEmailProtection
                case .extendedKeyUsage:                           return kSecOIDExtendedKeyUsage
                case .extendedKeyUsageAny:                        return kSecOIDExtendedKeyUsageAny
                case .extendedUseCodeSigning:                     return kSecOIDExtendedUseCodeSigning
                case .givenName:                                  return kSecOIDGivenName
                case .holdInstructionCode:                        return kSecOIDHoldInstructionCode
                case .invalidityDate:                             return kSecOIDInvalidityDate
                case .issuerAltName:                              return kSecOIDIssuerAltName
                case .distributionPoint:                          return kSecOIDIssuingDistributionPoint
                case .issuingDistributionPoints:                  return kSecOIDIssuingDistributionPoints
                case .kerbV5PkinitKpClientAuth:                   return kSecOIDKERBv5_PKINIT_KP_CLIENT_AUTH
                case .kerbV5PkinitKpKdc:                          return kSecOIDKERBv5_PKINIT_KP_KDC
                case .keyUsage:                                   return kSecOIDKeyUsage
                case .localityName:                               return kSecOIDLocalityName
                case .msNTPrincipalName:                          return kSecOIDMS_NTPrincipalName
                case .microsoftSGC:                               return kSecOIDMicrosoftSGC
                case .nameConstraints:                            return kSecOIDNameConstraints
                case .netscapeCertSequence:                       return kSecOIDNetscapeCertSequence
                case .netscapeCertType:                           return kSecOIDNetscapeCertType
                case .netscapeSGC:                                return kSecOIDNetscapeSGC
                case .cspSigning:                                 return kSecOIDOCSPSigning
                case .organizationName:                           return kSecOIDOrganizationName
                case .organizationalUnitName:                     return kSecOIDOrganizationalUnitName
                case .policyConstraints:                          return kSecOIDPolicyConstraints
                case .policyMappings:                             return kSecOIDPolicyMappings
                case .privateKeyUsagePeriod:                      return kSecOIDPrivateKeyUsagePeriod
                case .dqcStatements:                              return kSecOIDQC_Statements
                case .srvName:                                    return kSecOIDSRVName
                case .serialNumber:                               return kSecOIDSerialNumber
                case .serverAuth:                                 return kSecOIDServerAuth
                case .stateProvinceName:                          return kSecOIDStateProvinceName
                case .streetAddress:                              return kSecOIDStreetAddress
                case .subjectAltName:                             return kSecOIDSubjectAltName
                case .subjectDirectoryAttributes:                 return kSecOIDSubjectDirectoryAttributes
                case .subjectEmailAddress:                        return kSecOIDSubjectEmailAddress
                case .subjectInfoAccess:                          return kSecOIDSubjectInfoAccess
                case .subjectKeyIdentifier:                       return kSecOIDSubjectKeyIdentifier
                case .subjectPicture:                             return kSecOIDSubjectPicture
                case .subjectSignatureBitmap:                     return kSecOIDSubjectSignatureBitmap
                case .surname:                                    return kSecOIDSurname
                case .timeStamping:                               return kSecOIDTimeStamping
                case .title:                                      return kSecOIDTitle
                case .useExemptions:                              return kSecOIDUseExemptions
                case .x509V1CertificateIssuerUniqueId:            return kSecOIDX509V1CertificateIssuerUniqueId
                case .x509V1CertificateSubjectUniqueId:           return kSecOIDX509V1CertificateSubjectUniqueId
                case .x509V1IssuerName:                           return kSecOIDX509V1IssuerName
                case .x509V1IssuerNameCStruct:                    return kSecOIDX509V1IssuerNameCStruct
                case .x509V1IssuerNameLDAP:                       return kSecOIDX509V1IssuerNameLDAP
                case .x509V1IssuerNameStd:                        return kSecOIDX509V1IssuerNameStd
                case .x509V1SerialNumber:                         return kSecOIDX509V1SerialNumber
                case .x509V1Signature:                            return kSecOIDX509V1Signature
                case .x509V1SignatureAlgorithm:                   return kSecOIDX509V1SignatureAlgorithm
                case .x509V1SignatureAlgorithmParameters:         return kSecOIDX509V1SignatureAlgorithmParameters
                case .x509V1SignatureAlgorithmTBS:                return kSecOIDX509V1SignatureAlgorithmTBS
                case .x509V1SignatureCStruct:                     return kSecOIDX509V1SignatureCStruct
                case .x509V1SignatureStruct:                      return kSecOIDX509V1SignatureStruct
                case .x509V1SubjectName:                          return kSecOIDX509V1SubjectName
                case .x509V1SubjectNameCStruct:                   return kSecOIDX509V1SubjectNameCStruct
                case .x509V1SubjectNameLDAP:                      return kSecOIDX509V1SubjectNameLDAP
                case .x509V1SubjectNameStd:                       return kSecOIDX509V1SubjectNameStd
                case .x509V1SubjectPublicKey:                     return kSecOIDX509V1SubjectPublicKey
                case .x509V1SubjectPublicKeyAlgorithm:            return kSecOIDX509V1SubjectPublicKeyAlgorithm
                case .x509V1SubjectPublicKeyAlgorithmParameters:  return kSecOIDX509V1SubjectPublicKeyAlgorithmParameters
                case .x509V1SubjectPublicKeyCStruct:              return kSecOIDX509V1SubjectPublicKeyCStruct
                case .x509V1ValidityNotAfter:                     return kSecOIDX509V1ValidityNotAfter
                case .x509V1ValidityNotBefore:                    return kSecOIDX509V1ValidityNotBefore
                case .x509V1Version:                              return kSecOIDX509V1Version
                case .x509V3Certificate:                          return kSecOIDX509V3Certificate
                case .x509V3CertificateCStruct:                   return kSecOIDX509V3CertificateCStruct
                case .x509V3CertificateExtensionCStruct:          return kSecOIDX509V3CertificateExtensionCStruct
                case .x509V3CertificateExtensionCritical:         return kSecOIDX509V3CertificateExtensionCritical
                case .x509V3CertificateExtensionId:               return kSecOIDX509V3CertificateExtensionId
                case .x509V3CertificateExtensionStruct:           return kSecOIDX509V3CertificateExtensionStruct
                case .x509V3CertificateExtensionType:             return kSecOIDX509V3CertificateExtensionType
                case .x509V3CertificateExtensionValue:            return kSecOIDX509V3CertificateExtensionValue
                case .x509V3CertificateExtensionsCStruct:         return kSecOIDX509V3CertificateExtensionsCStruct
                case .x509V3CertificateExtensionsStruct:          return kSecOIDX509V3CertificateExtensionsStruct
                case .x509V3CertificateNumberOfExtensions:        return kSecOIDX509V3CertificateNumberOfExtensions
                case .x509V3SignedCertificate:                    return kSecOIDX509V3SignedCertificate
                case .x509V3SignedCertificateCStruct:             return kSecOIDX509V3SignedCertificateCStruct
            }
        }
    }
}
