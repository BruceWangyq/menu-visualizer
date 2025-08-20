//
//  CameraPreview.swift
//  Menu Visualizer
//
//  SwiftUI camera preview with robust UIKit integration
//

import SwiftUI
import AVFoundation
import UIKit

/// SwiftUI wrapper for camera preview
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    let onTapToFocus: ((CGPoint) -> Void)?
    let onZoomGesture: ((CGFloat) -> Void)?
    
    init(
        cameraManager: CameraManager,
        onTapToFocus: ((CGPoint) -> Void)? = nil,
        onZoomGesture: ((CGFloat) -> Void)? = nil
    ) {
        self.cameraManager = cameraManager
        self.onTapToFocus = onTapToFocus
        self.onZoomGesture = onZoomGesture
    }
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Update preview layer when session changes
        if let previewLayer = cameraManager.previewLayer {
            uiView.setPreviewLayer(previewLayer)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    final class Coordinator: NSObject, CameraPreviewDelegate {
        let parent: CameraPreview
        
        init(_ parent: CameraPreview) {
            self.parent = parent
        }
        
        func didTapToFocus(at point: CGPoint) {
            parent.onTapToFocus?(point)
        }
        
        func didZoom(to factor: CGFloat) {
            parent.onZoomGesture?(factor)
        }
    }
}

// MARK: - Camera Preview UIView

protocol CameraPreviewDelegate: AnyObject {
    func didTapToFocus(at point: CGPoint)
    func didZoom(to factor: CGFloat)
}

final class CameraPreviewUIView: UIView {
    weak var delegate: CameraPreviewDelegate?
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var initialZoomFactor: CGFloat = 1.0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupGestures()
    }
    
    private func setupView() {
        backgroundColor = .black
        clipsToBounds = true
    }
    
    private func setupGestures() {
        // Tap to focus gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
        
        // Pinch to zoom gesture
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinchGesture)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    // MARK: - Preview Layer Management
    
    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        // Remove existing layer
        previewLayer?.removeFromSuperlayer()
        
        // Add new layer
        previewLayer = layer
        layer.frame = bounds
        self.layer.insertSublayer(layer, at: 0)
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: self)
        
        // Convert touch point to camera coordinate system
        guard let previewLayer = previewLayer else { return }
        
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        delegate?.didTapToFocus(at: devicePoint)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            initialZoomFactor = 1.0
            
        case .changed:
            let scale = gesture.scale
            let newZoomFactor = initialZoomFactor * scale
            delegate?.didZoom(to: newZoomFactor)
            
        case .ended, .cancelled:
            initialZoomFactor = 1.0
            
        default:
            break
        }
    }
}

// MARK: - Camera Control Overlay

struct CameraControlOverlay: View {
    @ObservedObject var cameraManager: CameraManager
    
    let onCapture: () -> Void
    let onSwitchCamera: () -> Void
    let onFlashToggle: (() -> Void)?
    
    @State private var showingZoomIndicator = false
    
    var body: some View {
        ZStack {
            // Focus indicator
            if let focusPoint = cameraManager.focusPoint {
                SwiftUIFocusIndicatorView()
                    .position(x: focusPoint.x, y: focusPoint.y)
            }
            
            // Zoom indicator
            if showingZoomIndicator {
                ZoomIndicatorView(zoomFactor: cameraManager.zoomFactor)
                    .position(x: UIScreen.main.bounds.width / 2, y: 100)
            }
            
            // Camera controls
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Camera switch button
                    Button(action: onSwitchCamera) {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(cameraManager.isCapturing)
                    
                    Spacer()
                    
                    // Capture button
                    Button(action: onCapture) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .stroke(.black, lineWidth: 2)
                                .frame(width: 70, height: 70)
                            
                            if cameraManager.isCapturing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(1.2)
                            }
                        }
                    }
                    .disabled(cameraManager.isCapturing || !cameraManager.isSessionRunning)
                    
                    Spacer()
                    
                    // Flash toggle (placeholder)
                    if let flashAction = onFlashToggle {
                        Button(action: flashAction) {
                            Image(systemName: "bolt.slash")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    } else {
                        Color.clear
                            .frame(width: 50, height: 50)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 50)
            }
        }
        .onChange(of: cameraManager.zoomFactor) { _, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showingZoomIndicator = true
            }
            
            // Hide zoom indicator after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showingZoomIndicator = false
                }
            }
        }
    }
}

// MARK: - Focus Indicator

struct SwiftUIFocusIndicatorView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 60, height: 60)
            .scaleEffect(isAnimating ? 1.0 : 1.5)
            .opacity(isAnimating ? 0.8 : 0.2)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Zoom Indicator

struct ZoomIndicatorView: View {
    let zoomFactor: CGFloat
    
    var body: some View {
        HStack {
            Image(systemName: "minus.magnifyingglass")
                .foregroundColor(.white)
            
            Text("\(zoomFactor, specifier: "%.1f")x")
                .foregroundColor(.white)
                .font(.system(.body, design: .monospaced))
            
            Image(systemName: "plus.magnifyingglass")
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Camera Viewfinder Overlay

struct CameraViewfinderOverlay: View {
    var body: some View {
        ZStack {
            // Viewfinder frame
            Rectangle()
                .stroke(.white.opacity(0.8), lineWidth: 1)
                .background(.clear)
            
            // Corner brackets
            VStack {
                HStack {
                    CornerBracket()
                    Spacer()
                    CornerBracket()
                        .rotationEffect(.degrees(90))
                }
                Spacer()
                HStack {
                    CornerBracket()
                        .rotationEffect(.degrees(-90))
                    Spacer()
                    CornerBracket()
                        .rotationEffect(.degrees(180))
                }
            }
            .padding(12)
            
            // Instructions
            VStack {
                Spacer()
                
                Text("Position menu within frame")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: Capsule())
                
                Spacer().frame(height: 24)
            }
        }
    }
}

struct CornerBracket: View {
    var body: some View {
        Path { path in
            let length: CGFloat = 24
            path.move(to: CGPoint(x: 0, y: length))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: length, y: 0))
        }
        .stroke(.white, lineWidth: 3)
        .frame(width: 24, height: 24)
    }
}

// MARK: - Preview

#if DEBUG
struct CameraPreview_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            CameraViewfinderOverlay()
                .padding()
        }
    }
}
#endif