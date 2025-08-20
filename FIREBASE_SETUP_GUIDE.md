# Firebase AI Logic Setup Guide

## Quick Setup (5 Minutes)

### 1. Remove Old Package
1. In Xcode: Project Navigator → Package Dependencies
2. Right-click `generative-ai-swift` → Remove
3. Clean Build Folder (Shift+Cmd+K)

### 2. Add Firebase SDK
1. File → Add Package Dependencies
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Version: Latest (11.13.0+)
4. Select `FirebaseAI` library
5. Add to Menu Visualizer target

### 3. Firebase Project Setup
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project (or use existing)
3. Project name: "Menu Visualizer" (or your choice)
4. Add iOS app:
   - Bundle ID: Your app's bundle identifier
   - App nickname: "Menu Visualizer iOS"
5. Download `GoogleService-Info.plist`
6. Drag plist to Xcode project root (next to Info.plist)
7. Ensure "Add to target" is checked for Menu Visualizer

### 4. Enable AI Logic Services
1. In Firebase Console, go to "Build" section
2. Find "AI Logic" (may be under "More products")
3. Click "Get started"
4. Choose "Gemini Developer API" provider
5. Enable the service

### 5. Build and Test
1. Build project (Cmd+B)
2. Should compile without errors
3. Run app to test Firebase initialization

## Expected Results

✅ **Build Success**: No compilation errors
✅ **Firebase Init**: App starts without crashes
✅ **AI Service**: Menu analysis works as before
✅ **Performance**: Same 6-10 second processing times
✅ **Fallback**: OCR fallback works if Firebase unavailable

## Migration Benefits

### Technical Improvements
- **Unified SDK**: Single SDK for all Google AI services
- **Better Security**: Built-in app authentication
- **Enhanced Monitoring**: Firebase analytics and monitoring
- **Future-Proof**: Access to latest AI models and features

### Operational Improvements
- **No Direct API Keys**: Firebase manages authentication
- **Better Rate Limiting**: More sophisticated quota management
- **Improved Error Handling**: More descriptive error messages
- **Service Integration**: Easy integration with other Firebase services

## Configuration Files Changed

### Modified Files
```
Menu_VisualizerApp.swift - Added Firebase initialization
AIMenuAnalysisService.swift - Updated to use Firebase AI
APIKeyManager.swift - Added Firebase configuration checks
AIMenuAnalysisTests.swift - Updated test configurations
```

### New Files
```
GoogleService-Info.plist - Firebase project configuration (you add this)
FIREBASE_AI_MIGRATION.md - Migration documentation
FIREBASE_AI_VALIDATION.md - Validation procedures
FIREBASE_SETUP_GUIDE.md - This setup guide
```

## Troubleshooting Quick Fixes

### "Firebase not configured" Error
- **Cause**: Missing GoogleService-Info.plist
- **Fix**: Download from Firebase Console and add to project

### "Module not found" Build Error
- **Cause**: Firebase SDK not properly added
- **Fix**: Re-add Firebase package, ensure FirebaseAI selected

### App Crashes on Launch
- **Cause**: Firebase initialization issue
- **Fix**: Check GoogleService-Info.plist is in project, clean and rebuild

### AI Analysis Fails
- **Cause**: Firebase AI Logic not enabled
- **Fix**: Enable AI Logic in Firebase Console

## Testing Your Migration

### Basic Functionality Test
1. Launch app
2. Navigate to menu capture
3. Take photo of a menu (or use test image)
4. Verify processing completes successfully
5. Check results are structured correctly

### Error Handling Test
1. Turn off internet connection
2. Attempt menu analysis
3. Should fallback to OCR with appropriate message
4. Turn internet back on, retry should work

## Next Steps After Setup

1. **Monitor Performance**: Check processing times remain 6-10 seconds
2. **Test Error Scenarios**: Verify fallback works properly
3. **User Testing**: Get feedback on any UX changes
4. **Cost Monitoring**: Monitor API usage in Firebase Console
5. **Update Documentation**: Update any internal docs with new setup

## Cost Considerations

### Gemini Developer API Pricing
- **Free Tier**: Generous free tier available (Spark plan)
- **Pay-per-use**: $0.0016 per image (same as before)
- **Rate Limits**: Reasonable limits with ability to request increases
- **Monitoring**: Real-time usage monitoring in Firebase Console

### Cost Control
- **Quotas**: Set spending limits in Firebase Console
- **Monitoring**: Set up alerts for usage thresholds
- **Caching**: 5-minute response cache reduces duplicate API calls
- **Fallback**: Local OCR fallback prevents dependency on paid service

## Support Resources

- **Firebase AI Logic Docs**: https://firebase.google.com/docs/ai-logic
- **Setup Issues**: Check FIREBASE_AI_VALIDATION.md
- **Migration Details**: Review FIREBASE_AI_MIGRATION.md
- **Technical Support**: Firebase support channels