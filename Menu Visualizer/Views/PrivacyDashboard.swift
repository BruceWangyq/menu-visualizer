//
//  PrivacyDashboard.swift
//  Menu Visualizer
//
//  Privacy-first dashboard for data management and transparency
//

import SwiftUI

struct PrivacyDashboard: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var pipeline: MenuProcessingPipeline
    @AppStorage("dataRetentionPolicy") private var dataRetentionPolicy: PrivacySettings.DataRetentionPolicy = .sessionOnly
    @AppStorage("hasSeenPrivacyPolicy") private var hasSeenPrivacyPolicy: Bool = false
    @State private var showingClearDataAlert = false
    @State private var showingPrivacyPolicy = false
    
    var body: some View {
        List {
            // Privacy status section
            privacyStatusSection
            
            // Data management section
            dataManagementSection
            
            // Privacy settings section
            privacySettingsSection
            
            // Transparency section
            transparencySection
            
            // Legal section
            legalSection
        }
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.large)
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Clear", role: .destructive) {
                clearAllData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all processed menus and visualizations from this device. This action cannot be undone.")
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
    
    // MARK: - Privacy Status Section
    
    private var privacyStatusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Privacy shield icon
                HStack {
                    Image(systemName: "hand.raised.square.on.square.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Privacy Protected")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Your data stays on your device")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Privacy features
                VStack(spacing: 12) {
                    privacyFeatureRow(
                        icon: "icloud.slash",
                        title: "No Cloud Storage",
                        description: "Photos and text never leave your device",
                        isActive: true
                    )
                    
                    privacyFeatureRow(
                        icon: "eye.slash",
                        title: "Minimal API Calls",
                        description: "Only dish names sent for AI visualization",
                        isActive: true
                    )
                    
                    privacyFeatureRow(
                        icon: "timer",
                        title: "Session-Only Data",
                        description: "Data cleared when app closes",
                        isActive: dataRetentionPolicy == .sessionOnly
                    )
                    
                    privacyFeatureRow(
                        icon: "trash",
                        title: "No Persistent Storage",
                        description: "Never saved to device storage",
                        isActive: dataRetentionPolicy == .never
                    )
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Privacy Status")
        }
    }
    
    private func privacyFeatureRow(icon: String, title: String, description: String, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isActive ? .green : .gray)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
            }
        }
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        Section {
            // Current session data
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Current Session")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if pipeline.currentMenu != nil {
                        Label("Active", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("Empty", systemImage: "circle")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if let menu = pipeline.currentMenu {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• \(menu.dishes.count) dishes processed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let visualizedCount = pipeline.processedDishes.filter { $0.aiVisualization != nil }.count
                        Text("• \(visualizedCount) visualizations generated")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Processed \(timeAgo(menu.timestamp))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No menu data in current session")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Clear session data button
            Button {
                pipeline.reset()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear Session Data")
                }
                .foregroundColor(pipeline.currentMenu != nil ? .red : .gray)
            }
            .disabled(pipeline.currentMenu == nil)
            
            // Clear all data button
            Button {
                showingClearDataAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Clear All Data")
                }
                .foregroundColor(.red)
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("Session data is automatically cleared when the app is closed to protect your privacy.")
        }
    }
    
    // MARK: - Privacy Settings Section
    
    private var privacySettingsSection: some View {
        Section {
            // Data retention policy
            Picker("Data Retention", selection: $dataRetentionPolicy) {
                ForEach(PrivacySettings.DataRetentionPolicy.allCases, id: \.self) { policy in
                    VStack(alignment: .leading) {
                        Text(policy.rawValue)
                            .font(.subheadline)
                        Text(policy.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(policy)
                }
            }
            .pickerStyle(.automatic)
            
            // Privacy-first features toggle (always on for this app)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Privacy-First Mode")
                        .font(.subheadline)
                    Text("Enhanced privacy protection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: .constant(true))
                    .disabled(true)
                    .tint(.green)
            }
        } header: {
            Text("Privacy Settings")
        } footer: {
            Text("Menuly is designed with privacy-first principles. Some features are always enabled to protect your data.")
        }
    }
    
    // MARK: - Transparency Section
    
    private var transparencySection: some View {
        Section {
            // Data flow explanation
            VStack(alignment: .leading, spacing: 12) {
                Text("How Your Data Flows")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                dataFlowStep(
                    number: 1,
                    title: "Photo Capture",
                    description: "Photo stays on device, never uploaded"
                )
                
                dataFlowStep(
                    number: 2,
                    title: "Text Recognition",
                    description: "Apple Vision processes locally"
                )
                
                dataFlowStep(
                    number: 3,
                    title: "Menu Parsing",
                    description: "Text analysis happens on device"
                )
                
                dataFlowStep(
                    number: 4,
                    title: "AI Visualization",
                    description: "Only dish names sent to Claude API"
                )
            }
            
            // API transparency
            VStack(alignment: .leading, spacing: 8) {
                Text("External API Usage")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude API by Anthropic")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("Used only for generating dish descriptions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.shield")
                        .foregroundColor(.green)
                }
            }
        } header: {
            Text("Transparency")
        }
    }
    
    private func dataFlowStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(.blue, in: Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Legal Section
    
    private var legalSection: some View {
        Section {
            Button {
                showingPrivacyPolicy = true
            } label: {
                HStack {
                    Text("Privacy Policy")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            Button {
                coordinator.navigate(to: .privacyPolicy)
            } label: {
                HStack {
                    Text("Data Usage Details")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            // Contact for privacy questions
            HStack {
                Text("Privacy Questions?")
                Spacer()
                Text("Contact Support")
                    .foregroundColor(.blue)
            }
        } header: {
            Text("Legal & Support")
        }
    }
    
    // MARK: - Methods
    
    private func clearAllData() {
        pipeline.reset()
        // Additional cleanup could be added here for any cached data
        print("🔒 All user data cleared for privacy compliance")
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}


// MARK: - Preview

#Preview("Privacy Dashboard") {
    NavigationView {
        PrivacyDashboard()
            .environmentObject(AppCoordinator.preview)
            .environmentObject({
                let pipeline = MenuProcessingPipeline()
                // Add some sample data for preview
                let sampleOCR = OCRResult(recognizedText: [], processingTime: 1.0, overallConfidence: 0.9, imageSize: CGSize(width: 100, height: 100))
                let sampleDishes = [
                    Dish(name: "Test Dish", description: "Test", price: "$10", category: .mainCourse, extractionConfidence: 0.9)
                ]
                pipeline.currentMenu = Menu(dishes: sampleDishes, ocrConfidence: 0.9)
                return pipeline
            }())
    }
}

#Preview("Privacy Policy") {
    PrivacyPolicyView()
}