# ``Required``

Parser and evaluator for Apple's [Code Signing Requirement Language](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html).

## Overview

Use this package to parse requirement and requirement sets into their abstract syntax tree form and then evaluate them.

### Motivation
Apple provides a compiler for their Code Signing Requirement Language in the form of
[`SecRequirementCreateWithString`](https://developer.apple.com/documentation/security/1394522-secrequirementcreatewithstring),
but does not expose a parser and its corresponding abstract syntax tree. This package does precisely that.

While Apple does provide an evaluator for a 
[`SecRequirement`](https://developer.apple.com/documentation/security/secrequirement) in the form of
[`SecStaticCodeCheckValidity`](https://developer.apple.com/documentation/security/1395784-secstaticcodecheckvalidity),
there is no ability to see _why_ validation has failed. This package provides detailed explanations.

### Example
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
then used at the bottom to provide explanations for why the leaf node, known as a ``Constraint``, was not satified. 

## Parsing
There are three ways to parse a requirement and one way to parse a requirement set.

To parse a requirement or requirement set in text form, use ``Parser/parse(text:)``:
```swift
let result = Parser.parse(text: "anchor apple generic and certificate leaf[subject.OU] = K36BKF7T3D")
```

To parse a requirement as a `SecRequirement`, use ``Parser/parse(requirement:)`` or
``SecRequirementCopyAbstractSyntaxTree(_:_:_:)``. While they operate in essentially the same manner, the latter matches
the standard pattern used in macOS's Security framework. Use whichever one works better for your code base.

## Evaluating
Any `Requirement` can be used to determine if either the currently running process or an arbitrary application/binary
satisifies its constraints. This is done with ``Requirement/evaluateForSelf()`` or
``Requirement/evaluateForStaticCode(_:)``. The result is an ``Evaluation`` which like `Requirement` is a nested tree
with nodes for each evaluation performed - one per `Requirement`. `Evaluation` contains a preformatted
``Evaluation/prettyDescription`` which textually demonstrated its result as shown in example near the top of this
documentation.

## Compiling
`Requirement`s and `RequirementSet`s can be compiled into their Security framework equivalents via their
``Requirement/compile()`` and ``RequirementSet/compile()`` functions respectively.

## Representing the Code Signing Requirement Language
This package represents code written in Apple's Code Signing Requirement Language as a nested tree of ``Requirement``s
or a ``RequirementSet`` containing `Requirement`s. `Requirement`s which have no children are ``Constraint``s.

There are four types of `Requirements` which are not `Constraint`s:
- ``ParenthesesRequirement``
- ``NegationRequirement``
- ``AndRequirement``
- ``OrRequirement``

The former two each have one child `Requirement` while the latter each have two. These can be accessed via the
``Requirement/children`` property and as such the entire tree can be walked.

There are five types of `Constraints`:
- ``IdentifierConstraint``
- ``InfoConstraint``
- ``EntitlementConstraint``
- ``CertificateConstraint``
- ``CodeDirectoryHashConstraint``

Constraints are always made up of multiple constituent parts, but they never have any child `Requirement`s. For example
the `InfoConstraint` has a properties which expose its ``InfoConstraint/infoSymbol``, ``InfoConstraint/key``, and
``InfoConstraint/match``. The `infoSymbol` is the symbol which marks the constraint as being an info expression; in
most cases this symbol or its equivalent for other `Constraint`s is unlikely to be of much use. The latter two
properties are respectively of types ``KeyExpression`` and ``MatchExpression``. In total there are five such types like
this which constraints are composed of:
- ``MatchExpression`` - the comparison portion of a `Constraint` such as `<= 5.3` or `exists`
- ``WildcardString`` - a wildcard string used in a `MatchExpression`
- ``KeyExpression`` - the key in an info or entitlements dictionary
- ``ElementExpression`` - the subject or OID in a certificate (typealias for `KeyExpression`)
- ``CertificatePosition`` - the position of a certificate within a certificate chain

Additionally ``StringSymbol`` and ``HashConstantSymbol`` are used by multiple constraints and each have a `value`
property to expose their underlying values free of any enclosing characters.

### Requirement Sets
``RequirementSet``s are essentially a dictionary of `Requirement`s as values with ``RequirementTag``s as keys.

The parser when provided with a `String` can parse either a requirement or requirement set so there is no need to know
which it is. As such a ``ParseResult`` is returned with cases for both ``ParseResult/requirement(_:)`` and
``ParseResult/requirementSet(_:)``.

### Tokens
Before parsing can occur, the input is tokenized (lexed) resulting in an array of ``Token``s. This tokenization process
is not publicly exposed, but the tokens that compose each `Requirement` and `RequirementSet` are accessible excluding
whitespace and comments.

For example a ``CodeDirectoryHashConstraint`` has the property ``CodeDirectoryHashConstraint/codeDirectoryHashSymbol``
which exposes ``CodeDirectoryHashSymbol/sourceToken``. In fact all ``Symbol``s have the ``Symbol/sourceToken`` property.
In a few cases there is no intermediate `Symbol` and instead the token is directly exposed such as `KeyExpression`'s
``KeyExpression/leftBracket``.

## OIDs
There are a few OID values you'll frequently see if you look at designated requirements. You may be wondering what are
these and what do they refer to? OIDs are Object Identifiers and they represent essentially all of the types within a
code signing certificate. 

The common requirements you'll see with OIDs are likely:
- `certificate leaf[field.1.2.840.113635.100.6.1.9]`
    - The leaf certificate is for a Mac App Store app
- `certificate leaf[field.1.2.840.113635.100.6.1.13]`
    - This leaf certificate is for a Developer ID Application
- `certificate 1[field.1.2.840.113635.100.6.2.6]`
    - This intermediate certificate is for the Developer ID CA (Certificate Authority)

The first requirement is typically `and`ed together with `anchor apple generic`. The net effect of this requirement is
to evaluate whether the certificate chain was signed by Apple and is for a Mac App Store app.

The latter two requirements are typically `and`ed together along with `anchor apple generic`. Collectively these three
requirements evaluate whether the certificate chain was signed by Apple and is for a Developer ID app.

## Implementation Notes
Here's how the source code for this project is structured:
- /Tokenizer
    - Tokenizes (lexes) a requirement or requirement set into an array of ``Token``s
    - Most of this code is intentionally internal and only indirectly exposed as part of parsing
    - All of the code in this folder intentionally has no macOS framework dependencies including Foundation
        - In the future it's possible this and /Parser will be moved into their own sub-package
- /Parser
    - Parses an array of `Token`s into a ``Requirement`` or a ``RequirementSet``
    - Most of this code is publicly exposed
    - All of the code in this folder intentionally has no macOS framework dependencies including Foundation
        - In the future it's possible this and /Tokenizer will be moved into their own sub-package
- /Evaluator
    - Recursively determines whether a `Requirement` is satisfied for a `SecStaticCode` or for the current process
       - This is exposed as extension functions ``Requirement/evaluateForStaticCode(_:)`` and
         ``Requirement/evaluateForSelf()`` and their return type ``Evaluation``
    - Deep dependency on macOS's [Security](https://developer.apple.com/documentation/security) framework
- /Helpers
    - Everything in this folder is package internal
    - Most of this /Helpers/Security which contains numerous wrappers around Security framework types to make them
      easier to use in Swift
- /
    - Currently just contains `CompileAndParse.swift` which exists to bridge the abstract syntax tree `Requirement` and
      `RequirementSet` with [`SecRequirement`](https://developer.apple.com/documentation/security/secrequirement) and 
      [`SecRequirementType`](https://developer.apple.com/documentation/security/secrequirementtype)

## Topics

### Evaluation
- ``Evaluation``

### Parser
- ``Parser``
- ``ParseResult``
- ``SecRequirementCopyAbstractSyntaxTree(_:_:_:)``

### Parser - Requirements
- ``Requirement``
- ``NegationRequirement``
- ``AndRequirement``
- ``OrRequirement``
- ``ParenthesesRequirement``
- ``Constraint``
- ``IdentifierConstraint``
- ``InfoConstraint``
- ``EntitlementConstraint``
- ``CertificateConstraint``
- ``CodeDirectoryHashConstraint``

### Parser - Constraint Elements
- ``MatchExpression``
- ``KeyExpression``
- ``ElementExpression``
- ``CertificatePosition``
- ``WildcardString``

### Parser - Requirement Set
- ``RequirementSet``
- ``RequirementSetElement``
- ``RequirementTag``

### Parser - Symbols
- ``Symbol``
- ``InfixComparisonOperatorSymbol``
- ``EqualsSymbol``
- ``LessThanSymbol``
- ``LessThanOrEqualToSymbol``
- ``GreaterThanSymbol``
- ``GreaterThanOrEqualToSymbol``
- ``NegationSymbol``
- ``AndSymbol``
- ``OrSymbol``
- ``ExistsSymbol``
- ``StringSymbol``
- ``WildcardSymbol``
- ``IdentifierSymbol``
- ``InfoSymbol``
- ``EntitlementSymbol``
- ``CertificateSymbol``
- ``NegativePositionSymbol``
- ``IntegerSymbol``
- ``RootPositionSymbol``
- ``LeafPositionSymbol``
- ``AnchorSymbol``
- ``AppleSymbol``
- ``GenericSymbol``
- ``TrustedSymbol``
- ``CodeDirectoryHashSymbol``
- ``HashConstantSymbol``
- ``RequirementTagSymbol``
- ``RequirementSetSymbol``
- ``HostSymbol``
- ``GuestSymbol``
- ``LibrarySymbol``
- ``DesignatedSymbol``

### Tokenization
- ``Token``
