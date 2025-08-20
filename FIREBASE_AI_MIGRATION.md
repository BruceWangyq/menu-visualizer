# Firebase AI Logic Migration Guide

## Overview

Google has deprecated the direct `generative-ai-swift` SDK in favor of Firebase AI Logic (formerly Vertex AI in Firebase). This migration guide covers the transition from direct Google AI SDK to Firebase AI Logic.

## Key Changes

### SDK Migration
- **Old**: `generative-ai-swift` package
- **New**: Firebase iOS SDK with `FirebaseAI` module

### Import Changes
```swift
// Old approach
import GoogleAI

// New approach
import FirebaseCore
import FirebaseAI
```

### Initialization Changes
```swift
// Old approach
let model = GenerativeModel(
    name: "gemini-1.5-flash",
    apiKey: apiKey
)

// New approach
let ai = FirebaseAI.firebaseAI(backend: .googleAI())
let model = ai.generativeModel(modelName: "gemini-1.5-flash")
```

## Migration Steps

### 1. Remove Old Package
1. In Xcode, go to Project Navigator → Package Dependencies
2. Remove `generative-ai-swift` package
3. Clean build folder (Shift+Cmd+K)

### 2. Add Firebase SDK
1. File → Add Package Dependencies
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Version: Latest (11.13.0+)
4. Select `FirebaseAI` library
5. Add to Menu Visualizer target

### 3. Firebase Project Setup
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project or use existing one
3. Add iOS app with bundle ID: `com.yourcompany.Menu-Visualizer`
4. Download `GoogleService-Info.plist`
5. Add plist to Xcode project root

### 4. App Configuration
Add Firebase initialization to AppDelegate or App struct:

```swift
import FirebaseCore

// In AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()
    return true
}

// Or in SwiftUI App struct
@main
struct MenuVisualizerApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## API Differences

### Model Creation
```swift
// Old
let model = GenerativeModel(name: "gemini-1.5-flash", apiKey: apiKey)

// New
let ai = FirebaseAI.firebaseAI(backend: .googleAI())
let model = ai.generativeModel(modelName: "gemini-1.5-flash")
```

### Content Generation
```swift
// Old & New - Same API
let response = try await model.generateContent(prompt, image)
let text = response.text
```

### Error Handling
Firebase AI Logic provides more structured error types and better integration with Firebase services.

## Benefits of Firebase AI Logic

### Enhanced Security
- Built-in security options against unauthorized clients
- Integration with Firebase Authentication
- App Check support for additional security

### Better Integration  
- Seamless integration with other Firebase services
- Unified SDK across all Google AI services
- Better analytics and monitoring

### Improved Performance
- Optimized for mobile usage
- Better caching and retry logic
- Enhanced network handling

## Configuration Requirements

### Firebase Project Setup
1. **Enable AI Logic API**: In Firebase console, enable AI Logic services
2. **Configure Billing**: Set up billing for API usage (Spark plan available for free tier)
3. **Set Usage Limits**: Configure quotas and rate limits

### API Key Management
- API keys now managed through Firebase project settings
- Better integration with Firebase security rules
- Support for multiple API backends (Gemini Developer API, Vertex AI)

## Testing Migration

### Unit Tests
Update test cases to use Firebase AI Logic:

```swift
@testable import Menu_Visualizer
import FirebaseCore
import FirebaseAI

class AIMenuAnalysisTests: XCTestCase {
    override func setUp() async throws {
        // Configure Firebase for testing
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
}
```

### Integration Tests
- Test with real Firebase project
- Validate API key configuration
- Test error handling scenarios

## Rollback Plan

If issues arise during migration:

1. **Keep old implementation**: Maintain both implementations initially
2. **Feature flag**: Use feature flags to switch between implementations
3. **Gradual rollout**: Test with subset of users first

## Performance Expectations

### Same Performance Characteristics
- Processing time: 6-10 seconds (maintained)
- Accuracy: 90-95% (maintained or improved)
- Caching: 5-minute cache (maintained)

### Enhanced Reliability
- Better error handling and retry logic
- Improved network resilience
- Better monitoring and debugging

## Migration Checklist

- [ ] Remove `generative-ai-swift` package
- [ ] Add Firebase iOS SDK (11.13.0+)
- [ ] Create/configure Firebase project
- [ ] Add GoogleService-Info.plist
- [ ] Initialize Firebase in app
- [ ] Update import statements
- [ ] Refactor AIMenuAnalysisService
- [ ] Update error handling
- [ ] Update API key management
- [ ] Test integration
- [ ] Validate performance
- [ ] Update documentation

## Support Resources

- [Firebase AI Logic Documentation](https://firebase.google.com/docs/ai-logic)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Firebase AI Logic Models](https://firebase.google.com/docs/ai-logic/models)
- [Firebase AI Logic Pricing](https://firebase.google.com/docs/ai-logic/pricing)