//
//  PrivacyControlsView.swift
//  Menu Visualizer
//
//  Native iOS privacy controls interface with system integration
//

import SwiftUI
import LocalAuthentication

/// Comprehensive privacy controls view with native iOS design patterns
struct PrivacyControlsView: View {
    @StateObject private var privacySettings = PrivacySettingsService()
    @StateObject private var privacyCompliance = PrivacyComplianceService.create()
    @StateObject private var consentManager = ConsentManager()
    
    @State private var showingBiometricAuth = false
    @State private var showingSystemSettings = false
    @State private var showingPrivacyPolicy = false
    @State private var showingDataDeletion = false
    @State private var healthReport: SettingsHealthReport?
    
    var body: some View {
        NavigationStack {
            List {
                privacyStatusSection
                dataProtectionSection
                consentSection
                systemIntegrationSection
                advancedSection
                diagnosticsSection
            }
            .navigationTitle("Privacy & Security")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshPrivacyStatus()
            }
            .task {
                await loadPrivacyData()
            }
            .sheet(isPresented: $showingSystemSettings) {
                SystemPrivacySettingsView()
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .alert("Biometric Authentication", isPresented: $showingBiometricAuth) {
                Button("Enable") {
                    Task { await enableBiometricProtection() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Use Face ID or Touch ID to protect your privacy settings and sensitive data.")
            }
            .alert("Delete All Data", isPresented: $showingDataDeletion) {
                Button("Delete", role: .destructive) {
                    Task { await deleteAllData() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all app data including menu history and preferences. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Privacy Status Section
    
    @ViewBuilder
    private var privacyStatusSection: some View {
        Section {
            privacyScoreCard
            
            if let report = healthReport {
                PrivacyHealthView(report: report)
            }
        } header: {
            Label("Privacy Status", systemImage: "shield.checkerboard")
        }
    }
    
    @ViewBuilder
    private var privacyScoreCard: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Compliance Score")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(Int(privacyCompliance.complianceScore * 100))%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(complianceScoreColor)
                
                Text(complianceLevel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: privacyCompliance.complianceScore)
                    .stroke(complianceScoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: privacyCompliance.complianceScore)
                
                Image(systemName: "shield.fill")
                    .foregroundColor(complianceScoreColor)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var complianceScoreColor: Color {
        switch privacyCompliance.complianceScore {
        case 0.9...1.0: return .green
        case 0.7..<0.9: return .blue
        case 0.5..<0.7: return .orange
        default: return .red
        }
    }
    
    private var complianceLevel: String {
        switch privacyCompliance.complianceScore {
        case 0.9...1.0: return "Excellent Protection"
        case 0.7..<0.9: return "Good Protection"
        case 0.5..<0.7: return "Basic Protection"
        default: return "Needs Improvement"
        }
    }
    
    // MARK: - Data Protection Section
    
    @ViewBuilder
    private var dataProtectionSection: some View {
        Section {
            // Data Retention Policy
            Picker("Data Retention", selection: Binding(
                get: { privacySettings.currentSettings.dataRetentionPolicy },
                set: { newValue in
                    Task {
                        var newSettings = privacySettings.currentSettings
                        newSettings.dataRetentionPolicy = newValue
                        await privacySettings.updateSettings(newSettings)
                    }
                }
            )) {
                ForEach(PrivacySettings.DataRetentionPolicy.allCases, id: \.self) { policy in
                    VStack(alignment: .leading) {
                        Text(policy.rawValue)
                        Text(policy.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(policy)
                }
            }
            .pickerStyle(.menu)
            
            // Biometric Protection
            Toggle(isOn: Binding(
                get: { privacySettings.currentSettings.enableBiometricProtection },
                set: { newValue in
                    if newValue {
                        showingBiometricAuth = true
                    } else {
                        Task {
                            var newSettings = privacySettings.currentSettings
                            newSettings.enableBiometricProtection = false
                            await privacySettings.updateSettings(newSettings)
                        }
                    }
                }
            )) {
                Label("Biometric Protection", systemImage: "faceid")
            }
            .disabled(!deviceSupportsBiometrics())
            
            // Screenshot Protection
            Toggle(isOn: Binding(
                get: { privacySettings.currentSettings.enableScreenshotProtection },
                set: { newValue in
                    Task {
                        var newSettings = privacySettings.currentSettings
                        newSettings.enableScreenshotProtection = newValue
                        await privacySettings.updateSettings(newSettings)
                    }
                }
            )) {
                Label("Screenshot Protection", systemImage: "camera.viewfinder")
            }
            
            // Network Protection
            Toggle(isOn: Binding(
                get: { privacySettings.currentSettings.enableNetworkProtection },
                set: { newValue in
                    Task {
                        var newSettings = privacySettings.currentSettings
                        newSettings.enableNetworkProtection = newValue
                        await privacySettings.updateSettings(newSettings)
                    }
                }
            )) {
                Label("Network Protection", systemImage: "network")
            }
            
        } header: {
            Label("Data Protection", systemImage: "lock.shield")
        } footer: {
            Text("These settings control how your data is protected using iOS security features.")
                .font(.caption)
        }
    }
    
    // MARK: - Consent Section
    
    @ViewBuilder
    private var consentSection: some View {
        Section {
            // Data Processing Consent
            ConsentToggleView(
                title: "Menu Processing",
                description: "Allow processing of menu photos to generate dish visualizations",
                category: .dataProcessing,
                consentManager: consentManager
            )
            
            // API Communication Consent
            ConsentToggleView(
                title: "AI Visualization",
                description: "Allow communication with AI service to create visualizations",
                category: .apiCommunication,
                consentManager: consentManager
            )
            
            // Error Reporting Consent
            ConsentToggleView(
                title: "Error Reporting",
                description: "Allow anonymous error reporting to improve the app",
                category: .errorReporting,
                consentManager: consentManager
            )
            
            // Consent Management
            Button("Manage All Consent") {
                // Navigate to detailed consent management
            }
            .foregroundColor(.blue)
            
            Button("Withdraw All Consent") {
                consentManager.withdrawAllConsent()
            }
            .foregroundColor(.red)
            
        } header: {
            Label("Data Processing Consent", systemImage: "hand.raised")
        } footer: {
            Text("You can change these permissions at any time. Essential features require data processing consent.")
                .font(.caption)
        }
    }
    
    // MARK: - System Integration Section
    
    @ViewBuilder
    private var systemIntegrationSection: some View {
        Section {
            HStack {
                Label("System Integration", systemImage: "gear")
                Spacer()
                Text(privacySettings.systemSettingsStatus.description)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            Button("Open iOS Settings") {
                showingSystemSettings = true
            }
            
            Button("Privacy Policy") {
                showingPrivacyPolicy = true
            }
            
        } header: {
            Label("System Integration", systemImage: "iphone")
        }
    }
    
    // MARK: - Advanced Section
    
    @ViewBuilder
    private var advancedSection: some View {
        Section {
            // Auto-delete temporary files
            Toggle(isOn: Binding(
                get: { privacySettings.currentSettings.autoDeleteTemporaryFiles },
                set: { newValue in
                    Task {
                        var newSettings = privacySettings.currentSettings
                        newSettings.autoDeleteTemporaryFiles = newValue
                        await privacySettings.updateSettings(newSettings)
                    }
                }
            )) {
                Label("Auto-Delete Temp Files", systemImage: "trash.fill")
            }
            
            // Require consent for API
            Toggle(isOn: Binding(
                get: { privacySettings.currentSettings.requireConsentForAPI },
                set: { newValue in
                    Task {
                        var newSettings = privacySettings.currentSettings
                        newSettings.requireConsentForAPI = newValue
                        await privacySettings.updateSettings(newSettings)
                    }
                }
            )) {
                Label("Require API Consent", systemImage: "checkmark.shield")
            }
            
            // Export Settings
            Button("Export Privacy Settings") {
                exportPrivacySettings()
            }
            
            // Reset to Defaults
            Button("Reset to Defaults") {
                Task {
                    await privacySettings.resetToDefaults()
                }
            }
            .foregroundColor(.orange)
            
        } header: {
            Label("Advanced", systemImage: "gear.badge")
        }
    }
    
    // MARK: - Diagnostics Section
    
    @ViewBuilder
    private var diagnosticsSection: some View {
        Section {
            NavigationLink("Privacy Report") {
                PrivacyReportView()
            }
            
            NavigationLink("Security Audit") {
                SecurityAuditView()
            }
            
            Button("Clear All Data") {
                showingDataDeletion = true
            }
            .foregroundColor(.red)
            
        } header: {
            Label("Diagnostics", systemImage: "chart.bar.doc.horizontal")
        } footer: {
            Text("Use these tools to monitor and manage your privacy and security status.")
                .font(.caption)
        }
    }
    
    // MARK: - Helper Methods
    
    private func deviceSupportsBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    private func loadPrivacyData() async {
        healthReport = privacySettings.validateCurrentSettings()
    }
    
    private func refreshPrivacyStatus() async {
        await loadPrivacyData()
        // Refresh compliance service
        await privacyCompliance.calculateComplianceScore()
    }
    
    private func enableBiometricProtection() async {
        let context = LAContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Enable biometric protection for Menuly"
            )
            
            if success {
                var newSettings = privacySettings.currentSettings
                newSettings.enableBiometricProtection = true
                await privacySettings.updateSettings(newSettings)
            }
        } catch {
            // Handle biometric authentication error
            print("Biometric authentication failed: \(error)")
        }
    }
    
    private func exportPrivacySettings() {
        guard let data = privacySettings.exportSettings() else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [data],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func deleteAllData() async {
        privacyCompliance.clearAllDataImmediately()
        await privacySettings.resetToDefaults()
        consentManager.withdrawAllConsent()
    }
}

// MARK: - Consent Toggle View

struct ConsentToggleView: View {
    let title: String
    let description: String
    let category: ConsentCategory
    @ObservedObject var consentManager: ConsentManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.body)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { consentManager.isConsentGranted(for: category) },
                    set: { newValue in
                        consentManager.updateConsent(for: category, granted: newValue)
                    }
                ))
            }
            
            if category.isEssential {
                Text("Required for core functionality")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Privacy Health View

struct PrivacyHealthView: View {
    let report: SettingsHealthReport
    @State private var showingDetails = false
    
    var body: some View {
        Button {
            showingDetails = true
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text("Privacy Health")
                        .font(.headline)
                    Text(report.healthLevel.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack {
                    Text(report.healthLevel.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(report.healthLevel.color.opacity(0.2))
                        .foregroundColor(report.healthLevel.color)
                        .cornerRadius(8)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetails) {
            PrivacyHealthDetailView(report: report)
        }
    }
}

// MARK: - Extensions

extension SystemSettingsStatus {
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .aligned: return "Aligned"
        case .partiallyAligned: return "Partially Aligned"
        case .misaligned: return "Misaligned"
        }
    }
}

extension LAContext {
    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            evaluatePolicy(policy, localizedReason: localizedReason) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
}

// MARK: - Placeholder Views

struct SystemPrivacySettingsView: View {
    var body: some View {
        Text("System Privacy Settings")
    }
}

struct PrivacyReportView: View {
    var body: some View {
        Text("Privacy Report")
    }
}

struct SecurityAuditView: View {
    var body: some View {
        Text("Security Audit")
    }
}

#Preview {
    PrivacyControlsView()
}