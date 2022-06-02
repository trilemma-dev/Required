//
//  Real World Explorations.swift
//  Required
//
//  Created by Josh Kaplan on 2022-06-02
//

import Required
import XCTest

final class RealWorldTests: XCTestCase {
    /*
    func testPrintAllDesignatedRequirements() throws {
        print("\n")
        for app in installedAppLocations() {
            print(app.pathComponents.last!)
            if let dr = designatedRequirement(url: app) {
                try Parser.parse(tokens: try Tokenizer.tokenize(requirement: dr)).prettyPrint()
            }
            print("\n")
        }
    }*/

    func installedAppLocations() -> [URL] {
        var appURLs = [URL]()
        for dir in FileManager.default.urls(for: .allApplicationsDirectory, in: [.localDomainMask, .userDomainMask]) {
            if let bundles = CFBundleCreateBundlesFromDirectory(nil, dir as CFURL, "app" as CFString) as? [CFBundle] {
                for bundle in bundles {
                    if let location = CFBundleCopyBundleURL(bundle) as URL? {
                        appURLs.append(location)
                    }
                }
            }
        }
        
        return appURLs
    }

    func designatedRequirement(url: URL) -> String? {
        var staticCode: SecStaticCode?
        SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCode)
        guard let staticCode = staticCode else {
            return nil
        }

        var requirement: SecRequirement?
        SecCodeCopyDesignatedRequirement(staticCode, SecCSFlags(), &requirement)
        guard let requirement = requirement else {
            return nil
        }
        
        var requirementString: CFString?
        SecRequirementCopyString(requirement, SecCSFlags(), &requirementString)
        guard let requirementString = requirementString else {
            return nil
        }
        
        return requirementString as String
    }

}
