//
//  CertificateConstraint.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-18
//

/// A constraint on certificates in the certificate chain used to validate the signature.
public enum CertificateConstraint: Constraint {
    public static let signifier = "certificate"
    
    /// Apple's own code.
    ///
    /// Textually represented as `anchor apple`.
    case wholeApple(AnchorSymbol, AppleSymbol)
    
    /// Code signed by Apple including code signed using a signing certificate issued by Apple to other developers.
    ///
    /// Textually represented as `anchor apple generic`.
    case wholeAppleGeneric(AnchorSymbol, AppleSymbol, GenericSymbol)
    
    /// A certificate at a specific position in the certificate chain hashes to a specific SHA1 value.
    ///
    /// Textually represented as `certificate position = hash` where `position` is a certificate position and `hash` is a SHA1 hash constant.
    case wholeHashConstant(CertificatePosition, EqualsSymbol, HashConstantSymbol)
    
    /// A certificate at a specific position in the certificate chain hashes to the same SHA1 value as the file referenced by a certificate file.
    ///
    /// Textually represented as `certificate position = filePath` where `position` is a certificate position and `filePath` is a certificate file.
    case wholeHashFilePath(CertificatePosition, EqualsSymbol, StringSymbol)
    
    /// An element at a specific position in the certificate chain satisfies the match expression.
    ///
    /// Elements can either be a specific `subject` element such as `subject.CN` or an OID field value such as `field.1.2.840.113635.100.6.2.6`.
    ///
    /// Textually represented as: `certificate position[element] matchExpression` where `position` is a certificate position and
    /// `matchExpresion` is a valid match expression.
    case element(CertificatePosition, ElementExpression, MatchExpression)
    
    /// An element at a specific position in the certificate chain exists.
    ///
    /// Elements can either be a specific `subject` element such as `subject.CN` or an OID field value such as `field.1.2.840.113635.100.6.2.6`.
    ///
    /// Textually represented as: `certificate position[element]` where `position` is a certificate position.
    ///
    /// >Note: This constraint form is not documented by Apple but is extremely common in app's designated requirements.
    case elementImplicitExists(CertificatePosition, ElementExpression)
    
