//
//  AIServiceConfigurationView.swift
//  Menu Visualizer
//
//  AI service configuration and API key management interface
//

import SwiftUI

/// Configuration view for AI service settings and API key management
struct AIServiceConfigurationView: View {
    @StateObject private var viewModel = AIConfigurationViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Header section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text("AI Menu Analysis")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Enhanced accuracy with Gemini 1.5 Flash")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Service status indicator
                        HStack {
                            Circle()
                                .fill(viewModel.hasValidAPIKey ? .green : .red)
                                .frame(width: 8, height: 8)
                            
                            Text(viewModel.hasValidAPIKey ? "AI Service Active" : "API Key Required")
                                .font(.caption)
                                .foregroundColor(viewModel.hasValidAPIKey ? .green : .red)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // API Key Configuration
                Section("API Configuration") {
                    VStack(alignment: .leading, spacing: 16) {
                        // API Key input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gemini API Key")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            SecureField("Enter your Gemini API key", text: $viewModel.apiKeyInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .onChange(of: viewModel.apiKeyInput) { _ in
                                    viewModel.validateAPIKey()
                                }
                            
                            if viewModel.showAPIKeyValidation {
                                HStack {
                                    Image(systemName: viewModel.isAPIKeyValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(viewModel.isAPIKeyValid ? .green : .orange)
                                    
                                    Text(viewModel.apiKeyValidationMessage)
                                        .font(.caption)
                                        .foregroundColor(viewModel.isAPIKeyValid ? .green : .orange)
                                }
                            }
                        }
                        
                        // Save/Remove buttons
                        HStack(spacing: 12) {
                            Button("Save Key") {
                                Task {
                                    await viewModel.saveAPIKey()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!viewModel.canSaveAPIKey)
                            
                            if viewModel.hasValidAPIKey {
                                Button("Remove Key") {
                                    viewModel.showRemoveConfirmation = true
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Processing Quality
                Section("Processing Quality") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(ProcessingQualityOption.allCases, id: \.self) { option in
                            HStack {
                                Button {
                                    viewModel.selectedQuality = option
                                } label: {
                                    HStack {
                                        Image(systemName: viewModel.selectedQuality == option ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(.blue)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.title)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            
                                            Text(option.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if option == .highQuality {
                                            Text("Slower")
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.2))
                                                .foregroundColor(.orange)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(!viewModel.hasValidAPIKey)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Performance Information
                Section("Performance Information") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("Processing Speed")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("AI-powered menu analysis")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quality Settings:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Group {
                                Text("• Fast: ~3-5 seconds per menu")
                                Text("• Balanced: ~5-8 seconds per menu")
                                Text("• High Quality: ~8-12 seconds per menu")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("No more slow OCR processing")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Setup Instructions
                Section("Setup Instructions") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to get your API key:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Text("1.")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                
                                Text("Visit Google AI Studio")
                                
                                Spacer()
                                
                                Button("Open") {
                                    if let url = URL(string: "https://makersuite.google.com/app/apikey") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                            
                            HStack(alignment: .top) {
                                Text("2.")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                
                                Text("Sign in with your Google account")
                            }
                            
                            HStack(alignment: .top) {
                                Text("3.")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                
                                Text("Click 'Create API key'")
                            }
                            
                            HStack(alignment: .top) {
                                Text("4.")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                
                                Text("Copy the key and paste it above")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("AI Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Remove API Key", isPresented: $viewModel.showRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                viewModel.removeAPIKey()
            }
        } message: {
            Text("Are you sure you want to remove your Gemini API key? This will disable AI menu analysis.")
        }
        .alert("API Key Status", isPresented: $viewModel.showAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

// MARK: - Processing Quality Options

enum ProcessingQualityOption: String, CaseIterable {
    case fast = "fast"
    case balanced = "balanced"
    case highQuality = "highQuality"
    
    var title: String {
        switch self {
        case .fast:
            return "Fast"
        case .balanced:
            return "Balanced (Recommended)"
        case .highQuality:
            return "High Quality"
        }
    }
    
    var description: String {
        switch self {
        case .fast:
            return "Quick AI analysis with basic optimization. Best for simple menus."
        case .balanced:
            return "Balanced speed and accuracy. Ideal for most menu types."
        case .highQuality:
            return "Maximum accuracy with detailed analysis. Best for complex or hard-to-read menus."
        }
    }
    
    func toProcessingQuality() -> MenuCaptureViewModel.ProcessingQuality {
        switch self {
        case .fast:
            return .fast
        case .balanced:
            return .balanced
        case .highQuality:
            return .highQuality
        }
    }
}

// MARK: - View Model

@MainActor
class AIConfigurationViewModel: ObservableObject {
    @Published var apiKeyInput: String = ""
    @Published var hasValidAPIKey: Bool = false
    @Published var isAPIKeyValid: Bool = false
    @Published var showAPIKeyValidation: Bool = false
    @Published var canSaveAPIKey: Bool = false
    @Published var selectedQuality: ProcessingQualityOption = .balanced
    @Published var showAlert: Bool = false
    @Published var showRemoveConfirmation: Bool = false
    @Published var alertMessage: String = ""
    
    private let apiKeyManager = APIKeyManager.shared
    
    var apiKeyValidationMessage: String {
        if apiKeyInput.isEmpty {
            return ""
        } else if isAPIKeyValid {
            return "Valid API key format"
        } else {
            return "Invalid API key format"
        }
    }
    
    init() {
        updateAPIKeyStatus()
        loadSavedSettings()
    }
    
    func validateAPIKey() {
        showAPIKeyValidation = !apiKeyInput.isEmpty
        
        // Basic format validation
        isAPIKeyValid = !apiKeyInput.isEmpty && 
                       apiKeyInput.count >= 20 && 
                       apiKeyInput.count <= 256 &&
                       apiKeyInput.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        
        canSaveAPIKey = isAPIKeyValid
    }
    
    func saveAPIKey() async {
        guard isAPIKeyValid else { return }
        
        let result = apiKeyManager.storeGeminiAPIKey(apiKeyInput)
        
        switch result {
        case .success:
            alertMessage = "API key saved securely. AI menu analysis is now enabled."
            showAlert = true
            updateAPIKeyStatus()
            apiKeyInput = "" // Clear input for security
            
        case .failure(let error):
            alertMessage = "Failed to save API key: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func removeAPIKey() {
        let result = apiKeyManager.removeGeminiAPIKey()
        
        switch result {
        case .success:
            alertMessage = "API key removed successfully. AI menu analysis is now disabled."
            showAlert = true
            updateAPIKeyStatus()
            
        case .failure(let error):
            alertMessage = "Failed to remove API key: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func updateAPIKeyStatus() {
        hasValidAPIKey = apiKeyManager.isFirebaseAIConfigured() || apiKeyManager.hasValidGeminiAPIKey()
    }
    
    private func loadSavedSettings() {
        // Load saved processing quality from UserDefaults
        if let savedQuality = UserDefaults.standard.object(forKey: "ProcessingQuality") as? String,
           let quality = ProcessingQualityOption(rawValue: savedQuality) {
            selectedQuality = quality
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(selectedQuality.rawValue, forKey: "ProcessingQuality")
    }
}

// MARK: - Preview

struct AIServiceConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        AIServiceConfigurationView()
    }
}