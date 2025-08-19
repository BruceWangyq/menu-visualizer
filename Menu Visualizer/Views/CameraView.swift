//
//  CameraView.swift
//  Menu Visualizer
//
//  SwiftUI camera interface with UIViewControllerRepresentable for real camera preview
//

import SwiftUI
import AVFoundation
import UIKit

/// SwiftUI wrapper for camera preview using AVFoundation
struct CameraView: UIViewControllerRepresentable {
    @ObservedObject var cameraService: CameraService
    @ObservedObject var permissionManager: CameraPermissionManager
    
    let onCapture: (UIImage) -> Void
    let onError: (MenulyError) -> Void
    let onFocusTap: ((CGPoint) -> Void)?
    
    init(
        cameraService: CameraService,
        permissionManager: CameraPermissionManager,
        onCapture: @escaping (UIImage) -> Void,
        onError: @escaping (MenulyError) -> Void,
        onFocusTap: ((CGPoint) -> Void)? = nil
    ) {
        self.cameraService = cameraService
        self.permissionManager = permissionManager
        self.onCapture = onCapture
        self.onError = onError
        self.onFocusTap = onFocusTap
    }
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // Update camera session if needed
        if permissionManager.authorizationStatus == .authorized {
            Task { @MainActor in
                await context.coordinator.setupCamera(for: uiViewController)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, CameraViewControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func setupCamera(for viewController: CameraViewController? = nil) async {
            let result = parent.cameraService.setupCaptureSession()
            
            switch result {
            case .success(let session):
                if let vc = viewController {
                    await MainActor.run {
                        vc.setCaptureSession(session)
                    }
                }
                parent.cameraService.startSession()
            case .failure(let error):
                await MainActor.run {
                    parent.onError(error)
                }
            }
        }
        
        func didTapToFocus(at point: CGPoint) {
            parent.cameraService.setFocusPoint(point)
            parent.onFocusTap?(point)
        }
        
        func didCapturePhoto(_ image: UIImage) {
            parent.onCapture(image)
        }
        
        func didEncounterError(_ error: MenulyError) {
            parent.onError(error)
        }
    }
}

// MARK: - Camera View Controller

protocol CameraViewControllerDelegate: AnyObject {
    func didTapToFocus(at point: CGPoint)
    func didCapturePhoto(_ image: UIImage)
    func didEncounterError(_ error: MenulyError)
}

final class CameraViewController: UIViewController {
    weak var delegate: CameraViewControllerDelegate?
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureSession: AVCaptureSession?
    private var focusView: FocusIndicatorView?
    private var overlayView: CameraOverlayUIView?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startPreviewSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopPreviewSession()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Setup camera overlay
        overlayView = CameraOverlayUIView()
        if let overlay = overlayView {
            view.addSubview(overlay)
            overlay.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: view.topAnchor),
                overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupPreviewLayer(with session: AVCaptureSession) {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        captureSession = session
    }
    
    // MARK: - Camera Control
    
    func setCaptureSession(_ session: AVCaptureSession) {
        setupPreviewLayer(with: session)
    }
    
    private func startPreviewSession() {
        guard let session = captureSession, !session.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    private func stopPreviewSession() {
        guard let session = captureSession, session.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }
    
    // MARK: - Focus Handling
    
    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: view)
        
        // Convert touch point to camera coordinate system
        guard let previewLayer = previewLayer else { return }
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        
        // Show focus indicator
        showFocusIndicator(at: touchPoint)
        
        // Delegate focus handling
        delegate?.didTapToFocus(at: devicePoint)
    }
    
    private func showFocusIndicator(at point: CGPoint) {
        // Remove existing focus indicator
        focusView?.removeFromSuperview()
        
        // Create new focus indicator
        let focusIndicator = FocusIndicatorView()
        focusIndicator.center = point
        view.addSubview(focusIndicator)
        
        focusView = focusIndicator
        focusIndicator.animateFocus()
        
        // Auto-hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            focusIndicator.removeFromSuperview()
            if self.focusView == focusIndicator {
                self.focusView = nil
            }
        }
    }
}

