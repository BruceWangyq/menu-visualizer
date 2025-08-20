//
//  QuickAITest.swift
//  Menu Visualizer
//
//  Quick standalone test for Firebase AI Logic
//

import Foundation
import FirebaseAI
import FirebaseCore

/// Quick test function you can call from anywhere to test Firebase AI
func runQuickAITest() async {
    print("🧪 QUICK AI TEST STARTING...")
    print("=" * 50)
    
    do {
        // Initialize the Gemini Developer API backend service
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        print("✅ Firebase AI instance created successfully")
        
        // Create a `GenerativeModel` instance with a model that supports your use case
        let model = ai.generativeModel(modelName: "gemini-2.5-flash")
        print("✅ Gemini 2.5 Flash model instance created")
        
        // Provide a prompt that contains text
        let prompt = "Write a story about a magic backpack."
        print("📝 Sending prompt: '\(prompt)'")
        
        // To generate text output, call generateContent with the text input
        let response = try await model.generateContent(prompt)
        
        if let responseText = response.text, !responseText.isEmpty {
            print("✅ SUCCESS! AI Response received:")
            print("-" * 50)
            print(responseText)
            print("-" * 50)
            print("🎉 Firebase AI Logic is working perfectly!")
        } else {
            print("❌ FAILED: Empty response from AI service")
        }
        
    } catch {
        print("❌ FAILED: \(error.localizedDescription)")
        print("💡 Possible causes:")
        
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("api key") || errorDescription.contains("authentication") {
            print("   • Firebase API key not configured")
            print("   • Check GoogleService-Info.plist")
            print("   • Verify Firebase project has Gemini AI enabled")
        } else if errorDescription.contains("network") || errorDescription.contains("connection") {
            print("   • Network connectivity issues")
            print("   • Check internet connection")
        } else if errorDescription.contains("quota") || errorDescription.contains("billing") {
            print("   • API quota exceeded")
            print("   • Check Firebase billing settings")
        } else if errorDescription.contains("model") {
            print("   • Gemini 2.5 Flash model not available")
            print("   • Try using 'gemini-1.5-flash' instead")
        } else {
            print("   • Generic error: \(error.localizedDescription)")
        }
    }
    
    print("=" * 50)
    print("🏁 QUICK AI TEST COMPLETE")
}

/// Test specifically for menu analysis
func runMenuAnalysisTest() async {
    print("🍽️ MENU ANALYSIS TEST STARTING...")
    print("=" * 50)
    
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
        
        print("📝 Sending menu analysis prompt...")
        let response = try await model.generateContent(prompt)
        
        if let responseText = response.text, !responseText.isEmpty {
            print("✅ SUCCESS! Menu Analysis Response:")
            print("-" * 50)
            print(responseText)
            print("-" * 50)
            print("🎉 Menu analysis is working!")
        } else {
            print("❌ FAILED: Empty response from menu analysis")
        }
        
    } catch {
        print("❌ MENU ANALYSIS FAILED: \(error.localizedDescription)")
    }
    
    print("=" * 50)
    print("🏁 MENU ANALYSIS TEST COMPLETE")
}

/// Extension to repeat a character
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}