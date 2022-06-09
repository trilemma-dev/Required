# Required
Parse requirement and requirement sets into their abstract syntax tree form and then evaluate them.

Apple provides a compiler for their
[Code Signing Requirement Language](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html)
in the form of
[`SecRequirementCreateWithString`](https://developer.apple.com/documentation/security/1394522-secrequirementcreatewithstring),
but does not expose a parser and its corresponding abstract syntax tree. This package does precisely that.

While Apple does provide an evaluator for a
[`SecRequirement`](https://developer.apple.com/documentation/security/secrequirement) in the form of
[`SecStaticCodeCheckValidity`](https://developer.apple.com/documentation/security/1395784-secstaticcodecheckvalidity),
there is no ability to see _why_ validation has failed. This package provides detailed explanations.

## Example
To see whether and how an application satisfies its designated requirement:
```swift
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
```

Requirements can be provided either as `SecRequirement`s as shown in the above code snippet or as `String`s. Running
this example outputs:
```
Does Numbers.app satisfy its designated requirement?
Yes

Evaluation tree:
and {true}
|--() {true}
|  \--or {true}
|     |--and {true}
|     |  |--anchor apple generic {true}
|     |  \--certificate leaf[field.1.2.840.113635.100.6.1.9] {true}
|     \--and {false}
|        |--and {false}
|        |  |--and {false}
|        |  |  |--anchor apple generic {true}
|        |  |  \--certificate 1[field.1.2.840.113635.100.6.2.6] {false}¹
|        |  \--certificate leaf[field.1.2.840.113635.100.6.1.13] {false}²
|        \--certificate leaf[subject.OU] = K36BKF7T3D {false}³
\--identifier "com.apple.iWork.Numbers" {true}

Constraints not satisfied:
1. The certificate <Apple Worldwide Developer Relations Certification Authority> does not contain OID 1.2.840.113635.100.6.2.6
2. The certificate <Apple Mac OS Application Signing> does not contain OID 1.2.840.113635.100.6.1.13
3. Value not present
```

Each leaf node of the evaluation tree which was not satisfied is annotated with a superscript number. Those numbers are
then used at the bottom to provide explanations for why the leaf node was not satified. 

See this package's DocC documentation for more details.
