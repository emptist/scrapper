# WebVideoAnalyzer Code Quality Guidelines

This document outlines the code quality standards and guidelines for the WebVideoAnalyzer project. These rules are enforced through configuration files and should be followed by all contributors.

## Enforced Rules

### 1. Architecture Guidelines

- **MVVM Architecture**: Use Model-View-ViewModel pattern with clear separation of concerns
- **Protocol-Oriented Programming**: Prefer protocols over class inheritance
- **Service Separation**: Services like CommandLineHandler and AnalysisService should be separate components
- **Size Limitations**:
  - Type bodies: 300 lines warning, 500 lines error
  - Files: 400 lines warning, 600 lines error
  - Function bodies: 50 lines warning, 100 lines error

### 2. Swift Language Best Practices

- **Swift 6.2 Compatibility**: Leverage latest Swift features
- **Type Safety**: Minimize force unwrapping and use appropriate error handling
- **Memory Management**: Avoid retain cycles and optimize ARC usage
- **Performance Optimization**: Follow efficiency guidelines for collections and algorithms

### 3. Code Organization

- **Documentation**: Document all public APIs
- **Naming Conventions**: Follow Swift API Design Guidelines
  - Classes/Structs: PascalCase
  - Variables/Properties: camelCase
  - Constants: camelCase with capitalized acronyms where appropriate

### 4. Error Handling

- **Safe Unwrapping**: Avoid force unwrapping (!) and force try
- **Error Propagation**: Use Swift's error handling mechanisms appropriately
- **Defensive Programming**: Validate inputs and handle edge cases

## Configuration Files

### SwiftLint (.swiftlint.yml)

The project uses SwiftLint to enforce code quality rules. The configuration is in the root directory:

```
.scrapper/.swiftlint.yml
```

### IDE Settings (.vscode/settings.json)

For VSCode users, there are recommended settings to support the code quality rules:

```
.scrapper/.vscode/settings.json
```

## Using the Tools

### Installing SwiftLint

To install SwiftLint:

```bash
# Using Homebrew
brew install swiftlint
```

### Running SwiftLint

To run SwiftLint manually:

```bash
# In the project root directory
swiftlint
```

### IDE Integration

For automatic linting during development:

1. **VSCode**: Install the "SwiftLint" extension by vknabel
2. **Xcode**: Consider using SwiftLintXcode or SwiftLint via build phases

## Exceptions

In some cases, exceptions to the rules may be necessary. Use the following inline comments to disable rules temporarily:

```swift
// swiftlint:disable:next force_unwrapping
let value = someOptional!

// swiftlint:disable function_body_length
func complexFunction() {
    // Implementation that exceeds length limit but is justified
}
// swiftlint:enable function_body_length
```

## Contributing

When contributing code:

1. Run SwiftLint before submitting PRs
2. Follow the established architecture patterns
3. Add appropriate documentation for new APIs
4. Write tests for new functionality

## Regular Review

These guidelines should be reviewed periodically to ensure they remain aligned with best practices and the project's evolving needs.
