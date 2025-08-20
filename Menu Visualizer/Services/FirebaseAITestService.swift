//
//  FirebaseAITestService.swift
//  Menu Visualizer
//
//  Test service to verify Firebase AI configuration
//

import Foundation
import FirebaseAI
import FirebaseCore

/// Test service to verify Firebase AI Logic setup
@MainActor
final class FirebaseAITestService: ObservableObject {
    @Published var testResult: TestResult = .idle
    @Published var isRunning = false
    
    enum TestResult {
        case idle
        case running
        case success(String)
        case failure(String)
        
        var displayText: String {
            switch self {
            case .idle:
                return "Ready to test"
            case .running:
                return "Testing AI service..."
            case .success(let response):
                return "✅ Success: \(response.prefix(100))..."
            case .failure(let error):
                return "❌ Failed: \(error)"
            }
        }
        
        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
        
        var isFailure: Bool {
            if case .failure = self { return true }
            return false
        }
    }
    
    /// Test Firebase AI Logic with a simple prompt
    func testFirebaseAI() async {
        print("🧪 Starting Firebase AI Logic test...")
        
        await MainActor.run {
            isRunning = true
            testResult = .running
        }
        
        do {
            // Initialize the Gemini Developer API backend service
            let ai = FirebaseAI.firebaseAI(backend: .googleAI())
            print("✅ Firebase AI instance created")
            
            // Create a `GenerativeModel` instance with a model that supports your use case
            let model = ai.generativeModel(modelName: "gemini-2.5-flash")
            print("✅ Gemini model instance created")
            
            // Provide a simple test prompt
            let prompt = "Write a one-sentence description of a delicious pizza."
            print("📝 Sending test prompt: \(prompt)")
            
            // To generate text output, call generateContent with the text input
            let response = try await model.generateContent(prompt)
            
            if let responseText = response.text, !responseText.isEmpty {
                print("✅ AI response received: \(responseText)")
                await MainActor.run {
                    testResult = .success(responseText)
                    isRunning = false
                }
            } else {
                print("❌ Empty response from AI service")
                await MainActor.run {
                    testResult = .failure("Empty response from AI service")
                    isRunning = false
                }
            }
            
        } catch {
            print("❌ Firebase AI test failed: \(error.localizedDescription)")
            let errorMessage = mapErrorToUserMessage(error)
            await MainActor.run {
                testResult = .failure(errorMessage)
                isRunning = false
            }
        }
    }
    
    /// Test with menu analysis prompt (more realistic)
    func testMenuAnalysis() async {
        print("🍽️ Starting menu analysis test...")
        
        await MainActor.run {
            isRunning = true
            testResult = .running
        }
        
        do {
            let ai = FirebaseAI.firebaseAI(backend: .googleAI())
            let model = ai.generativeModel(modelName: "gemini-2.5-flash")
            
            let prompt = """
            Analyze this sample menu text and extract dishes in JSON format:
            
            "APPETIZERS
            Caesar Salad - $12.99
            Chicken Wings - $14.99
            
            MAIN COURSES  
            Grilled Salmon - $24.99
            Beef Steak - $28.99"
            
            Return only JSON with this structure:
            {
              "dishes": [
                {"name": "dish name", "price": "$0.00", "category": "appetizer|mainCourse"}
              ]
            }
            """
            
            let response = try await model.generateContent(prompt)
            
            if let responseText = response.text, !responseText.isEmpty {
                print("✅ Menu analysis response: \(responseText)")
                await MainActor.run {
                    testResult = .success(responseText)
                    isRunning = false
                }
            } else {
                await MainActor.run {
                    testResult = .failure("Empty response from menu analysis")
                    isRunning = false
                }
            }
            
        } catch {
            print("❌ Menu analysis test failed: \(error.localizedDescription)")
            let errorMessage = mapErrorToUserMessage(error)
            await MainActor.run {
                testResult = .failure(errorMessage)
                isRunning = false
            }
        }
    }
    
    /// Check configuration status
    func checkConfiguration() -> ConfigurationStatus {
        var status = ConfigurationStatus()
        
        // Check Firebase configuration file
        status.firebaseConfigExists = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        
        // Check API key from APIKeyManager
        status.hasAPIKey = APIKeyManager.shared.isFirebaseAIConfigured() || APIKeyManager.shared.hasValidGeminiAPIKey()
        
        // Check Firebase app configuration
        do {
            if FirebaseApp.app() != nil {
                status.firebaseInitialized = true
            }
        } catch {
            status.firebaseInitialized = false
        }
        
        return status
    }
    
    private func mapErrorToUserMessage(_ error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("api key") || errorDescription.contains("authentication") {
            return "API key issue: Check Firebase configuration or Gemini API key"
        } else if errorDescription.contains("network") || errorDescription.contains("connection") {
            return "Network issue: Check internet connection"
        } else if errorDescription.contains("quota") || errorDescription.contains("billing") {
            return "API quota exceeded: Check Firebase billing or API limits"
        } else if errorDescription.contains("model") {
            return "Model issue: Gemini 2.5 Flash model may not be available"
        } else if errorDescription.contains("firebase") {
            return "Firebase configuration issue: Check GoogleService-Info.plist"
        } else {
            return "Error: \(error.localizedDescription)"
        }
    }
}

struct ConfigurationStatus {
    var firebaseConfigExists = false
    var firebaseInitialized = false
    var hasAPIKey = false
    
    var isFullyConfigured: Bool {
        return firebaseConfigExists && hasAPIKey
    }
    
    var summary: String {
        var issues: [String] = []
        
        if !firebaseConfigExists {
            issues.append("Missing GoogleService-Info.plist")
        }
        if !hasAPIKey {
            issues.append("No API key configured")
        }
        if !firebaseInitialized {
            issues.append("Firebase not initialized")
        }
        
        if issues.isEmpty {
            return "✅ Configuration looks good"
        } else {
            return "⚠️ Issues: \(issues.joined(separator: ", "))"
        }
    }
}