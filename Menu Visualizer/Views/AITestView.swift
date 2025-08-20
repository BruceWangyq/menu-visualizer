//
//  AITestView.swift
//  Menu Visualizer
//
//  Simple view to test Firebase AI Logic configuration
//

import SwiftUI

struct AITestView: View {
    @StateObject private var testService = FirebaseAITestService()
    @State private var showingConfigDetails = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Firebase AI Logic Test")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Test your AI service configuration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Configuration Status
                ConfigurationStatusCard(testService: testService)
                
                // Test Results
                TestResultsCard(testService: testService)
                
                // Test Buttons
                VStack(spacing: 16) {
                    Button {
                        Task {
                            await testService.testFirebaseAI()
                        }
                    } label: {
                        HStack {
                            if testService.isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                            }
                            
                            Text("Run Simple Test")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(testService.isRunning ? Color.gray : Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(testService.isRunning)
                    
                    Button {
                        Task {
                            await testService.testMenuAnalysis()
                        }
                    } label: {
                        HStack {
                            if testService.isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "text.viewfinder")
                                    .font(.title3)
                            }
                            
                            Text("Test Menu Analysis")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(testService.isRunning ? Color.gray : Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(testService.isRunning)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Config") {
                        showingConfigDetails = true
                    }
                }
            }
            .sheet(isPresented: $showingConfigDetails) {
                ConfigurationDetailView(testService: testService)
            }
        }
    }
}

struct ConfigurationStatusCard: View {
    let testService: FirebaseAITestService
    
    var body: some View {
        let config = testService.checkConfiguration()
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.blue)
                Text("Configuration Status")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(
                    title: "Firebase Config File",
                    isValid: config.firebaseConfigExists,
                    icon: "doc.text"
                )
                
                StatusRow(
                    title: "API Key Available",
                    isValid: config.hasAPIKey,
                    icon: "key"
                )
                
                StatusRow(
                    title: "Firebase Initialized",
                    isValid: config.firebaseInitialized,
                    icon: "checkmark.circle"
                )
            }
            
            Text(config.summary)
                .font(.caption)
                .foregroundColor(config.isFullyConfigured ? .green : .orange)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusRow: View {
    let title: String
    let isValid: Bool
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isValid ? .green : .red)
        }
    }
}

struct TestResultsCard: View {
    @ObservedObject var testService: FirebaseAITestService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.purple)
                Text("Test Results")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(testService.testResult.displayText)
                    .font(.subheadline)
                    .foregroundColor(
                        testService.testResult.isSuccess ? .green :
                        testService.testResult.isFailure ? .red : .primary
                    )
                
                if testService.testResult.isSuccess {
                    Text("🎉 AI service is working correctly!")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if testService.testResult.isFailure {
                    Text("💡 Check configuration or try again")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ConfigurationDetailView: View {
    let testService: FirebaseAITestService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Detailed Configuration")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                let config = testService.checkConfiguration()
                let apiStatus = APIKeyManager.shared.getAIServiceAuthStatus()
                
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(title: "Firebase Config File", value: config.firebaseConfigExists ? "Found" : "Missing")
                    DetailRow(title: "Firebase Initialized", value: config.firebaseInitialized ? "Yes" : "No")
                    DetailRow(title: "Has API Key", value: config.hasAPIKey ? "Yes" : "No")
                    
                    if let firebase = apiStatus["firebaseConfigured"] as? Bool {
                        DetailRow(title: "Firebase AI Configured", value: firebase ? "Yes" : "No")
                    }
                    
                    if let gemini = apiStatus["geminiKeyStored"] as? Bool {
                        DetailRow(title: "Gemini Key Stored", value: gemini ? "Yes" : "No")
                    }
                    
                    if let preferred = apiStatus["preferredService"] as? String {
                        DetailRow(title: "Preferred Service", value: preferred.capitalized)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AITestView()
}