    // certificate position trusted
    /// A certificate at a specific position in the certificate chain is trusted in the system's Trust Settings database.
    ///
    /// Textually represented as: `certificate position trusted` where `position` is a certificate position.
    case trusted(CertificatePosition, TrustedSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (Requirement, [Token])? {
        guard let firstToken = tokens.first,
              firstToken.type == .identifier,
              ["cert", "certificate", "anchor"].contains(firstToken.rawValue) else {
            return nil
        }
        
        let certificateConstraint: CertificateConstraint
        
        let positionParseResult = try CertificatePosition.attemptParse(tokens: tokens)
        let position = positionParseResult.0
        var remainingTokens = positionParseResult.1
        
        // Apple's documentation claims that "anchor" is equivalent to "certificate root", but unfortunately testing
        // shows this to be false because while "anchor apple" is valid, "certificate root apple" is not. So special
        // casing is needed for:
        //   anchor apple
        //   anchor apple generic
        if case .anchor(let anchorSymbol) = position,
           remainingTokens.first?.type == .identifier,
           remainingTokens.first?.rawValue == "apple" {
            let appleSymbol = AppleSymbol(sourceToken: remainingTokens.removeFirst())
            if remainingTokens.first?.type == .identifier, remainingTokens.first?.rawValue == "generic" {
                let genericSymbol = GenericSymbol(sourceToken: remainingTokens.removeFirst())
                certificateConstraint = .wholeAppleGeneric(anchorSymbol, appleSymbol, genericSymbol)
            } else {
                certificateConstraint = .wholeApple(anchorSymbol, appleSymbol)
            }
            
            return (certificateConstraint, remainingTokens)
        }
        
        // All other cases
        guard let nextToken = remainingTokens.first else {
            throw ParserError.invalidCertificate(description: "No token after certificate position")
        }
                
        if nextToken.type == .identifier, nextToken.rawValue == "trusted" { // certificate position trusted
            let trustedSymbol = TrustedSymbol(sourceToken: remainingTokens.removeFirst())
            certificateConstraint = .trusted(position, trustedSymbol)
        } else if nextToken.type == .equals { // certificate position = hash
            let equalsOperator = EqualsSymbol(sourceToken: remainingTokens.removeFirst())
            
            if remainingTokens.first?.type == .hashConstant { // Hash is a constant
                let hashConstantSymbol = HashConstantSymbol(sourceToken: remainingTokens.removeFirst())
                certificateConstraint = .wholeHashConstant(position, equalsOperator, hashConstantSymbol)
            } else if remainingTokens.first?.type == .identifier { // Hash is a file path
                let filePath = StringSymbol(sourceToken: remainingTokens.removeFirst())
                certificateConstraint = .wholeHashFilePath(position, equalsOperator, filePath)
            } else {
                throw ParserError.invalidCertificate(description: "No hash constant or file path after =")
            }
        } else if nextToken.type == .leftBracket { // certificate position[element] match expression
                                                   //                   OR
                                                   // certificate position[element]
            let elementFragmentResult = try ElementExpression.attemptParse(tokens: remainingTokens)
            remainingTokens = elementFragmentResult.1
            
            // certificate position[element] match expression
            if let matchResult = try MatchExpression.attemptParse(tokens: remainingTokens) {
                certificateConstraint = .element(position, elementFragmentResult.0, matchResult.0)
                remainingTokens = matchResult.1
            } else { // certificate position[element]
                certificateConstraint = .elementImplicitExists(position, elementFragmentResult.0)
            }
        } else {
            throw ParserError.invalidCertificate(description: "Token after certificiate position not one of: " +
                                                 "trusted, =, or [")
        }
        
        return (certificateConstraint, remainingTokens)
    }
    
    public var textForm: String {
        switch self {
            case .wholeApple(_, _):
                return "anchor apple"
            case .wholeAppleGeneric(_, _, _):
                return "anchor apple generic"
            case .wholeHashConstant(let position, _, let hashConstant):
                return "\(position.textForm) = \(hashConstant.sourceToken.rawValue)"
            case .wholeHashFilePath(let position, _, let string):
                return "\(position.textForm) = \(string.sourceToken.rawValue)"
            case .element(let position, let element, let match):
                return "\(position.textForm)\(element.textForm) \(match.textForm)"
            case .elementImplicitExists(let position, let element):
                return "\(position.textForm)\(element.textForm)"
            case .trusted(let position, _):
                return "\(position.textForm) trusted"
        }
    }
    
    public var sourceRange: Range<String.Index> {
        switch self {
            case .wholeApple(let anchor, let apple):
                return anchor.sourceToken.range.lowerBound..<apple.sourceToken.range.upperBound
            case .wholeAppleGeneric(let anchor, _, let generic):
                return anchor.sourceToken.range.lowerBound..<generic.sourceToken.range.upperBound
            case .wholeHashConstant(let position, _, let hashConstant):
                return position.sourceLowerBound..<hashConstant.sourceToken.range.upperBound
            case .wholeHashFilePath(let position, _, let string):
                return position.sourceLowerBound..<string.sourceToken.range.upperBound
            case .element(let position, _, let match):
                return position.sourceLowerBound..<match.sourceUpperBound
            case .elementImplicitExists(let position, let element):
                return position.sourceLowerBound..<element.rightBracket.range.upperBound
            case .trusted(let position, let trusted):
                return position.sourceLowerBound..<trusted.sourceToken.range.upperBound
        }
    }
}

public enum CertificatePosition {
    case root(CertificateSymbol, RootPositionSymbol) // certificate root
    case leaf(CertificateSymbol, LeafPositionSymbol) // certificate leaf
    case positiveFromLeaf(CertificateSymbol, IntegerSymbol) // certificate 2
    case negativeFromAnchor(CertificateSymbol, NegativePositionSymbol, IntegerSymbol) // certificate -3
    case anchor(AnchorSymbol) // anchor
    
