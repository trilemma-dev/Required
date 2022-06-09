//
//  SecCode+Extensions.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-20
//

import Foundation
import Security

extension SecCode {
    static var current: SecCode {
        var code: SecCode?
        SecCodeCopySelf(SecCSFlags(), &code)
        
        return code!
    }
    
    func asStaticCode() throws -> SecStaticCode {
        try SecurityError.throwIfFailure { staticCode in
            SecCodeCopyStaticCode(self, SecCSFlags(), &staticCode)
        }
    }
    
    func checkValidity(flags: SecCSFlags, requirement: SecRequirement) throws {
        let result = SecCodeCheckValidity(self, flags, requirement)
        if result != errSecSuccess {
            throw SecurityError.statusCode(result)
        }
    }
    
    static func withAttributes(_ attributes: [GuestAttribute: Any]) throws -> SecCode? {
        let cfAttributes = Dictionary(uniqueKeysWithValues: attributes.map{ ($0.key.rawValue, $0.value) })
                           as CFDictionary
        return try SecurityError.throwIfFailure { guestCode in
            SecCodeCopyGuestWithAttributes(nil, cfAttributes, SecCSFlags(), &guestCode)
        }
    }
    
    enum GuestAttribute: Hashable {
        case architecture
        case audit
        case canonical
        case dynamicCode
        case dynamicCodeInfoPlist
        case hash
        case machPort
        case pid
        case subarchitecture
        
        fileprivate var rawValue: CFString {
            switch self {
                case .architecture:
                    return kSecGuestAttributeArchitecture
                case .audit:
                    return kSecGuestAttributeAudit
                case .canonical:
                    return kSecGuestAttributeCanonical
                case .dynamicCode:
                    return kSecGuestAttributeDynamicCode
                case .dynamicCodeInfoPlist:
                    return kSecGuestAttributeDynamicCodeInfoPlist
                case .hash:
                    return kSecGuestAttributeHash
                case .machPort:
                    return kSecGuestAttributeMachPort
                case .pid:
                    return kSecGuestAttributePid
                case .subarchitecture:
                    return kSecGuestAttributeSubarchitecture
            }
        }
    }
}

