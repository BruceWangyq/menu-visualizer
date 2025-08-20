# Gemini Integration Setup Guide

This guide walks you through setting up the Google Generative AI Swift SDK for the Menu Visualizer app.

## Step 1: Add Swift Package Dependency

### Option A: Through Xcode (Recommended)

1. Open `Menu Visualizer.xcodeproj` in Xcode
2. Go to **File** → **Add Package Dependencies**
3. Enter the package URL: `https://github.com/google/generative-ai-swift`
4. Choose **Up to Next Major Version** and set version to `0.4.0`
5. Click **Add Package**
6. Select **GoogleGenerativeAI** target and click **Add Package**

### Option B: Manual Package.swift (Reference)

If you were using Swift Package Manager directly, your Package.swift would look like:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuVisualizer",
    platforms: [
        .iOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/google/generative-ai-swift", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "MenuVisualizer",
            dependencies: [
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift")
            ]
        )
    ]
)
```

## Step 2: Configure API Key

### Option A: Environment Variable (Recommended for Development)

Add to your Xcode scheme's environment variables:
1. Go to **Product** → **Scheme** → **Edit Scheme**
2. Select **Run** → **Arguments** → **Environment Variables**
3. Add: `GEMINI_API_KEY` = `your_actual_api_key_here`

### Option B: Info.plist Configuration

Add to your `Info.plist`:
```xml
<key>GEMINI_API_KEY</key>
<string>$(GEMINI_API_KEY)</string>
```

Then add to your build settings:
1. Go to **Build Settings** → **User-Defined**
2. Add: `GEMINI_API_KEY` = `your_actual_api_key_here`

### Option C: Keychain Storage (Most Secure)

The app already supports secure keychain storage via `APIKeyManager`:

```swift
// Store API key securely
let result = APIKeyManager.shared.storeGeminiAPIKey("your_api_key")
```

## Step 3: Get Your Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click **Create API key**
4. Copy the generated key
5. Store it using one of the methods above

## Step 4: Verify Integration

The `AIMenuAnalysisService` will automatically:
- Check for API key availability
- Fall back to Claude or local OCR if unavailable
- Handle rate limiting and errors gracefully

## Security Best Practices

1. **Never commit API keys to version control**
2. **Use environment variables for development**
3. **Use keychain storage for production**
4. **Rotate keys regularly**
5. **Monitor API usage and costs**

## Cost Monitoring

Gemini 1.5 Flash pricing (as of August 2025):
- Input: $0.075 per 1M tokens
- Output: $0.30 per 1M tokens
- Images: $0.0016 per image (1024x1024)

Estimated costs for Menu Visualizer:
- 100 menu scans/day: ~$48/month
- 1000 menu scans/day: ~$480/month

## Troubleshooting

### Common Issues

1. **"No API key configured"**
   - Check that GEMINI_API_KEY is set
   - Verify APIKeyManager.shared.getGeminiAPIKey() returns a value

2. **"Invalid API key format"**
   - Ensure your API key is from Google AI Studio
   - Check for extra spaces or characters

3. **"Rate limit exceeded"**
   - Implement exponential backoff (already built-in)
   - Consider upgrading your quota

4. **Build errors**
   - Clean build folder: Product → Clean Build Folder
   - Reset package cache: File → Swift Packages → Reset Package Caches

## Migration from OCR Service

The new AI service maintains compatibility with existing data models:

```swift
// Old way
let ocrResult = await ocrService.extractText(from: image)
let parsingResult = await parsingService.extractDishes(from: ocrResult)

// New way (single call)
let aiResult = await aiService.analyzeMenu(from: image)
```

All existing `Menu` and `Dish` objects work seamlessly with the new service.