    // Note that it's not possible to express `certificate anchor` with the above despite the documentation implying
    // such is possible. However, trying to create security requirement of `certificate anchor trusted` fails to
    // compile.
    //
    // From Apple:
    //   The syntax `anchor trusted` is not a synonym for `certificate anchor trusted`. Whereas the former checks all
    //   certificates in the signature, the latter checks only the anchor certificate.
    
    // This assumes that CertificateRequirement.attemptParse(...) already determined this should be a position expression
    static func attemptParse(tokens: [Token]) throws -> (CertificatePosition, [Token]) {
        var remainingTokens = tokens
        
        let position: CertificatePosition
        if remainingTokens.first?.rawValue == "anchor" {
            position = .anchor(AnchorSymbol(sourceToken: remainingTokens.removeFirst()))
        } else {
            let certificateSymbol = CertificateSymbol(sourceToken: remainingTokens.removeFirst())
            guard let secondToken = remainingTokens.first else {
                throw ParserError.invalidCertificate(description: "Missing token after certificate")
            }
            
            if secondToken.type == .identifier {
                if secondToken.rawValue == "root" {
                    position = .root(certificateSymbol, RootPositionSymbol(sourceToken: remainingTokens.removeFirst()))
                } else if secondToken.rawValue == "leaf" {
                    position = .leaf(certificateSymbol, LeafPositionSymbol(sourceToken: remainingTokens.removeFirst()))
                } else if UInt(secondToken.rawValue) != nil {
                    position = .positiveFromLeaf(certificateSymbol,
                                                 IntegerSymbol(sourceToken: remainingTokens.removeFirst()))
                } else {
                    throw ParserError.invalidCertificate(description: "Identifier token after certificate " +
                                                                   "is not root, leaf, or an unsigned integer")
                }
            } else if secondToken.type == .negativePosition {
                let negativePositionSymbol = NegativePositionSymbol(sourceToken: remainingTokens.removeFirst())
                
                if let thirdToken = remainingTokens.first,
                   thirdToken.type == .identifier,
                   UInt(thirdToken.rawValue) != nil {
                    position = .negativeFromAnchor(certificateSymbol,
                                                   negativePositionSymbol,
                                                   IntegerSymbol(sourceToken: remainingTokens.removeFirst()))
                } else {
                    throw ParserError.invalidCertificate(description: "Identifier token after - is not an unsigned " +
                                                         "integer")
                }
            } else {
                throw ParserError.invalidCertificate(description: "Token after certificate is not an identifier or " +
                                                     "negative position")
            }
        }
        
        return (position, remainingTokens)
    }
    
    var description: [String] {
        switch self {
            case .root(_, _):
                return ["certificate", "root"]
            case .leaf(_, _):
                return ["certificate", "leaf"]
            case .positiveFromLeaf(_, let integer):
                return ["certificate", integer.sourceToken.rawValue]
            case .negativeFromAnchor(_, _, let integer):
                return ["certificate", "-", integer.sourceToken.rawValue]
            case .anchor(_):
                return ["anchor"]
        }
    }
    
    var textForm: String {
        switch self {
            case .root(_, _):
                return "certificate root"
            case .leaf(_, _):
                return "certificate leaf"
            case .positiveFromLeaf(_, let integer):
                return "certificate \(integer.sourceToken.rawValue)"
            case .negativeFromAnchor(_, _, let integer):
                return "certificate -\(integer.sourceToken.rawValue)"
            case .anchor(_):
                return "anchor"
        }
    }
    
    public var sourceLowerBound: String.Index {
        switch self {
            case .root(let certificate, _):
                return certificate.sourceToken.range.lowerBound
            case .leaf(let certificate, _):
                return certificate.sourceToken.range.lowerBound
            case .positiveFromLeaf(let certificate, _):
                return certificate.sourceToken.range.lowerBound
            case .negativeFromAnchor(let certificate, _, _):
                return certificate.sourceToken.range.lowerBound
            case .anchor(let anchor):
                return anchor.sourceToken.range.lowerBound
        }
    }
}

