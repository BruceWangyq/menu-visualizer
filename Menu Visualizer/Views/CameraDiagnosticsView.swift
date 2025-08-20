//
//  CameraDiagnosticsView.swift
//  Menu Visualizer
//
//  Comprehensive camera diagnostics UI for debugging camera issues
//

import SwiftUI
import AVFoundation

struct CameraDiagnosticsView: View {
    @StateObject private var diagnosticService = CameraDiagnosticService()
    @State private var showingReport = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Camera System Diagnostics")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Comprehensive analysis of camera functionality")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Quick Status Checks
                VStack(spacing: 16) {
                    quickStatusView
                    
                    if let report = diagnosticService.diagnosticReport {
                        reportSummaryView(report)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button {
                        Task {
                            await diagnosticService.runComprehensiveDiagnostics()
                            showingReport = true
                        }
                    } label: {
                        HStack {
                            if diagnosticService.isRunningDiagnostics {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Running Diagnostics...")
                            } else {
                                Image(systemName: "play.circle.fill")
                                Text("Run Full Diagnostic")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(diagnosticService.isRunningDiagnostics)
                    
                    if diagnosticService.diagnosticReport != nil {
                        Button {
                            showingReport = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("View Last Report")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingReport) {
            if let report = diagnosticService.diagnosticReport {
                DiagnosticReportView(report: report)
            }
        }
    }
    
    // MARK: - Quick Status View
    
    @ViewBuilder
    private var quickStatusView: some View {
        VStack(spacing: 12) {
            Text("Quick Status Check")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                quickStatusItem(
                    title: "Environment",
                    value: environmentStatus,
                    color: environmentStatus == "Physical Device" ? .green : .orange
                )
                
                quickStatusItem(
                    title: "Hardware",
                    value: hardwareStatus,
                    color: hardwareStatus == "Available" ? .green : .red
                )
                
                quickStatusItem(
                    title: "Permission",
                    value: permissionStatus,
                    color: permissionColor
                )
                
                quickStatusItem(
                    title: "Info.plist",
                    value: infoPlistStatus,
                    color: infoPlistStatus == "Valid" ? .green : .red
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func quickStatusItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Computed Properties
    
    private var environmentStatus: String {
        #if targetEnvironment(simulator)
        return "Simulator"
        #else
        return "Physical Device"
        #endif
    }
    
    private var hardwareStatus: String {
        UIImagePickerController.isSourceTypeAvailable(.camera) ? "Available" : "Not Available"
    }
    
    private var permissionStatus: String {
        AVCaptureDevice.authorizationStatus(for: .video).displayName
    }
    
    private var permissionColor: Color {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .green
        case .denied, .restricted: return .red
        case .notDetermined: return .orange
        @unknown default: return .gray
        }
    }
    
    private var infoPlistStatus: String {
        guard let description = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String,
              !description.isEmpty else {
            return "Missing"
        }
        return "Valid"
    }
    
    // MARK: - Report Summary View
    
    private func reportSummaryView(_ report: CameraDiagnosticReport) -> some View {
        VStack(spacing: 12) {
            Text("Last Diagnostic Summary")
                .font(.headline)
            
            Text(report.summary)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            if !report.criticalIssues.isEmpty {
                VStack(spacing: 4) {
                    Text("Critical Issues:")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    ForEach(Array(report.criticalIssues.enumerated()), id: \.offset) { _, issue in
                        Text(issue.title)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Diagnostic Report Detail View

struct DiagnosticReportView: View {
    let report: CameraDiagnosticReport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Summary Section
                Section("Summary") {
                    Text(report.summary)
                        .font(.subheadline)
                }
                
                // Critical Issues Section
                if !report.criticalIssues.isEmpty {
                    Section("Critical Issues") {
                        ForEach(Array(report.criticalIssues.enumerated()), id: \.offset) { _, issue in
                            Label(issue.title, systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(issue.severity.color)
                        }
                    }
                }
                
                // System Status Section
                Section("System Status") {
                    HStack {
                        Text("Environment")
                        Spacer()
                        Text(report.environment.description)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Hardware Available")
                        Spacer()
                        Image(systemName: report.hardwareAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(report.hardwareAvailable ? .green : .red)
                    }
                    
                    HStack {
                        Text("Permission Status")
                        Spacer()
                        Text(report.permissionStatus.displayName)
                            .foregroundColor(report.permissionStatus.isAuthorized ? .green : .red)
                    }
                    
                    HStack {
                        Text("Info.plist Valid")
                        Spacer()
                        Image(systemName: report.infoPlistValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(report.infoPlistValid ? .green : .red)
                    }
                    
                    HStack {
                        Text("Session Creation")
                        Spacer()
                        Text(report.sessionCreationResult.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Available Devices Section
                if !report.availableDevices.isEmpty {
                    Section("Available Camera Devices") {
                        ForEach(Array(report.availableDevices.enumerated()), id: \.offset) { _, device in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.localizedName)
                                    .font(.subheadline)
                                Text("Position: \(device.position.description)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Recommendations Section
                if !report.recommendations.isEmpty {
                    Section("Recommendations") {
                        ForEach(Array(report.recommendations.enumerated()), id: \.offset) { _, recommendation in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recommendation.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(recommendation.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Diagnostic Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension AVCaptureDevice.Position {
    var description: String {
        switch self {
        case .front: return "Front"
        case .back: return "Back"
        case .unspecified: return "Unspecified"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Preview

#Preview {
    CameraDiagnosticsView()
}

#Preview("Report") {
    let report = CameraDiagnosticReport(
        environment: .simulator,
        hardwareAvailable: false,
        permissionStatus: .notDetermined,
        infoPlistValid: true,
        availableDevices: [],
        sessionCreationResult: .failure("No camera hardware"),
        recommendations: [.testOnRealDevice],
        criticalIssues: [.simulatorLimitation, .noHardware]
    )
    
    DiagnosticReportView(report: report)
}