// MARK: - Focus Indicator View

final class FocusIndicatorView: UIView {
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        setupAppearance()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupAppearance() {
        backgroundColor = .clear
        layer.borderWidth = 2
        layer.borderColor = UIColor.systemYellow.cgColor
        layer.cornerRadius = 4
        alpha = 0
    }
    
    func animateFocus() {
        transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        alpha = 0
        
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 1
            self.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 1.0, animations: {
                self.alpha = 0
            })
        }
    }
}

// MARK: - Camera Overlay UI View

final class CameraOverlayUIView: UIView {
    private let frameView = UIView()
    private let instructionLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupOverlay() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        
        // Setup frame indicator
        frameView.backgroundColor = .clear
        frameView.layer.borderWidth = 2
        frameView.layer.borderColor = UIColor.white.cgColor
        frameView.layer.cornerRadius = 8
        addSubview(frameView)
        
        // Setup instruction label
        instructionLabel.text = "Position menu within frame"
        instructionLabel.textColor = .white
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textAlignment = .center
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        instructionLabel.layer.cornerRadius = 16
        instructionLabel.clipsToBounds = true
        addSubview(instructionLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        frameView.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Frame view (centered, aspect ratio for documents)
            frameView.centerXAnchor.constraint(equalTo: centerXAnchor),
            frameView.centerYAnchor.constraint(equalTo: centerYAnchor),
            frameView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.85),
            frameView.heightAnchor.constraint(equalTo: frameView.widthAnchor, multiplier: 0.7),
            
            // Instruction label
            instructionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: frameView.bottomAnchor, constant: 24),
            instructionLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.8),
            instructionLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Add corner brackets to frame
        addCornerBrackets()
    }
    
    private func addCornerBrackets() {
        // Remove existing bracket layers
        layer.sublayers?.removeAll { $0.name == "bracket" }
        
        let bracketLength: CGFloat = 20
        let bracketWidth: CGFloat = 3
        
        let corners = [
            (frameView.frame.minX, frameView.frame.minY), // Top-left
            (frameView.frame.maxX, frameView.frame.minY), // Top-right
            (frameView.frame.minX, frameView.frame.maxY), // Bottom-left
            (frameView.frame.maxX, frameView.frame.maxY)  // Bottom-right
        ]
        
        for (index, corner) in corners.enumerated() {
            let bracket = createCornerBracket(at: corner, for: index, length: bracketLength, width: bracketWidth)
            bracket.name = "bracket"
            layer.addSublayer(bracket)
        }
    }
    
    private func createCornerBracket(at point: (CGFloat, CGFloat), for corner: Int, length: CGFloat, width: CGFloat) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let path = UIBezierPath()
        
        switch corner {
        case 0: // Top-left
            path.move(to: CGPoint(x: point.0, y: point.1 + length))
            path.addLine(to: CGPoint(x: point.0, y: point.1))
            path.addLine(to: CGPoint(x: point.0 + length, y: point.1))
        case 1: // Top-right
            path.move(to: CGPoint(x: point.0 - length, y: point.1))
            path.addLine(to: CGPoint(x: point.0, y: point.1))
            path.addLine(to: CGPoint(x: point.0, y: point.1 + length))
        case 2: // Bottom-left
            path.move(to: CGPoint(x: point.0, y: point.1 - length))
            path.addLine(to: CGPoint(x: point.0, y: point.1))
            path.addLine(to: CGPoint(x: point.0 + length, y: point.1))
        case 3: // Bottom-right
            path.move(to: CGPoint(x: point.0 - length, y: point.1))
            path.addLine(to: CGPoint(x: point.0, y: point.1))
            path.addLine(to: CGPoint(x: point.0, y: point.1 - length))
        default:
            break
        }
        
        layer.path = path.cgPath
        layer.strokeColor = UIColor.white.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = width
        layer.lineCap = .round
        
        return layer
    }
}

// MARK: - Preview Support

#if DEBUG
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(
            cameraService: CameraService(),
            permissionManager: CameraPermissionManager(),
            onCapture: { _ in },
            onError: { _ in }
        )
    }
}
#endif