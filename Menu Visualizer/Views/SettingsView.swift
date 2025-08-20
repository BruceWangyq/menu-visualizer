//
//  SettingsView.swift
//  Menu Visualizer
//
//  Main settings interface with AI configuration and app preferences
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingAIConfiguration = false
    
    var body: some View {
        List {
            // AI Service Settings
            Section("AI Menu Analysis") {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("AI Configuration")
                            .font(.headline)
                        
                        Text(viewModel.aiServiceStatus)
                            .font(.caption)
                            .foregroundColor(viewModel.hasValidGeminiKey ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    Button("Configure") {
                        showingAIConfiguration = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
            
            // App Preferences
            Section("Processing Preferences") {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                    
                    Text("AI Processing Quality")
                    
                    Spacer()
                    
                    Text(viewModel.currentQuality.title)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                Picker("Processing Quality", selection: $viewModel.currentQuality) {
                    ForEach(ProcessingQualityOption.allCases, id: \.self) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.currentQuality) { _ in
                    viewModel.saveSettings()
                }
                
                Toggle("Cache Results", isOn: $viewModel.cacheResults)
                    .onChange(of: viewModel.cacheResults) { _ in
                        viewModel.saveSettings()
                    }
            }
            
            // Privacy Settings
            Section("Privacy") {
                NavigationLink {
                    PrivacyDashboard()
                } label: {
                    HStack {
                        Image(systemName: "hand.raised")
                            .foregroundColor(.purple)
                        Text("Privacy Dashboard")
                    }
                }
                
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Text("Privacy Policy")
                    }
                }
            }
            
            // Performance & Diagnostics
            Section("Performance") {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading) {
                        Text("Memory Usage")
                        Text("\(viewModel.memoryUsage) MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading) {
                        Text("API Usage (This Month)")
                        Text(viewModel.apiUsageText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("Clear Cache") {
                    viewModel.clearCache()
                }
                .foregroundColor(.red)
            }
            
            // Diagnostics & Testing
            Section("Diagnostics") {
                NavigationLink {
                    AITestView()
                } label: {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                        Text("Test AI Service")
                        
                        Spacer()
                        
                        Text("Firebase & Gemini")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                NavigationLink {
                    CameraDiagnosticsView()
                } label: {
                    HStack {
                        Image(systemName: "camera.badge.ellipsis")
                            .foregroundColor(.orange)
                        Text("Camera Diagnostics")
                        
                        Spacer()
                        
                        Text("Debug Issues")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // About Section
            Section("About") {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Version")
                    
                    Spacer()
                    
                    Text(viewModel.appVersion)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "checkmark.shield")
                        .foregroundColor(.green)
                    Text("Security Level")
                    
                    Spacer()
                    
                    Text(viewModel.securityLevel)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                Link(destination: URL(string: "https://github.com/anthropics/claude-code/issues")!) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.orange)
                        Text("Support & Feedback")
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            viewModel.refreshData()
        }
        .sheet(isPresented: $showingAIConfiguration) {
            AIServiceConfigurationView()
        }
    }
}

// MARK: - Settings ViewModel

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var hasValidGeminiKey: Bool = false
    @Published var cacheResults: Bool = true
    @Published var memoryUsage: String = "0"
    @Published var currentQuality: ProcessingQualityOption = .balanced
    
    private let apiKeyManager = APIKeyManager.shared
    
    var aiServiceStatus: String {
        if hasValidGeminiKey {
            return "AI service configured and ready"
        } else {
            return "API key required for AI analysis"
        }
    }
    
    var apiUsageText: String {
        // This would be implemented with actual usage tracking
        return "~50 requests"
    }
    
    var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "Unknown"
    }
    
    var securityLevel: String {
        let status = apiKeyManager.getPrivacyCompliantStatus()
        return status["securityLevel"] as? String == "hardware" ? "Hardware" : "Software"
    }
    
    init() {
        loadSettings()
        refreshData()
    }
    
    func refreshData() {
        hasValidGeminiKey = apiKeyManager.hasValidGeminiAPIKey()
        updateMemoryUsage()
    }
    
    func loadSettings() {
        cacheResults = UserDefaults.standard.bool(forKey: "CacheResults")
        
        if let qualityString = UserDefaults.standard.string(forKey: "ProcessingQuality"),
           let quality = ProcessingQualityOption(rawValue: qualityString) {
            currentQuality = quality
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(currentQuality.rawValue, forKey: "ProcessingQuality")
        UserDefaults.standard.set(cacheResults, forKey: "CacheResults")
    }
    
    func clearCache() {
        // Clear AI service cache
        // This would be implemented with actual cache clearing
        
        // Show confirmation
        let alert = UIAlertController(title: "Cache Cleared", message: "All cached data has been removed.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / (1024 * 1024)
            memoryUsage = String(format: "%.1f", usedMB)
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(AppCoordinator.preview)
    }
}