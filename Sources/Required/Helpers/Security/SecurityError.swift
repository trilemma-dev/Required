//
//  SecurityError.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-20
//

import Foundation

enum SecurityError: Error {
    case statusCode(OSStatus)
    case unknown
    case cfError(CFErrorDomain, CFIndex)
    
    static func throwIfFailure<T>(_ function: (inout T?) -> (OSStatus)) throws -> T {
        var value: T?
        let result = function(&value)
        if result == errSecSuccess, let value = value {
            return value
        } else {
            throw SecurityError.statusCode(result)
        }
    }
    
    static func fromUnmanagedCFError(_ error: Unmanaged<CFError>?) -> SecurityError {
        guard let error = error?.takeUnretainedValue() else {
            return .unknown
        }
        guard let domain = CFErrorGetDomain(error) else {
            return .unknown
        }
        
        return .cfError(domain, CFErrorGetCode(error))
    }
}
