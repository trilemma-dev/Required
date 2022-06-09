//
//  Data+Extensions.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-21
//

import Foundation
import CommonCrypto

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        self.map { String(format: options.contains(.upperCase) ? "%02hhX" : "%02hhx", $0) }.joined()
    }
    
    func sha256() -> Data {
        var sha256Context = CC_SHA256_CTX()
        CC_SHA256_Init(&sha256Context)
        
        self.withUnsafeBytes { bytesFromBuffer  in
            let rawBytes = bytesFromBuffer.bindMemory(to: UInt8.self).baseAddress
            CC_SHA256_Update(&sha256Context, rawBytes, numericCast(self.count))
        }
        
        var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        digest.withUnsafeMutableBytes { bytesFromDigest in
            let rawBytes = bytesFromDigest.bindMemory(to: UInt8.self).baseAddress
            CC_SHA256_Final(rawBytes, &sha256Context)
        }
        
        return digest
    }

    func sha1() -> Data {
        var sha1Context = CC_SHA1_CTX()
        CC_SHA1_Init(&sha1Context)
        
        self.withUnsafeBytes { bytesFromBuffer  in
            let rawBytes = bytesFromBuffer.bindMemory(to: UInt8.self).baseAddress
            CC_SHA1_Update(&sha1Context, rawBytes, numericCast(self.count))
        }
        
        var digest = Data(count: Int(CC_SHA1_DIGEST_LENGTH))
        digest.withUnsafeMutableBytes { bytesFromDigest in
            let rawBytes = bytesFromDigest.bindMemory(to: UInt8.self).baseAddress
            CC_SHA1_Final(rawBytes, &sha1Context)
        }
        
        return digest
    }
}
