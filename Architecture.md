# Menuly iOS App Architecture

## Overview

Menuly is a privacy-first iOS app that captures menu photos, performs on-device OCR using Apple Vision framework, extracts dish information, and generates AI visualizations through secure Claude API calls. The architecture prioritizes user privacy, performance, and iOS best practices.

## Architecture Pattern: MVVM + Coordinator

### Core Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Views (UI)    │────│  ViewModels     │────│    Services     │
│   SwiftUI       │    │  Business Logic │    │  Data/Network   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                        │                        │
        │                        │                        │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Coordinators   │    │   Data Models   │    │   Frameworks    │
│   Navigation    │    │   Entities      │    │ Vision/Network  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Data Flow Pipeline

**Privacy-First Processing**: Photo → OCR → Parsing → API Call → Visualization Display

```
[Camera Capture] → [Vision OCR] → [Text Parsing] → [API Request] → [Visualization Display]
       │               │              │              │                    │
   UIImage         String Array   DishInfo[]    APIResponse         Generated Image
   (device)        (device)      (device)      (minimal data)        (display only)
```

## Directory Structure

```
Menu Visualizer/
├── Models/
│   └── DataModels.swift              # Core data structures
├── Navigation/
│   └── AppCoordinator.swift          # Navigation coordinator
├── Services/
│   ├── CameraService.swift           # Camera & photo capture
│   ├── OCRService.swift              # Vision framework OCR
│   ├── MenuParsingService.swift      # Dish extraction logic
│   ├── VisualizationService.swift    # Claude API integration
│   ├── PrivacyComplianceService.swift # Privacy management
│   └── PerformanceOptimizationService.swift # Performance monitoring
├── ViewModels/
│   └── MenuCaptureViewModel.swift    # Main capture flow logic
├── Views/
│   ├── MenuCaptureView.swift         # Camera capture interface
│   └── DishListView.swift            # Extracted dishes display
└── ContentView.swift                 # App entry point
```

## Key Data Models

### Core Entities

```swift
// Menu represents extracted information from a restaurant menu
struct Menu: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let dishes: [Dish]
    let restaurantName: String?
    let ocrConfidence: Float
}

// Dish contains individual menu item information
struct Dish: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let price: String?
    let category: DishCategory?
    let allergens: [String]
    let dietaryInfo: [DietaryInfo]
    let extractionConfidence: Float
}

// OCR processing results with confidence metrics
struct OCRResult {
    let id: UUID
    let recognizedText: [TextBlock]
    let processingTime: TimeInterval
    let overallConfidence: Float
    let imageSize: CGSize
}
```

### Privacy Models

```swift
// Privacy settings with compliance tracking
struct PrivacySettings {
    var dataRetentionPolicy: DataRetentionPolicy
    var analyticsEnabled: Bool // Always false by default
    var crashReportingEnabled: Bool // Always false by default
    
    enum DataRetentionPolicy: String, CaseIterable {
        case sessionOnly = "Session Only"  // Clear on app close
        case never = "Never Store"         // No persistence ever
    }
}
```

### Error Handling

```swift
// Comprehensive error types for all operations
enum MenulyError: LocalizedError, Equatable {
    // Camera Errors
    case cameraPermissionDenied
    case cameraUnavailable
    case photoCaptureFailed
    
    // OCR Errors  
    case ocrProcessingFailed
    case noTextRecognized
    case lowConfidenceOCR(Float)
    
    // Parsing Errors
    case dishExtractionFailed
    case noDishesFound
    case invalidMenuFormat
    
    // API Errors
    case networkUnavailable
    case apiRequestFailed(String)
    case invalidAPIResponse
    case apiRateLimited
    case authenticationFailed
    
    // System Errors
    case insufficientMemory
    case processingTimeout
    case unknownError(String)
}
```

## Service Architecture

### 1. CameraService
- **Purpose**: Privacy-first camera capture with AVFoundation
- **Features**: Permission management, photo optimization for OCR
- **Privacy**: No image persistence beyond session, automatic cleanup

### 2. OCRService  
- **Purpose**: On-device text extraction using Apple Vision framework
- **Features**: Accuracy optimization, confidence scoring, performance tracking
- **Privacy**: All processing on-device, no external data transfer

### 3. MenuParsingService
- **Purpose**: Extract structured dish information from OCR results
- **Features**: Smart dish detection, category classification, allergen identification
- **Privacy**: Local processing only, no data sharing

### 4. VisualizationService
- **Purpose**: Secure Claude API integration for dish visualizations
- **Features**: Minimal data transfer, secure authentication, retry logic
- **Privacy**: Only essential dish info sent, no images or personal data

### 5. PrivacyComplianceService
- **Purpose**: Enforce privacy-first policies and data protection
- **Features**: Data retention management, compliance monitoring, automatic cleanup
- **Privacy**: Ensures no data persists beyond user preferences

### 6. PerformanceOptimizationService
- **Purpose**: Memory management and performance optimization
- **Features**: Memory monitoring, image optimization, OCR tuning
- **Privacy**: Local optimization only, no usage analytics

## State Management Strategy

### MVVM with ObservableObject

