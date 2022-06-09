//
//  SecStaticCode+Extensions.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-20
//

import Foundation
import Security

extension SecStaticCode {
    
    static func withPath(_ path: URL) throws -> SecStaticCode {
        try SecurityError.throwIfFailure { staticCode in
            SecStaticCodeCreateWithPath(path as CFURL, SecCSFlags(), &staticCode)
        }
    }
    
    var path: URL {
        get throws {
            try SecurityError.throwIfFailure { url in
                SecCodeCopyPath(self, SecCSFlags(), &url)
            } as URL
        }
    }
    
    func readSigningInformation(
        options: Set<SigningInformationRequestOption> = []
    ) throws -> [SigningInformationDictionaryKey : Any] {
        let nsInfo = try SecurityError.throwIfFailure { information in
            SecCodeCopySigningInformation(self, options.asSecFlags, &information)
        } as NSDictionary
        
        var info = [SigningInformationDictionaryKey : Any]()
        for key in SigningInformationDictionaryKey.allCases {
            if let value = nsInfo[key.rawValue] {
                // TODO: see if values for SecCodeSignatureFlags need to created if only the UInt32 values are stored
                info[key] = cfTypeRefAsSwiftType(value as AnyObject)
            }
        }
        
        return info
    }
    
    var designatedRequirement: SecRequirement {
        get throws {
            try SecurityError.throwIfFailure { requirement in
                SecCodeCopyDesignatedRequirement(self, SecCSFlags(), &requirement)
            }
        }
    }
    
    func checkValidity(flags: SecCSFlags, requirement: SecRequirement) throws {
        let result = SecStaticCodeCheckValidity(self, flags, requirement)
        if result != errSecSuccess {
            throw SecurityError.statusCode(result)
        }
    }
    
    enum SigningInformationRequestOption {
        /// Internal code signing information.
        case internalInformation
        /// Cryptographic signing information.
        case signingInformation
        /// Code requirements—including the designated requirement—embedded in the code.
        case requirementInformation
        /// Dynamic validity information about running code.
        case dynamicInformation
        /// More information about the file system contents making up the signed code on disk.
        case contentInformation
        /// Suppress validating the resource directory.
        case skipResourceDirectory
        /// Undocumented
        case calculateCMSDigest
        
        fileprivate var rawValue: UInt32 {
            switch self {
                case .internalInformation:      return kSecCSInternalInformation
                case .signingInformation:       return kSecCSSigningInformation
                case .requirementInformation:   return kSecCSRequirementInformation
                case .dynamicInformation:       return kSecCSDynamicInformation
                case .contentInformation:       return kSecCSContentInformation
                case .skipResourceDirectory:    return kSecCSSkipResourceDirectory
                case .calculateCMSDigest:       return kSecCSCalculateCMSDigest
            }
        }
    }
    
    enum SigningInformationDictionaryKey: CaseIterable {
        /// A key whose value is an array containing the unique binary identifier for every digest algorithm supported in the signature.
        case cdHashes
        /// A key whose value is an array of certificates representing the certificate chain of the signing certificate as seen by the system.
        case infoCertificates
        /// A key whose value is a list of all files in the code that may have been modified by the process of signing it.
        case changedFiles
        /// A key whose value is the CMS cryptographic object that secures the code signature.
        case cms
        /// A keys whose value is the designated requirement of the code.
        case designatedRequirement
        /// A key whose value is a number indicating the cryptographic hash function.
        case digestAlgorithm
        /// A key whose value is a list of the kinds of cryptographic hash functions available within the signature.
        case digestAlgorithms
        /// A key whose value represents the embedded entitlement blob of the code, if any.
        case entitlements
        /// A key whose value is a dictionary of embedded entitlements.
        case entitlementsDict
        /// A key whose value is a string representing the type and format of the code in a form suitable for display to a knowledgeable user.
        case format
        /// A key whose value indicates the static (on-disk) state of the object.
        case flags
        /// A key whose value is the signing identifier sealed into the signature.
        case identifier
        /// A key whose value is the designated requirement (DR) that the system generated—or would have generated—for the code in the absence of an
        /// explicitly-declared DR.
        case implicitDesignatedRequirement
        /// A key whose value is a URL locating the main executable file of the code.
        case mainExecutable
        /// A key whose value is an information dictionary containing the contents of the secured Info.plist file as seen by Code Signing Services.
        case infoPList
        /// A key whose value identifies the operating system release with which the code is associated, if any.
        case platformIdentifier
        /// A key whose value is the internal requirements of the code as a text string in canonical syntax.
        case requirements
        /// A key whose value is the internal requirements of the code as a binary blob.
        case requirementData
        /// A key whose value represents the runtime version.
        case runtimeVersion
        /// The source of the code signature used for the code object in a format suitable for display.
        case source
        /// A key whose value is the set of code status flags for the running code.
        case status
        /// A key whose value is the team identifier.
        case teamIdentifier
        /// A key whose value is the signing date embedded in the code signature.
        case time
        /// A key whose value indicates the actual signing date.
        case timestamp
        /// A key whose value is the trust object the system uses to evaluate the validity of the code's signature.
        case trust
        /// A key whose value is a binary number that uniquely identifies static code.
        case unique
        
        fileprivate var rawValue: CFString {
            switch self {
                case .cdHashes:                         return kSecCodeInfoCdHashes
                case .infoCertificates:                 return kSecCodeInfoCertificates
                case .changedFiles:                     return kSecCodeInfoChangedFiles
                case .cms:                              return kSecCodeInfoCMS
                case .designatedRequirement:            return kSecCodeInfoDesignatedRequirement
                case .digestAlgorithm:                  return kSecCodeInfoDigestAlgorithm
                case .digestAlgorithms:                 return kSecCodeInfoDigestAlgorithms
                case .entitlements:                     return kSecCodeInfoEntitlements
                case .entitlementsDict:                 return kSecCodeInfoEntitlementsDict
                case .format:                           return kSecCodeInfoFormat
                case .flags:                            return kSecCodeInfoFlags
                case .identifier:                       return kSecCodeInfoIdentifier
                case .implicitDesignatedRequirement:    return kSecCodeInfoImplicitDesignatedRequirement
                case .mainExecutable:                   return kSecCodeInfoMainExecutable
                case .infoPList:                        return kSecCodeInfoPList
                case .platformIdentifier:               return kSecCodeInfoPlatformIdentifier
                case .requirements:                     return kSecCodeInfoRequirements
                case .requirementData:                  return kSecCodeInfoRequirementData
                case .runtimeVersion:                   return kSecCodeInfoRuntimeVersion
                case .source:                           return kSecCodeInfoSource
                case .status:                           return kSecCodeInfoStatus
                case .teamIdentifier:                   return kSecCodeInfoTeamIdentifier
                case .time:                             return kSecCodeInfoTime
                case .timestamp:                        return kSecCodeInfoTimestamp
                case .trust:                            return kSecCodeInfoTrust
                case .unique:                           return kSecCodeInfoUnique
            }
        }
    }
}

extension Set where Element == SecStaticCode.SigningInformationRequestOption {
    fileprivate var asSecFlags: SecCSFlags {
        if self.isEmpty {
            return SecCSFlags()
        } else {
            var rawValues = self.map{ $0.rawValue }
            var combinedRawValue = rawValues.removeFirst()
            for rawValue in rawValues {
                combinedRawValue = combinedRawValue | rawValue
            }
            
            return SecCSFlags(rawValue: combinedRawValue)
        }
    }
}
