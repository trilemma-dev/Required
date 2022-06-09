//
//  SecRequirement+Extensions.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-22
//

import Foundation
import Security

extension SecRequirement {
    var data: Data {
        get throws {
            try SecurityError.throwIfFailure { data in
                SecRequirementCopyData(self, SecCSFlags(), &data)
            } as Data
        }
    }
    
    static func withData(_ data: Data) throws -> SecRequirement {
        try SecurityError.throwIfFailure { requirement in
            SecRequirementCreateWithData(data as CFData, SecCSFlags(), &requirement)
        }
    }
    
    var textForm: String {
        get throws {
            try SecurityError.throwIfFailure { text in
                SecRequirementCopyString(self, SecCSFlags(), &text)
            } as String
        }
    }
    
    static func withString(_ text: String) throws -> SecRequirement {
        try SecurityError.throwIfFailure { requirement in
            SecRequirementCreateWithString(text as CFString, SecCSFlags(), &requirement)
        }
    }
}
