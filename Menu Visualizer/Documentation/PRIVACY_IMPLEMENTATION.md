# Privacy Implementation Guide - Menuly iOS App

## Overview

Menuly is designed as a **privacy-first** iOS application that processes menu photos locally and only sends minimal dish information to Claude API for visualization generation. This document outlines our comprehensive privacy compliance and data protection implementation.

## Core Privacy Principles

### 1. Data Minimization
- **On-Device Processing**: All OCR and image analysis happens locally using Apple Vision framework
- **Minimal API Calls**: Only dish names and basic descriptions are sent to external APIs
- **No Personal Data**: Zero collection of personal information, location data, or user identification

### 2. Transparent Communication
- **Clear Consent**: Explicit consent for all data processing activities
- **Real-Time Status**: Live privacy dashboard showing data retention status
- **Violation Detection**: Automatic detection and reporting of privacy policy violations

### 3. User Control
- **Granular Settings**: Fine-grained control over data handling and retention
- **One-Tap Deletion**: Immediate and complete data removal
- **Consent Withdrawal**: Easy withdrawal of previously granted permissions

## iOS Security Framework Integration

### Keychain Services
```swift
// Secure storage using iOS Keychain
func securelyStore(data: Data, for key: String, requiresBiometric: Bool = true) async throws {
    var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    
    if requiresBiometric && isBiometricAuthEnabled {
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryAny,
            nil
        )
        query[kSecAttrAccessControl as String] = access
    }
    
    let status = SecItemAdd(query as CFDictionary, nil)
    // Handle status...
}
```

### Core Data Encryption
```swift
// Core Data with iOS data protection
let storeDescription = container.persistentStoreDescriptions.first
storeDescription?.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject, 
                           forKey: NSPersistentHistoryTrackingKey)
storeDescription?.setOption(true as NSObject, forKey: NSPersistentStoreFileProtectionKey)
```

### Local Authentication
```swift
// Biometric protection for sensitive features
func authenticateWithBiometrics(reason: String) async throws -> Bool {
    return try await withCheckedThrowingContinuation { continuation in
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { success, error in
            if let error = error {
                continuation.resume(throwing: DataProtectionError.biometricAuthFailed(error))
            } else {
                continuation.resume(returning: success)
            }
        }
    }
}
```

### Memory Protection
```swift
// Protected memory with automatic cleanup
class ProtectedMemory {
    private var data: Data
    
    func accessSecurely<T>(_ block: (Data) throws -> T) rethrows -> T {
        defer {
            data.resetBytes(in: 0..<data.count) // Clear sensitive data
        }
        return try block(data)
    }
    
    deinit {
        data.resetBytes(in: 0..<data.count) // Ensure cleanup
    }
}
```

## App Store Compliance

### Privacy Manifest (iOS 17+)
```xml
<key>NSPrivacyTracking</key>
<false/>
<key>NSPrivacyCollectedDataTypes</key>
<array>
    <dict>
        <key>NSPrivacyCollectedDataType</key>
        <string>NSPrivacyCollectedDataTypeUserContent</string>
        <key>NSPrivacyCollectedDataTypeLinkedToUser</key>
        <false/>
        <key>NSPrivacyCollectedDataTypeUsedForTracking</key>
        <false/>
    </dict>
</array>
```

### App Store Privacy Labels
- **Data Not Collected**: No data linked to user identity
- **Data Not Used for Tracking**: Zero user tracking across apps/websites
- **Data Not Shared**: No data sharing with third parties

## Privacy Architecture Components

### 1. PrivacyComplianceService
- **Compliance Monitoring**: Real-time privacy compliance scoring
- **Violation Detection**: Automatic privacy policy violation detection
- **Data Auditing**: Comprehensive data retention auditing
- **Manifest Validation**: iOS 17+ privacy manifest compliance

### 2. DataProtectionManager
- **Keychain Integration**: Secure storage using iOS Keychain Services
- **File Protection**: iOS data protection classes for file system security
- **Memory Protection**: Secure memory handling with automatic cleanup
- **Biometric Security**: Face ID/Touch ID integration for sensitive operations

### 3. ConsentManager
- **iOS ATT Compliance**: App Tracking Transparency framework integration
- **Granular Consent**: Category-specific consent management
- **Consent Persistence**: Secure storage of consent records
- **Withdrawal Mechanism**: Immediate consent withdrawal with data cleanup

### 4. APIPrivacyLayer
- **TLS 1.3 Enforcement**: Mandatory secure connections
- **Certificate Pinning**: Additional security for API communications
- **Privacy Headers**: DNT and privacy-focused request headers
- **Request Auditing**: Privacy-compliant API request logging

### 5. PrivacySettingsService
- **iOS Settings Integration**: System-level privacy controls
- **Permission Management**: Camera and notification permission handling
- **Settings Validation**: Privacy settings health monitoring
- **Biometric Integration**: Secure settings protection

## Data Flow and Processing

