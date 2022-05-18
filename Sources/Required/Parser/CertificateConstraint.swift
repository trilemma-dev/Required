//
//  CertificateConstraint.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-18
//

public enum CertificateConstraint: Statement, StatementDescribable {
    // anchor apple
    case wholeApple(AnchorSymbol, AppleSymbol)
    // anchor apple generic
    case wholeAppleGeneric(AnchorSymbol, AppleSymbol, GenericSymbol)
    // certificate position = hash
    case whole(CertificatePosition, EqualsSymbol, HashConstantSymbol)
    // certificate position[element] match expression
    case element(CertificatePosition, ElementFragment, MatchFragment)
    // certificate position[element] <- undocumented, frequently seen for designated requirements
    case elementImplicitExists(CertificatePosition, ElementFragment)
    // certificate position trusted
    case trusted(CertificatePosition, TrustedSymbol)
    
    static func attemptParse(tokens: [Token]) throws -> (Statement, [Token])? {
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
            
            guard remainingTokens.first?.type == .hashConstant else {
                throw ParserError.invalidCertificate(description: "No hash constant token after =")
            }
            let hashConstantSymbol = HashConstantSymbol(sourceToken: remainingTokens.removeFirst())
            certificateConstraint = .whole(position, equalsOperator, hashConstantSymbol)
        } else if nextToken.type == .leftBracket { // certificate position[element] match expression
                                                   //                   OR
                                                   // certificate position[element]
            let elementFragmentResult = try ElementFragment.attemptParse(tokens: remainingTokens)
            remainingTokens = elementFragmentResult.1
            
            // certificate position[element] match expression
            if let matchResult = try MatchFragment.attemptParse(tokens: remainingTokens) {
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
    
    var description: StatementDescription {
        switch self {
            case .whole(let certificatePosition, _, let hashConstantSymbol):
                return .constraint(certificatePosition.description + ["=", hashConstantSymbol.value])
            case .wholeApple(_, _):
                return .constraint(["anchor", "apple"])
            case .wholeAppleGeneric(_, _, _):
                return .constraint(["anchor", "apple", "generic"])
            case .element(let certificatePosition, let element, let match):
                return .constraint(certificatePosition.description + element.description + match.description)
            case .elementImplicitExists(let certificatePosition, let element):
                return .constraint(certificatePosition.description + element.description)
            case .trusted(let certificatePosition, _):
                return .constraint(certificatePosition.description + ["trusted"])
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
    
    // This assumes that CertificateStatement.attemptParse(...) already determined this should be a position expression
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
            case .positiveFromLeaf(_, let integerSymbol):
                return ["certificate", integerSymbol.sourceToken.rawValue]
            case .negativeFromAnchor(_, _, let integerSymbol):
                return ["certificate", "-", integerSymbol.sourceToken.rawValue]
            case .anchor(_):
                return ["anchor"]
        }
    }
}

