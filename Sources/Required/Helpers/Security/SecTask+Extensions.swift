//
//  SecTask+Extensions.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-20
//

import Foundation

extension SecTask {
    static var current: SecTask {
        return SecTaskCreateFromSelf(nil)!
    }
    
    static func withAuditToken(_ token: audit_token_t) throws -> SecTask {
        guard let task = SecTaskCreateWithAuditToken(nil, token) else {
            throw SecurityError.unknown
        }
        
        return task
    }
    
    var signingIdentifier: String {
        get throws {
            var unmanagedError: Unmanaged<CFError>?
            defer { unmanagedError?.release() }
            guard let identifier = SecTaskCopySigningIdentifier(self, &unmanagedError) as String? else {
                throw SecurityError.fromUnmanagedCFError(unmanagedError)
            }
            
            return identifier
        }
    }
    
    func valueForEntitlement(key: String) throws -> Any? {
        var unmanagedError: Unmanaged<CFError>?
        defer { unmanagedError?.release() }
        let value = SecTaskCopyValueForEntitlement(self, key as CFString, &unmanagedError)
        
        // It's not an error for the value to be nil, it just means the entitlement isn't present
        if unmanagedError != nil {
            throw SecurityError.fromUnmanagedCFError(unmanagedError)
        }
        
        return cfTypeRefAsSwiftType(value as AnyObject)
    }
}
