//
//  PrivacyHealthDetailView.swift
//  Menu Visualizer
//
//  Detailed privacy health analysis and recommendations view
//

import SwiftUI

/// Detailed view showing privacy health analysis and actionable recommendations
struct PrivacyHealthDetailView: View {
    let report: SettingsHealthReport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    healthScoreSection
                    
                    if !report.issues.isEmpty {
                        issuesSection
                    }
                    
                    if !report.recommendations.isEmpty {
                        recommendationsSection
                    }
                    
                    privacyTipsSection
                }
                .padding()
            }
            .navigationTitle("Privacy Health")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            })
        }
    }
    
    // MARK: - Health Score Section
    
    @ViewBuilder
    private var healthScoreSection: some View {
        VStack(spacing: 16) {
            // Large circular progress indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: report.score / 100)
                    .stroke(report.healthLevel.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.5), value: report.score)
                
                VStack {
                    Text("\(Int(report.score))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Health level badge
            Text(report.healthLevel.rawValue.capitalized)
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(report.healthLevel.color.opacity(0.2))
                .foregroundColor(report.healthLevel.color)
                .cornerRadius(12)
            
            // Description
            Text(report.healthLevel.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Issues Section
    
    @ViewBuilder
    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Issues Found")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            ForEach(Array(report.issues.enumerated()), id: \.offset) { index, issue in
                IssueRowView(issue: issue)
                
                if index < report.issues.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Recommendations Section
    
    @ViewBuilder
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.blue)
                Text("Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            ForEach(Array(report.recommendations.enumerated()), id: \.offset) { index, recommendation in
                RecommendationRowView(recommendation: recommendation)
                
                if index < report.recommendations.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Privacy Tips Section
    
    @ViewBuilder
    private var privacyTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.checkerboard")
                    .foregroundColor(.green)
                Text("Privacy Tips")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            PrivacyTipView(
                icon: "lock.fill",
                title: "Enable Biometric Protection",
                description: "Use Face ID or Touch ID to secure your privacy settings and sensitive data."
            )
            
            Divider()
            
            PrivacyTipView(
                icon: "camera.viewfinder",
                title: "Screenshot Protection",
                description: "Prevent sensitive content from appearing in screenshots and screen recordings."
            )
            
            Divider()
            
            PrivacyTipView(
                icon: "trash.fill",
                title: "Regular Data Cleanup",
                description: "Regularly clear temporary files and cached data to minimize your digital footprint."
            )
            
            Divider()
            
            PrivacyTipView(
                icon: "network",
                title: "Network Security",
                description: "Only use secure networks and enable network protection for API communications."
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Issue Row View

struct IssueRowView: View {
    let issue: SettingsIssue
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: issue.severity.iconName)
                .foregroundColor(issue.severity.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.severity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(issue.severity.color)
                
                Text(issue.description)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Recommendation Row View

struct RecommendationRowView: View {
    let recommendation: PrivacySettingsRecommendation
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack {
                Image(systemName: recommendation.type.iconName)
                    .foregroundColor(recommendation.impact.color)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(recommendation.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(recommendation.impact.description)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(recommendation.impact.color.opacity(0.2))
                            .foregroundColor(recommendation.impact.color)
                            .cornerRadius(4)
                    }
                    
                    Text(recommendation.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(recommendation.action)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Privacy Tip View

struct PrivacyTipView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Extensions

extension SettingsIssue.IssueSeverity {
    var iconName: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
    
    var title: String {
        switch self {
        case .info:
            return "Information"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        }
    }
}

extension PrivacySettingsRecommendation.RecommendationType {
    var iconName: String {
        switch self {
        case .security:
            return "shield.fill"
        case .privacy:
            return "hand.raised.fill"
        case .performance:
            return "speedometer"
        case .usability:
            return "person.fill"
        }
    }
}

extension PrivacySettingsRecommendation.ImpactLevel {
    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
}

#Preview {
    PrivacyHealthDetailView(
        report: SettingsHealthReport(
            score: 85.0,
            healthLevel: .good,
            issues: [
                SettingsIssue(
                    severity: .warning,
                    description: "Screenshot protection is disabled"
                ),
                SettingsIssue(
                    severity: .info,
                    description: "Biometric protection available but not enabled"
                )
            ],
            recommendations: [
                PrivacySettingsRecommendation(
                    type: .security,
                    title: "Enable Biometric Protection",
                    description: "Use Face ID or Touch ID to protect sensitive data",
                    impact: .medium,
                    action: "Enable biometric protection in privacy settings"
                )
            ]
        )
    )
}