//
//  Symbols.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-18
//

public protocol Symbol: CustomStringConvertible {
    var sourceToken: Token { get }
}

extension Symbol {
    public var description: String {
        self.sourceToken.rawValue
    }
}

public struct NegationSymbol: Symbol {
    public let sourceToken: Token
}

public struct AndSymbol: Symbol {
    public let sourceToken: Token
}

public struct OrSymbol: Symbol {
    public let sourceToken: Token
}

public protocol InfixComparisonOperatorSymbol: Symbol { }

public struct EqualsSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

public struct LessThanSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

public struct GreaterThanSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

public struct LessThanOrEqualToSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

public struct GreaterThanOrEqualToSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

public struct ExistsSymbol: Symbol {
    public let sourceToken: Token
}

public struct StringSymbol: Symbol {
    public let sourceToken: Token
    public let value: String
    
    init(sourceToken: Token) {
        self.sourceToken = sourceToken
        let rawValue = sourceToken.rawValue
        
        if rawValue.hasPrefix("\""), rawValue.hasSuffix("\"") {
            let secondIndex = rawValue.index(after: rawValue.startIndex)
            let secondToLastIndex = rawValue.index(before: rawValue.endIndex)
            self.value = String(rawValue[secondIndex..<secondToLastIndex])
        } else {
            self.value = rawValue
        }
    }
    
    public var description: String {
        value
    }
}

public struct WildcardSymbol: Symbol {
    public let sourceToken: Token
}

public struct InfoSymbol: Symbol {
    public let sourceToken: Token
}

public struct EntitlementSymbol: Symbol {
    public let sourceToken: Token
}


/// Literally the symbol for the `identifier` keyword
public struct IdentifierSymbol: Symbol {
    public let sourceToken: Token
}


public struct CodeDirectoryHashSymbol: Symbol {
    public let sourceToken: Token
}

public struct AppleSymbol: Symbol {
    public let sourceToken: Token
}

public struct GenericSymbol: Symbol {
    public let sourceToken: Token
}

public struct TrustedSymbol: Symbol {
    public let sourceToken: Token
}

// Used exclusively for certificate positions, optionally with NegativePositionSymbol
public struct IntegerSymbol: Symbol {
    public let sourceToken: Token
    public let value: UInt
    
    init(sourceToken: Token) {
        self.sourceToken = sourceToken
        self.value = UInt(sourceToken.rawValue)!
    }
}

public struct NegativePositionSymbol: Symbol {
    public let sourceToken: Token
}

public struct RootPositionSymbol: Symbol {
    public let sourceToken: Token
}

public struct LeafPositionSymbol: Symbol {
    public let sourceToken: Token
}

public struct CertificateSymbol: Symbol {
    public let sourceToken: Token
    
    public var description: String {
        // Explicitly set this to be certificate instead of relying on the sourceToken's raw value which could be
        // either cert or certificate
        "certificate"
    }
}

// equivalent to: certificate root
public struct AnchorSymbol: Symbol {
    public let sourceToken: Token
}

public struct HashConstantSymbol: Symbol {
    public let sourceToken: Token
    public let value: String
    
    init(sourceToken: Token) {
        self.sourceToken = sourceToken
        
        // Extract value by removing leading H" and trailing "
        let rawValue = sourceToken.rawValue
        let thirdIndex = rawValue.index(after: rawValue.index(after: rawValue.startIndex))
        let secondToLastIndex = rawValue.index(before: rawValue.endIndex)
        self.value = String(rawValue[thirdIndex..<secondToLastIndex])
    }
    
    public var description: String {
        value
    }
}
