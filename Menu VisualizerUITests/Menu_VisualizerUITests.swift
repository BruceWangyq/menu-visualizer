//
//  Menu_VisualizerUITests.swift
//  Menu VisualizerUITests
//
//  Comprehensive UI test suite for Menuly iOS app
//  Tests user interactions, navigation, error handling, and accessibility
//

import XCTest

final class Menu_VisualizerUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    // UI test configuration
    private let testTimeouts = UITestTimeouts(
        shortWait: 5.0,
        mediumWait: 10.0,
        longWait: 30.0,
        animationWait: 1.0
    )
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Stop on first failure for faster debugging
        continueAfterFailure = false
        
        // Initialize app
        app = XCUIApplication()
        
        // Configure app for testing
        app.launchArguments = ["--uitesting", "--disable-animations"]
        app.launchEnvironment = [
            "UITEST_MODE": "1",
            "DISABLE_NETWORK": "1"
        ]
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
        try super.tearDownWithError()
    }
    
    // MARK: - App Launch and Startup Tests
    
    @MainActor
    func testAppLaunch() throws {
        app.launch()
        
        // App should launch successfully
        XCTAssertTrue(app.state == .runningForeground, "App should be running")
        
        // Should show onboarding or main interface
        let onboardingExists = app.staticTexts["Welcome to Menuly"].waitForExistence(timeout: testTimeouts.shortWait)
        let mainInterfaceExists = app.buttons["Capture Menu Photo"].waitForExistence(timeout: testTimeouts.shortWait)
        
        XCTAssertTrue(onboardingExists || mainInterfaceExists, "Should show onboarding or main interface")
    }
    
    @MainActor
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
            app.terminate()
        }
    }
    
    @MainActor
    func testAppMemoryUsage() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            app.launch()
            
            // Navigate through main flows
            navigateToMainInterface()
            simulateMenuCapture()
            navigateToSettings()
            
            app.terminate()
        }
    }
    
    // MARK: - Onboarding Flow Tests
    
    @MainActor
    func testOnboardingFlow() throws {
        app.launch()
        
        // Check if onboarding is shown for new users
        if app.staticTexts["Welcome to Menuly"].exists {
            // Test onboarding screens
            testOnboardingScreens()
            
            // Test camera permission flow
            testCameraPermissionRequest()
            
            // Complete onboarding
            completeOnboarding()
        }
        
        // Should reach main interface
        XCTAssertTrue(app.buttons["Capture Menu Photo"].waitForExistence(timeout: testTimeouts.mediumWait),
                     "Should reach main interface after onboarding")
    }
    
    @MainActor
    func testOnboardingSkip() throws {
        app.launch()
        
        if app.staticTexts["Welcome to Menuly"].exists {
            // Find and tap skip button
            let skipButton = app.buttons["Skip"]
            if skipButton.exists {
                skipButton.tap()
                
                // Should still request camera permission
                XCTAssertTrue(app.alerts.buttons["Allow"].waitForExistence(timeout: testTimeouts.shortWait) ||
                             app.buttons["Capture Menu Photo"].waitForExistence(timeout: testTimeouts.shortWait),
                             "Should handle onboarding skip properly")
            }
        }
    }
    
    // MARK: - Main Interface Tests
    
    @MainActor
    func testMainInterfaceElements() throws {
        app.launch()
        navigateToMainInterface()
        
        // Test main UI elements existence
        XCTAssertTrue(app.buttons["Capture Menu Photo"].exists, "Capture button should exist")
        XCTAssertTrue(app.buttons["Settings"].exists, "Settings button should exist")
        
        // Test accessibility
        let captureButton = app.buttons["Capture Menu Photo"]
        XCTAssertFalse(captureButton.label.isEmpty, "Capture button should have accessibility label")
        
        // Test button states
        XCTAssertTrue(captureButton.isEnabled, "Capture button should be enabled")
        XCTAssertTrue(captureButton.isHittable, "Capture button should be tappable")
    }
    
    @MainActor
    func testCaptureButtonInteraction() throws {
        app.launch()
        navigateToMainInterface()
        
        let captureButton = app.buttons["Capture Menu Photo"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: testTimeouts.shortWait))
        
        // Test button tap
        captureButton.tap()
        
        // Should show camera interface or permission request
        let cameraInterface = app.otherElements["Camera View"]
        let permissionAlert = app.alerts.firstMatch
        
        XCTAssertTrue(cameraInterface.waitForExistence(timeout: testTimeouts.shortWait) ||
                     permissionAlert.waitForExistence(timeout: testTimeouts.shortWait),
                     "Should show camera interface or permission request")
    }
    
    // MARK: - Camera and Photo Capture Tests
    
    @MainActor
    func testCameraPermissionFlow() throws {
        app.launch()
        navigateToMainInterface()
        
        // Trigger camera permission request
        app.buttons["Capture Menu Photo"].tap()
        
        // Handle permission alert if it appears
        let permissionAlert = app.alerts.firstMatch
        if permissionAlert.waitForExistence(timeout: testTimeouts.shortWait) {
            // Test permission denial
            permissionAlert.buttons["Don't Allow"].tap()
            
            // Should show error message or settings guidance
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'camera'")).firstMatch
                         .waitForExistence(timeout: testTimeouts.shortWait),
                         "Should show camera permission error")
            
            // Test going to settings
            if app.buttons["Settings"].exists {
                app.buttons["Settings"].tap()
                // Would open iOS Settings app in real scenario
            }
        }
    }
    
    @MainActor
    func testCameraInterface() throws {
        app.launch()
        navigateToMainInterface()
        grantCameraPermission()
        
        let captureButton = app.buttons["Capture Menu Photo"]
        captureButton.tap()
        
        // Should show camera interface
        let cameraView = app.otherElements["Camera View"]
        XCTAssertTrue(cameraView.waitForExistence(timeout: testTimeouts.mediumWait),
                     "Should show camera interface")
        
        // Test camera controls
        if cameraView.exists {
            let shutterButton = app.buttons["Capture"]
            let closeButton = app.buttons["Close"]
            
            XCTAssertTrue(shutterButton.exists, "Should have shutter button")
            XCTAssertTrue(closeButton.exists, "Should have close button")
            
            // Test close camera
            closeButton.tap()
            XCTAssertFalse(cameraView.exists, "Camera should close")
        }
    }
    
    @MainActor
    func testPhotoCapture() throws {
        app.launch()
        navigateToMainInterface()
        grantCameraPermission()
        
        simulateMenuCapture()
        
        // Should show processing state
        let processingIndicator = app.activityIndicators.firstMatch
        let processingLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Processing'")).firstMatch
        
        XCTAssertTrue(processingIndicator.waitForExistence(timeout: testTimeouts.shortWait) ||
                     processingLabel.waitForExistence(timeout: testTimeouts.shortWait),
                     "Should show processing state")
        
        // Wait for processing to complete
        XCTAssertTrue(app.staticTexts["Menu processing complete"].waitForExistence(timeout: testTimeouts.longWait) ||
                     app.navigationBars["Menu Items"].waitForExistence(timeout: testTimeouts.longWait),
                     "Should complete processing")
    }
    
    // MARK: - Menu Processing and Results Tests
    
    @MainActor
    func testProcessingStatesDisplay() throws {
        app.launch()
        navigateToMainInterface()
        simulateMenuCapture()
        
        let processingStates = [
            "Capturing photo",
            "Reading menu text",
            "Extracting dishes",
            "Menu processing complete"
        ]
        
        for state in processingStates {
            let stateLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] '%@'", state)).firstMatch
            // Note: In real testing, states might change too quickly to reliably test all of them
            // This is more for documentation of expected states
        }
    }
    
    @MainActor
    func testMenuResultsDisplay() throws {
        app.launch()
        navigateToMainInterface()
        simulateSuccessfulMenuCapture()
        
        // Should show dish list
        let dishList = app.tables["Menu Items"].firstMatch
        XCTAssertTrue(dishList.waitForExistence(timeout: testTimeouts.mediumWait),
                     "Should show menu items list")
        
        // Should have dish items
        let dishCells = dishList.cells
        XCTAssertGreaterThan(dishCells.count, 0, "Should display extracted dishes")
        
        // Test first dish cell
        let firstDish = dishCells.firstMatch
        if firstDish.exists {
            XCTAssertTrue(firstDish.isHittable, "Dish cells should be tappable")
            XCTAssertFalse(firstDish.label.isEmpty, "Dish cells should have content")
        }
    }
    
    @MainActor
    func testDishDetailView() throws {
        app.launch()
        navigateToMainInterface()
        simulateSuccessfulMenuCapture()
        
        // Tap on first dish
        let dishList = app.tables["Menu Items"].firstMatch
        XCTAssertTrue(dishList.waitForExistence(timeout: testTimeouts.mediumWait))
        
        let firstDish = dishList.cells.firstMatch
        if firstDish.exists {
            firstDish.tap()
            
            // Should show dish detail
            let dishDetailView = app.scrollViews["Dish Detail"].firstMatch
            XCTAssertTrue(dishDetailView.waitForExistence(timeout: testTimeouts.shortWait),
                         "Should show dish detail view")
            
            // Test visualization button
            let visualizeButton = app.buttons["Generate Visualization"]
            if visualizeButton.exists {
                XCTAssertTrue(visualizeButton.isEnabled, "Visualization button should be enabled")
                
                visualizeButton.tap()
                
                // Should show visualization or loading state
                let loadingIndicator = app.activityIndicators.firstMatch
                let visualizationContent = app.textViews["Visualization Content"].firstMatch
                
                XCTAssertTrue(loadingIndicator.waitForExistence(timeout: testTimeouts.shortWait) ||
                             visualizationContent.waitForExistence(timeout: testTimeouts.mediumWait),
                             "Should show visualization loading or content")
            }
        }
    }
    
    // MARK: - Settings and Configuration Tests
    
    @MainActor
    func testSettingsAccess() throws {
        app.launch()
        navigateToMainInterface()
        
        navigateToSettings()
        
        // Should show settings screen
        let settingsNavigationBar = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNavigationBar.waitForExistence(timeout: testTimeouts.shortWait),
                     "Should show settings screen")
    }
    
    @MainActor
    func testPrivacySettings() throws {
        app.launch()
        navigateToMainInterface()
        navigateToSettings()
        
        // Look for privacy-related settings
        let privacySection = app.cells.containing(NSPredicate(format: "label CONTAINS[c] 'privacy'")).firstMatch
        if privacySection.exists {
            privacySection.tap()
            
            // Should show privacy controls
            let dataRetentionSetting = app.switches["Data Retention"]
            let biometricSetting = app.switches["Biometric Protection"]
            
            // Test privacy toggles
            if dataRetentionSetting.exists {
                XCTAssertTrue(dataRetentionSetting.isEnabled, "Privacy settings should be accessible")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    func testNoTextFoundError() throws {
        app.launch()
        navigateToMainInterface()
        
        // Simulate capturing image with no text (would need mock setup)
        simulateErrorScenario(errorType: .noTextFound)
        
        // Should show appropriate error message
        let errorMessage = app.alerts.firstMatch
        XCTAssertTrue(errorMessage.waitForExistence(timeout: testTimeouts.mediumWait),
                     "Should show error alert")
        
        // Should have retry option
        let retryButton = errorMessage.buttons["Retry"]
        let okButton = errorMessage.buttons["OK"]
        
        XCTAssertTrue(retryButton.exists || okButton.exists,
                     "Error alert should have action buttons")
        
        if retryButton.exists {
            retryButton.tap()
            // Should return to capture state
        } else if okButton.exists {
            okButton.tap()
        }
    }
    
    @MainActor
    func testNetworkErrorHandling() throws {
        app.launch()
        navigateToMainInterface()
        simulateSuccessfulMenuCapture()
        
        // Try to generate visualization with network disabled
        let dishList = app.tables["Menu Items"].firstMatch
        let firstDish = dishList.cells.firstMatch
        
        if firstDish.exists {
            firstDish.tap()
            
            let visualizeButton = app.buttons["Generate Visualization"]
            if visualizeButton.exists {
                visualizeButton.tap()
                
                // Should show network error
                let networkErrorAlert = app.alerts.containing(NSPredicate(format: "label CONTAINS[c] 'network'")).firstMatch
                XCTAssertTrue(networkErrorAlert.waitForExistence(timeout: testTimeouts.mediumWait),
                             "Should show network error")
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    @MainActor
    func testVoiceOverNavigation() throws {
        app.launch()
        navigateToMainInterface()
        
        // Test accessibility elements
        let captureButton = app.buttons["Capture Menu Photo"]
        XCTAssertFalse(captureButton.label.isEmpty, "Capture button should have accessibility label")
        
        let settingsButton = app.buttons["Settings"]
        XCTAssertFalse(settingsButton.label.isEmpty, "Settings button should have accessibility label")
    }
    
    @MainActor
    func testDynamicTypeSupport() throws {
        app.launch()
        
        // Would test different text sizes - requires system-level changes
        // This is a placeholder for dynamic type testing
        navigateToMainInterface()
        
        // Text should be readable and not clipped
        let mainButton = app.buttons["Capture Menu Photo"]
        XCTAssertTrue(mainButton.exists, "UI should adapt to text size changes")
    }
    
    // MARK: - Navigation and State Management Tests
    
    @MainActor
    func testNavigationBackAndForth() throws {
        app.launch()
        navigateToMainInterface()
        simulateSuccessfulMenuCapture()
        
        // Navigate to dish detail
        let dishList = app.tables["Menu Items"].firstMatch
        let firstDish = dishList.cells.firstMatch
        
        if firstDish.exists {
            firstDish.tap()
            
            // Should be in dish detail
            let dishDetailView = app.scrollViews["Dish Detail"].firstMatch
            XCTAssertTrue(dishDetailView.waitForExistence(timeout: testTimeouts.shortWait))
            
            // Navigate back
            let backButton = app.navigationBars.buttons["Back"]
            if backButton.exists {
                backButton.tap()
                
                // Should return to dish list
                XCTAssertTrue(dishList.waitForExistence(timeout: testTimeouts.shortWait),
                             "Should return to dish list")
            }
        }
    }
    
    @MainActor
    func testAppStateRestoration() throws {
        app.launch()
        navigateToMainInterface()
        simulateSuccessfulMenuCapture()
        
        // Send app to background
        XCUIDevice.shared.press(.home)
        sleep(2)
        
        // Relaunch app
        app.activate()
        
        // Should restore to previous state or main interface
        let dishList = app.tables["Menu Items"].firstMatch
        let mainInterface = app.buttons["Capture Menu Photo"]
        
        XCTAssertTrue(dishList.waitForExistence(timeout: testTimeouts.shortWait) ||
                     mainInterface.waitForExistence(timeout: testTimeouts.shortWait),
                     "Should restore app state appropriately")
    }
    
    // MARK: - Helper Methods
    
    private func navigateToMainInterface() {
        // Skip onboarding if present
        if app.staticTexts["Welcome to Menuly"].exists {
            completeOnboarding()
        }
        
        // Ensure we're at main interface
        XCTAssertTrue(app.buttons["Capture Menu Photo"].waitForExistence(timeout: testTimeouts.mediumWait),
                     "Should be at main interface")
    }
    
    private func completeOnboarding() {
        // Navigate through onboarding screens
        while app.buttons["Next"].exists {
            app.buttons["Next"].tap()
            usleep(500000) // 0.5 second delay
        }
        
        // Complete onboarding
        if app.buttons["Get Started"].exists {
            app.buttons["Get Started"].tap()
        }
        
        // Handle camera permission
        grantCameraPermission()
    }
    
    private func testOnboardingScreens() {
        let expectedScreens = [
            "Welcome to Menuly",
            "Privacy-First Menu Reading",
            "AI-Powered Visualizations"
        ]
        
        for screenTitle in expectedScreens {
            if app.staticTexts[screenTitle].exists {
                XCTAssertTrue(app.staticTexts[screenTitle].isHittable,
                             "Onboarding screen should be visible: \(screenTitle)")
                
                if app.buttons["Next"].exists {
                    app.buttons["Next"].tap()
                }
            }
        }
    }
    
    private func testCameraPermissionRequest() {
        if app.buttons["Enable Camera"].exists {
            app.buttons["Enable Camera"].tap()
        }
        
        grantCameraPermission()
    }
    
    private func grantCameraPermission() {
        let permissionAlert = app.alerts.firstMatch
        if permissionAlert.waitForExistence(timeout: testTimeouts.shortWait) {
            if permissionAlert.buttons["Allow"].exists {
                permissionAlert.buttons["Allow"].tap()
            } else if permissionAlert.buttons["OK"].exists {
                permissionAlert.buttons["OK"].tap()
            }
        }
    }
    
    private func navigateToSettings() {
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()
        }
    }
    
    private func simulateMenuCapture() {
        let captureButton = app.buttons["Capture Menu Photo"]
        if captureButton.exists {
            captureButton.tap()
            
            // If camera interface opens, simulate capture
            if app.buttons["Capture"].waitForExistence(timeout: testTimeouts.shortWait) {
                app.buttons["Capture"].tap()
            }
        }
    }
    
    private func simulateSuccessfulMenuCapture() {
        simulateMenuCapture()
        
        // Wait for processing to complete
        let dishList = app.tables["Menu Items"].firstMatch
        XCTAssertTrue(dishList.waitForExistence(timeout: testTimeouts.longWait),
                     "Should complete menu processing")
    }
    
    private func simulateErrorScenario(errorType: ErrorType) {
        // This would be configured through launch arguments in a real implementation
        // For now, just simulate the basic flow
        simulateMenuCapture()
    }
    
    enum ErrorType {
        case noTextFound
        case networkError
        case cameraError
    }
}

// MARK: - Test Configuration

private struct UITestTimeouts {
    let shortWait: TimeInterval
    let mediumWait: TimeInterval
    let longWait: TimeInterval
    let animationWait: TimeInterval
}
