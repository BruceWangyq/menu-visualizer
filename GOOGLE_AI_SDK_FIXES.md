# Google AI SDK Integration Fixes

## Issue: "No such module 'GoogleGenerativeAI'"

The Google AI Swift SDK package is named `generative-ai-swift` but the module is imported as `GoogleAI`.

## Solution Applied

### 1. Fixed Import Statement
Changed from:
```swift
import GoogleGenerativeAI
```

To:
```swift
import GoogleAI
```

### 2. Updated Model Initialization
The GoogleAI SDK has a simpler initialization:
```swift
self.model = GenerativeModel(
    name: "gemini-1.5-flash",
    apiKey: apiKey
)
```

### 3. Fixed Method Calls
The `generateContent` method signature in GoogleAI SDK:
```swift
try await model.generateContent(prompt, processedImage)
```

## Additional Steps if Build Still Fails

### Option 1: Clean Build
1. Product → Clean Build Folder (Shift+Cmd+K)
2. Close Xcode
3. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. Reopen Xcode and rebuild

### Option 2: Re-add Package
1. Remove the package:
   - Project Navigator → Package Dependencies
   - Right-click on `generative-ai-swift` → Remove
   
2. Re-add the package:
   - File → Add Package Dependencies
   - URL: `https://github.com/google/generative-ai-swift`
   - Branch: `main` or Version: `0.5.0` (latest)
   
3. Make sure to add it to your app target:
   - When prompted, select your "Menu Visualizer" target

### Option 3: Manual Package Resolution
1. File → Packages → Reset Package Caches
2. File → Packages → Resolve Package Versions

### Option 4: Alternative Module Names
If the module name varies by version, try these imports:
```swift
#if canImport(GoogleAI)
import GoogleAI
#elseif canImport(GoogleGenerativeAI)
import GoogleGenerativeAI
#elseif canImport(GenerativeAI)
import GenerativeAI
#endif
```

## Verify Package Integration

1. Check that the package appears in:
   - Project Navigator → Package Dependencies
   - Target → General → Frameworks, Libraries, and Embedded Content

2. Ensure the module is linked to your target:
   - Select your project in navigator
   - Select your app target
   - Build Phases → Link Binary With Libraries
   - Should show GoogleAI or similar

## Test Build

After fixes, try building with:
1. Clean Build Folder (Shift+Cmd+K)
2. Build (Cmd+B)

## If Still Having Issues

The package might need to be added differently. Try:

1. **Using Swift Package Manager directly**:
   ```swift
   // In Package.swift (if you have one)
   dependencies: [
       .package(url: "https://github.com/google/generative-ai-swift", from: "0.5.0")
   ]
   ```

2. **Check Xcode Console**:
   - View → Debug Area → Show Debug Area
   - Look for specific error messages about the package

3. **Verify Network Access**:
   - Xcode needs to download the package
   - Check your network/proxy settings

## Current Working Configuration

- Package: `generative-ai-swift`
- Module: `GoogleAI`
- Version: 0.4.0 or later
- Minimum iOS: 15.0
- Swift: 5.9+