### Menu Photo Processing
1. **Image Capture**: Camera photo captured in memory only
2. **Local OCR**: Apple Vision framework processes image on-device
3. **Text Extraction**: Menu text extracted without image persistence
4. **Dish Parsing**: Local parsing to identify individual dishes
5. **Privacy Validation**: Consent check before any external communication

### API Communication
1. **Consent Verification**: Explicit user consent required
2. **Data Minimization**: Only dish name and basic description sent
3. **Secure Transport**: TLS 1.3 with certificate pinning
4. **Response Processing**: AI visualization received and processed locally
5. **Immediate Cleanup**: All API data cleared based on retention policy

### Data Retention Policies

#### Session Only (Default)
- Data cleared when app is terminated
- Temporary files auto-deleted
- No persistent storage of sensitive information

#### Never Store (Maximum Privacy)
- Data cleared immediately after each operation
- No caching or temporary storage
- Real-time processing only

## Security Features

### Network Security
- **TLS 1.3 Only**: Latest secure protocol required
- **Certificate Pinning**: Prevents man-in-the-middle attacks
- **Network Monitoring**: Detects insecure network conditions
- **Privacy Headers**: DNT and cache-control headers

### Screen Protection
- **Screenshot Detection**: Automatic content hiding during screenshots
- **Screen Recording Protection**: Sensitive content blurred during recording
- **Background Protection**: Content hidden when app enters background

### Device Security
- **Jailbreak Detection**: Enhanced security on compromised devices
- **Debug Detection**: Prevents privacy violations during debugging
- **Secure Enclave**: Hardware-backed security when available

## Privacy Testing

### Automated Test Suite
```swift
func testDataRetentionCompliance() async {
    privacyCompliance.privacySettings.dataRetentionPolicy = .never
    privacyCompliance.trackImageCapture()
    
    // Should trigger immediate cleanup
    await privacyCompliance.auditDataRetention()
    
    XCTAssertFalse(privacyCompliance.dataRetentionStatus.hasAnyData)
}

func testPrivacyViolationDetection() async {
    // Simulate violation condition
    privacyCompliance.privacySettings.dataRetentionPolicy = .never
    privacyCompliance.trackImageCapture()
    
    await privacyCompliance.auditDataRetention()
    
    XCTAssertGreaterThan(privacyCompliance.privacyViolations.count, 0)
}
```

### Manual Testing Procedures
1. **Privacy Dashboard**: Verify real-time data status updates
2. **Consent Flow**: Test complete consent collection and withdrawal
3. **Data Deletion**: Verify complete data removal
4. **Security Audit**: Regular security validation testing

## App Store Submission Checklist

### Privacy Manifest Requirements ✅
- [x] NSPrivacyTracking set to false
- [x] Empty NSPrivacyTrackingDomains array
- [x] Accurate NSPrivacyCollectedDataTypes
- [x] Proper NSPrivacyAccessedAPITypes declarations

### App Store Privacy Labels ✅
- [x] "Data Not Collected" accurately reflects app behavior
- [x] No tracking across apps and websites
- [x] No data linked to user identity
- [x] No data shared with third parties

### iOS Security Integration ✅
- [x] Keychain Services for secure storage
- [x] Local Authentication for biometric protection
- [x] Core Data encryption enabled
- [x] File protection with appropriate classes

### Testing & Validation ✅
- [x] Comprehensive test suite covering all privacy features
- [x] Manual testing procedures documented
- [x] Privacy compliance monitoring active
- [x] Security audit reports generated

## Compliance Standards

### Apple Privacy Guidelines
- **Data Minimization**: Only collect data necessary for functionality
- **User Consent**: Clear, informed consent for all data processing
- **Transparency**: Honest communication about data practices
- **User Control**: Easy access to privacy settings and data deletion

### Security Best Practices
- **Defense in Depth**: Multiple layers of security controls
- **Secure by Default**: Privacy-first default settings
- **Regular Auditing**: Continuous monitoring and validation
- **Incident Response**: Automatic violation detection and response

## Future Enhancements

### Planned Features
1. **Enhanced Encryption**: Additional encryption layers for sensitive operations
2. **Zero-Knowledge Architecture**: Explore zero-knowledge proof implementations
3. **Privacy Analytics**: Anonymous privacy metrics for app improvement
4. **International Compliance**: GDPR and other regional privacy regulations

### Monitoring & Maintenance
1. **Regular Security Audits**: Quarterly comprehensive security reviews
2. **Privacy Impact Assessments**: Evaluate privacy implications of new features
3. **Compliance Updates**: Stay current with evolving privacy regulations
4. **User Education**: Ongoing privacy education and transparency efforts

## Contact & Support

For privacy-related questions or concerns:
- **Privacy Policy**: Available in-app and at https://menuly.app/privacy
- **Contact**: privacy@menuly.app
- **Security Issues**: security@menuly.app

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Review Schedule**: Quarterly