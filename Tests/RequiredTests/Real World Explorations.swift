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
            // Xcode is massive and therefore takes an inconvenient amount of time to validate
            if app.lastPathComponent == "Xcode.app" { continue }
            
            // Debug hack
            //if app.lastPathComponent != "Narrative Publish.app" { continue }
            
            print(app.lastPathComponent)
            let (staticCode, designatedRequirement) = designatedRequirement(url: app)
            
            if let staticCode = staticCode, let designatedRequirement = designatedRequirement {
                let requirement = try Parser.parse(requirement: designatedRequirement)
                let evaluation = try requirement.evaluateForStaticCode(staticCode)
                print(evaluation.prettyDescription)
            }
            print("\n")
        }
    }*/
    
    /*
    func testDesignatedRequirementOfTestCLT() throws {
        let containingDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
        let executableURL = URL(fileURLWithPath: "TestCLT", relativeTo: containingDir).absoluteURL

        let designatedRequirement = designatedRequirement(url: executableURL).1!

        let abstractRequirement = try Parser.parse(requirement: designatedRequirement)
        print(abstractRequirement.prettyDescription)
    }
    */
    
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

    func designatedRequirement(url: URL) -> (SecStaticCode?, SecRequirement?) {
        var staticCode: SecStaticCode?
        SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCode)
        guard let staticCode = staticCode else {
            return (nil, nil)
        }

        var requirement: SecRequirement?
        SecCodeCopyDesignatedRequirement(staticCode, SecCSFlags(), &requirement)
        guard let requirement = requirement else {
            return (staticCode, nil)
        }
        
        return (staticCode, requirement)
    }
    
    /*
    func testNumbersForDocumentation() throws {
        // Retrieve the designated requirement for Numbers
        let url = URL(fileURLWithPath: "/Applications/Numbers.app")
        var code: SecStaticCode?
        SecStaticCodeCreateWithPath(url as CFURL, [], &code)
        var requirement: SecRequirement?
        SecCodeCopyDesignatedRequirement(code!, [], &requirement)

        // See whether and how Numbers satisifies its designated requirement
        let abstractRequirement = try Parser.parse(requirement: requirement!)
        let evaluation = try abstractRequirement.evaluateForStaticCode(code!)
        print("Does \(url.lastPathComponent) satisfy its designated requirement?")
        print(evaluation.isSatisfied ? "Yes" : "No")
        print("\nEvaluation tree:")
        print(evaluation.prettyDescription)
    }
    */
}
