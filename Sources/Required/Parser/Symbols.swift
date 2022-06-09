//
//  Symbols.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-18
//

/// An keyword, operator, or value in the Code Signing Requirement Language.
public protocol Symbol: CustomStringConvertible {
    /// The token representing the source text from which this symbol is derived.
    var sourceToken: Token { get }
}

// Implementation of CustomStringConvertible
extension Symbol {
    public var description: String {
        self.sourceToken.rawValue
    }
}

/// Logically negates the following requirement.
public struct NegationSymbol: Symbol {
    public let sourceToken: Token
}

/// Logically ands the preceeding and following requirements.
public struct AndSymbol: Symbol {
    public let sourceToken: Token
}

/// Logically ors the preceeding and following requirements.
public struct OrSymbol: Symbol {
    public let sourceToken: Token
}

/// Infix comparison operators.
public protocol InfixComparisonOperatorSymbol: Symbol { }

/// An equality comparison operator.
///
/// This does not necessarily represent true equality as it may be used in a match expression against a wildcard string.
public struct EqualsSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

/// A less than comparison operator.
public struct LessThanSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

/// A greater than comparison operator.
public struct GreaterThanSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

/// A less than or equal to comparison operator.
public struct LessThanOrEqualToSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

/// A greater than or equal to comparison operator.
public struct GreaterThanOrEqualToSymbol: InfixComparisonOperatorSymbol {
    public let sourceToken: Token
}

/// An existence operator.
public struct ExistsSymbol: Symbol {
    public let sourceToken: Token
}

/// A quoted or unquoted string.
public struct StringSymbol: Symbol {
    public let sourceToken: Token
    
    /// The value of this string, removing begin and end quotes if present.
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

/// A wildcard symbol preceeding and/or following a ``StringSymbol``.
public struct WildcardSymbol: Symbol {
    public let sourceToken: Token
}

/// Represents an Info.plist dictionary.
public struct InfoSymbol: Symbol {
    public let sourceToken: Token
}

/// Represents a signature’s embedded entitlement dictionary.
public struct EntitlementSymbol: Symbol {
    public let sourceToken: Token
}

/// Represents the unique identifier string embedded in the code signature.
public struct IdentifierSymbol: Symbol {
    public let sourceToken: Token
}

/// Represents the canonical hash of the program’s CodeDirectory resource.
public struct CodeDirectoryHashSymbol: Symbol {
    public let sourceToken: Token
}

/// Represents code signed by Apple.
public struct AppleSymbol: Symbol {
    public let sourceToken: Token
}

/// Represents code signed using a signing certificate issued by Apple to other developers.
public struct GenericSymbol: Symbol {
    public let sourceToken: Token
}

/// Represents a certificate trusted for the code signing certificate policy in the system’s Trust Settings database.
public struct TrustedSymbol: Symbol {
    public let sourceToken: Token
}

/// A position of a certificate in the certificate chain, optionally modified by ``NegativePositionSymbol``.
public struct IntegerSymbol: Symbol {
    public let sourceToken: Token
    public let value: UInt
    
    init(sourceToken: Token) {
        self.sourceToken = sourceToken
        self.value = UInt(sourceToken.rawValue)!
    }
}

/// A negative modifier for the ``IntegerSymbol`` position of a certificate in the certificate chain.
public struct NegativePositionSymbol: Symbol {
    public let sourceToken: Token
}

/// The root position for a certificate in the certificate chain.
public struct RootPositionSymbol: Symbol {
    public let sourceToken: Token
}

/// The leaf position for a certificate in the certificate chain.
public struct LeafPositionSymbol: Symbol {
    public let sourceToken: Token
}

/// The beginning of a certificate constraint.
public struct CertificateSymbol: Symbol {
    public let sourceToken: Token
    
    public var description: String {
        // Explicitly set this to be certificate instead of relying on the sourceToken's raw value which could be
        // either cert or certificate
        "certificate"
    }
}

/// Represents the beginning of a certificate constraint for the root position of a certificate in the certificate chain.
///
/// Equivalent to the symbols ``CertificateSymbol`` followed by ``RootPositionSymbol``.
public struct AnchorSymbol: Symbol {
    public let sourceToken: Token
}

/// A hash constant which is expected to be a hexadecimal value for SHA1.
public struct HashConstantSymbol: Symbol {
    public let sourceToken: Token
    
    /// The value of this constant removing the leading `H"` and trailing `"`.
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

/// Associates a ``RequirementTagSymbol`` with the requirement which follows.
public struct RequirementSetSymbol: Symbol {
    public let sourceToken: Token
}

/// A tag that is associated with a requirement to form a requirement set.
public protocol RequirementTagSymbol: Symbol { }

/// A host tag for a requirement set.
public struct HostSymbol: RequirementTagSymbol {
    public let sourceToken: Token
}

/// A guest tag for a requirement set.
public struct GuestSymbol: RequirementTagSymbol {
    public let sourceToken: Token
}

/// A library tag for a requirement set.
public struct LibrarySymbol: RequirementTagSymbol {
    public let sourceToken: Token
}

/// A designated requirement tag for a requirement set.
public struct DesignatedSymbol: RequirementTagSymbol {
    public let sourceToken: Token
}
