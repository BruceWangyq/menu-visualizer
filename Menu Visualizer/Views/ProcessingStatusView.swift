//
//  ProcessingStatusView.swift
//  Menu Visualizer
//
//  Real-time processing status with animations and user feedback
//

import SwiftUI

struct ProcessingStatusView: View {
    @EnvironmentObject private var pipeline: MenuProcessingPipeline
    @State private var pulseAnimation = false
    @State private var rotationAnimation = 0.0
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissal by tap
                }
            
            // Main processing card
            VStack(spacing: 24) {
                // Animated icon
                processingIcon
                
                // Status content
                statusContent
                
                // Progress indicator
                progressIndicator
                
                // Action buttons
                actionButtons
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Processing Icon
    
    private var processingIcon: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(iconColor.opacity(0.3), lineWidth: 2)
                .frame(width: 120, height: 120)
                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                .opacity(pulseAnimation ? 0.0 : 1.0)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: false),
                    value: pulseAnimation
                )
            
            // Main icon background
            Circle()
                .fill(iconColor.opacity(0.2))
                .frame(width: 80, height: 80)
            
            // Icon
            Image(systemName: processingIcon(for: pipeline.processingState))
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(iconColor)
                .rotationEffect(.degrees(rotationAnimation))
                .animation(
                    shouldRotate ? .linear(duration: 2.0).repeatForever(autoreverses: false) : .default,
                    value: rotationAnimation
                )
        }
    }
    
    // MARK: - Status Content
    
    private var statusContent: some View {
        VStack(spacing: 12) {
            Text(pipeline.processingState.displayText)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            if let detailText = detailMessage {
                Text(detailText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            // Progress bar
            ProgressView(value: pipeline.processingProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: iconColor))
                .frame(height: 6)
                .background(Color.gray.opacity(0.2), in: Capsule())
            
            // Progress percentage
            HStack {
                Text("\(Int(pipeline.processingProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let eta = estimatedTimeRemaining {
                    Text("~\(eta) remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Cancel button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    pipeline.cancelProcessing()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                    Text("Cancel")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.gray.opacity(0.2), in: Capsule())
                .foregroundColor(.primary)
            }
            
            // Minimize button (for background processing)
            if canMinimize {
                Button {
                    // This would hide the overlay but continue processing
                    // For now, we'll keep it simple
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "minus")
                        Text("Background")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(iconColor.opacity(0.2), in: Capsule())
                    .foregroundColor(iconColor)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var iconColor: Color {
        switch pipeline.processingState {
        case .idle:
            return .gray
        case .capturingPhoto:
            return .blue
        case .processingOCR:
            return .blue
        case .extractingDishes:
            return .orange
        case .parsingMenu:
            return .orange
        case .generatingVisualization:
            return .purple
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
    
    private var shouldRotate: Bool {
        switch pipeline.processingState {
        case .processingOCR, .extractingDishes, .parsingMenu, .generatingVisualization:
            return true
        default:
            return false
        }
    }
    
    private var canMinimize: Bool {
        switch pipeline.processingState {
        case .generatingVisualization:
            return true
        default:
            return false
        }
    }
    
    private var detailMessage: String? {
        switch pipeline.processingState {
        case .processingOCR:
            return "Using Apple Vision to extract text from your menu photo"
        case .parsingMenu:
            return "Analyzing menu structure and extracting dish information"
        case .generatingVisualization(let dishName):
            return "Creating AI-powered visualization for \(dishName)"
        case .completed:
            return "All processing completed successfully"
        case .error(let error):
            return error.isRecoverable ? "Tap retry to try again" : "Please check settings"
        default:
            return nil
        }
    }
    
    private var estimatedTimeRemaining: String? {
        switch pipeline.processingState {
        case .processingOCR:
            let remaining = max(0, (1.0 - pipeline.processingProgress) * 15) // ~15s for OCR
            return remaining > 1 ? "\(Int(remaining))s" : nil
        case .parsingMenu:
            return "5s"
        case .generatingVisualization:
            return "10s"
        default:
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func processingIcon(for state: ProcessingState) -> String {
        switch state {
        case .idle:
            return "camera"
        case .capturingPhoto:
            return "camera.fill"
        case .processingOCR:
            return "doc.text.viewfinder"
        case .extractingDishes:
            return "list.bullet.rectangle"
        case .parsingMenu:
            return "list.bullet.rectangle"
        case .generatingVisualization:
            return "sparkles"
        case .completed:
            return "checkmark"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    private func startAnimations() {
        // Start pulse animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
            pulseAnimation = true
        }
        
        // Start rotation animation if needed
        if shouldRotate {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                rotationAnimation = 360.0
            }
        }
    }
}


// MARK: - Preview

#Preview("Processing") {
    ProcessingStatusView()
        .environmentObject({
            let pipeline = MenuProcessingPipeline()
            pipeline.processingState = .processingOCR
            pipeline.processingProgress = 0.6
            return pipeline
        }())
}

#Preview("Error Recovery") {
    NavigationView {
        ErrorRecoveryView(error: .noTextRecognized)
            .environmentObject(AppCoordinator.preview)
            .environmentObject(MenuProcessingPipeline())
    }
}