```swift
@MainActor
final class MenuCaptureViewModel: ObservableObject {
    // Published state for UI binding
    @Published var currentState: AppState = .idle
    @Published var capturedImage: UIImage?
    @Published var extractedMenu: Menu?
    @Published var currentError: MenulyError?
    @Published var processingProgress: Double = 0.0
    
    // Service dependencies
    private let cameraService: CameraService
    private let ocrService: OCRService
    private let parsingService: MenuParsingService
    private let coordinator: AppCoordinator
}
```

### App State Management

```swift
enum AppState: Equatable {
    case idle
    case capturingPhoto
    case processingOCR
    case extractingDishes
    case generatingVisualization(dishName: String)
    case displayingResults
    case error(MenulyError)
}
```

## Privacy Implementation

### Core Privacy Principles

1. **On-Device Processing**: OCR and parsing happen locally using Apple Vision framework
2. **Minimal Data Transfer**: Only essential dish information sent to Claude API
3. **No Data Persistence**: User choice between "Session Only" or "Never Store"
4. **Secure Communication**: HTTPS-only with secure headers and authentication
5. **Transparent Privacy**: Clear privacy settings and data status reporting

### Privacy Compliance Features

- **Data Retention Policies**: User-configurable session-only or never-store options
- **Automatic Cleanup**: Data cleared based on user preferences and app lifecycle
- **Memory Monitoring**: Track and limit data retention across services
- **Secure API Communication**: Minimal payload with privacy-respecting headers
- **Privacy Dashboard**: Real-time data status and compliance reporting

### API Security Implementation

```swift
// Minimal API payload for visualization requests
struct VisualizationRequest: Codable {
    let dishName: String
    let description: String?
    let dietaryInfo: [String]
    let style: VisualizationStyle
    let requestId: String
}

// Privacy-respecting HTTP headers
func getSecureAPIHeaders() -> [String: String] {
    return [
        "User-Agent": "Menuly/1.0 Privacy-First",
        "DNT": "1", // Do Not Track
        "X-Privacy-Policy": "no-data-collection"
    ]
}
```

## Performance Optimization

### Memory Management

- **Automatic Memory Monitoring**: Track memory usage with configurable thresholds
- **Proactive Cleanup**: Clear caches and temporary data before memory pressure
- **Image Optimization**: Resize and optimize images for OCR processing
- **Performance Metrics**: Track processing times and resource usage

### OCR Optimization

- **Adaptive Quality**: Adjust OCR accuracy based on performance requirements
- **Image Preprocessing**: Optimize images for better text recognition
- **Confidence Filtering**: Filter low-confidence results to improve accuracy
- **Memory-Conscious Processing**: Stream processing for large images

### Performance Configuration

```swift
enum OptimizationLevel: String, CaseIterable {
    case conservative = "Conservative"  // Stability first
    case balanced = "Balanced"          // Optimal balance
    case aggressive = "Aggressive"      // Maximum performance
    
    var maxImageDimension: CGFloat {
        switch self {
        case .conservative: return 1024
        case .balanced: return 1536  
        case .aggressive: return 2048
        }
    }
}
```

## Error Handling Strategy

### Comprehensive Error Coverage
- **Camera Errors**: Permission, availability, capture failures
- **OCR Errors**: Processing failures, low confidence, no text found
- **Parsing Errors**: Invalid format, no dishes found, extraction failures
- **API Errors**: Network issues, authentication, rate limiting, server errors
- **System Errors**: Memory pressure, timeout, unknown issues

### Error Recovery
- **User-Friendly Messages**: Clear descriptions with recovery suggestions
- **Automatic Retry**: Intelligent retry logic with exponential backoff
- **Fallback Options**: Alternative approaches when primary methods fail
- **Graceful Degradation**: Maintain core functionality during partial failures

## Framework Integration

### Required Frameworks
- **SwiftUI**: Modern declarative UI framework
- **AVFoundation**: Camera capture and media processing
- **Vision**: On-device OCR and text recognition
- **Foundation**: Core data types and networking
- **UIKit**: Image processing utilities
- **OSLog**: Privacy-conscious logging

### Target Requirements
- **iOS 17.0+**: Latest SwiftUI and Vision framework features
- **Device Camera**: Required for menu photo capture
- **Network Access**: Required for Claude API visualization requests

## Implementation Recommendations

### Phase 1: Core MVP
1. Implement basic camera capture and OCR pipeline
2. Create menu parsing service with dish extraction
3. Add privacy compliance service and data management
4. Build essential SwiftUI views and navigation

### Phase 2: Enhanced Features
1. Integrate Claude API for dish visualizations
2. Add performance optimization and memory management
3. Implement comprehensive error handling and recovery
4. Add privacy dashboard and settings

### Phase 3: Polish & Optimization
1. Performance tuning and memory optimization
2. Enhanced OCR accuracy with preprocessing
3. Advanced dish categorization and parsing
4. Accessibility improvements and localization

### Code Quality Standards
- **SwiftUI Best Practices**: Use of proper state management and view composition
- **Memory Management**: Proper use of weak references and cleanup
- **Error Handling**: Comprehensive Result types and throwing functions
- **Privacy by Design**: Built-in privacy protection at every level
- **Performance Monitoring**: Real-time performance tracking and optimization

This architecture provides a solid foundation for building a privacy-first, high-performance menu visualization app that leverages the best of iOS frameworks while maintaining user trust and data protection.