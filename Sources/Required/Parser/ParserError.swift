//
//  ParserError.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-08
//

public enum ParserError: Error {
    case invalid(description: String)
    case invalidToken(description: String)
    
    case invalidRequirementSet(description: String)
    
    case invalidKeyFragment(description: String)
    case invalidMatchFragment(description: String)
    
    case invalidAnd(description: String)
    case invalidOr(description: String)
    case invalidNegation(description: String)
    case invalidIdentifier(description: String)
    case invalidInfo(description: String)
    case invalidCodeDirectoryHash(description: String)
    case invalidCertificate(description: String)
}