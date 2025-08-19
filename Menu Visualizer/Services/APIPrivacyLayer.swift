//
//  APIPrivacyLayer.swift
//  Menu Visualizer
//
//  Enhanced API privacy layer with iOS security frameworks integration
//

import Foundation
import Network
import CryptoKit
import OSLog

/// Enhanced API privacy protection layer using iOS security frameworks
@MainActor
final class APIPrivacyLayer: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isNetworkSecure: Bool = false
    @Published var tlsVersion: String = "Unknown"
    @Published var certificatePinningStatus: CertificatePinningStatus = .notConfigured
    @Published var privacyHeadersEnabled: Bool = true
    @Published var requestAuditingEnabled: Bool = true
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.menuly.api.privacy", category: "APIPrivacyLayer")
    private let networkMonitor = NWPathMonitor()
    private let sessionConfiguration: URLSessionConfiguration
    private lazy var secureSession: URLSession = {
        return URLSession(configuration: sessionConfiguration)
    }()
    
    // Certificate pinning
    private let pinnedCertificates: Set<Data>
    private let trustedHosts: Set<String>
    
    // Privacy protection
    private var requestAuditLog: [APIRequestAudit] = []
    private let maxAuditLogSize = 100
    
    // MARK: - Initialization
    
    init() {
        // Configure secure session
        sessionConfiguration = URLSessionConfiguration.default
        setupSecureSessionConfiguration()
        
        // Initialize certificate pinning
        pinnedCertificates = Self.loadPinnedCertificates()
        trustedHosts = ["api.anthropic.com"] // Claude API endpoint
        
        // Setup network monitoring
        setupNetworkMonitoring()
        
        logger.info("API Privacy Layer initialized")
    }
    
    // MARK: - Secure Session Configuration
    
    private func setupSecureSessionConfiguration() {
        // Enforce TLS 1.3
        sessionConfiguration.tlsMinimumSupportedProtocolVersion = .TLSv13
        sessionConfiguration.tlsMaximumSupportedProtocolVersion = .TLSv13
        
        // Privacy-focused headers
        sessionConfiguration.httpAdditionalHeaders = getPrivacyHeaders()
        
        // Security configuration
        sessionConfiguration.httpShouldUsePipelining = false
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfiguration.urlCache = nil // Disable caching for privacy
        
        // Timeout configuration
        sessionConfiguration.timeoutIntervalForRequest = 30.0
        sessionConfiguration.timeoutIntervalForResource = 60.0
        
        logger.debug("Secure session configuration completed")
    }
    
    private func getPrivacyHeaders() -> [String: String] {
        return [
            "User-Agent": "Menuly/1.0 Privacy-First iOS",
            "DNT": "1", // Do Not Track
            "X-Privacy-Policy": "no-data-collection",
            "X-Data-Minimization": "true",
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0"
        ]
    }
    
    // MARK: - Certificate Pinning
    
    private static func loadPinnedCertificates() -> Set<Data> {
        var certificates: Set<Data> = []
        
        // Load pinned certificates from bundle
        if let certPath = Bundle.main.path(forResource: "anthropic-api", ofType: "der"),
           let certData = NSData(contentsOfFile: certPath) as Data? {
            certificates.insert(certData)
        }
        
        // Note: In production, you would include the actual pinned certificates
        // For this example, we're setting up the framework
        return certificates
    }
    
    private func validateCertificatePinning(for host: String, trust: SecTrust) -> Bool {
        guard trustedHosts.contains(host) else {
            return true // Allow non-pinned hosts
        }
        
        // Get server certificate
        guard let serverCertificate = SecTrustGetCertificateAtIndex(trust, 0) else {
            logger.error("Failed to get server certificate")
            return false
        }
        
        let serverCertData = SecCertificateCopyData(serverCertificate)
        let serverCertDataCF = CFDataGetBytePtr(serverCertData)
        let serverCertLength = CFDataGetLength(serverCertData)
        let serverCertNSData = Data(bytes: serverCertDataCF!, count: serverCertLength)
        
        // Check against pinned certificates
        let isPinned = pinnedCertificates.contains(serverCertNSData)
        
        if isPinned {
            certificatePinningStatus = .valid
            logger.info("Certificate pinning validation successful for \(host)")
        } else {
            certificatePinningStatus = .invalid
            logger.error("Certificate pinning validation failed for \(host)")
        }
        
        return isPinned
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkPathUpdate(path)
            }
        }
        
        let queue = DispatchQueue(label: "api.network.monitor")
        networkMonitor.start(queue: queue)
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) {
        isNetworkSecure = evaluateNetworkSecurity(path)
        
        if path.status == .satisfied {
            if path.isExpensive {
                logger.info("Network is expensive - privacy implications noted")
            }
            
            if !path.supportsIPv6 {
                logger.warning("IPv6 not supported - potential privacy limitation")
            }
        } else {
            logger.warning("Network path not satisfied - API calls will fail")
        }
    }
    
    private func evaluateNetworkSecurity(_ path: NWPath) -> Bool {
        // Evaluate network security characteristics
        let isWiFi = path.usesInterfaceType(.wifi)
        let isCellular = path.usesInterfaceType(.cellular)
        let isWired = path.usesInterfaceType(.wiredEthernet)
        
        // WiFi and cellular are generally acceptable, avoid other types
        return isWiFi || isCellular || isWired
    }
    
    // MARK: - Privacy-Safe API Requests
    
    func makePrivacySafeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        // Validate request privacy compliance
        try validateRequestPrivacy(request)
        
        // Add privacy audit
        let auditEntry = APIRequestAudit(
            url: request.url?.absoluteString ?? "unknown",
            method: request.httpMethod ?? "GET",
            timestamp: Date(),
            privacyCompliant: true
        )
        
        addToAuditLog(auditEntry)
        
        // Configure request with privacy headers
        var secureRequest = request
        secureRequest = addPrivacyHeaders(to: secureRequest)
        
        logger.debug("Making privacy-safe API request to: \(request.url?.host ?? "unknown")")
        
        do {
            let (data, response) = try await secureSession.data(for: secureRequest)
            
            // Validate response privacy
            try validateResponsePrivacy(response)
            
            // Update audit log
            updateAuditEntry(auditEntry, success: true, responseSize: data.count)
            
            logger.debug("Privacy-safe API request completed successfully")
            return (data, response)
            
        } catch {
            // Update audit log with error
            updateAuditEntry(auditEntry, success: false, error: error)
            
            logger.error("Privacy-safe API request failed: \(error.localizedDescription)")
            throw APIPrivacyError.requestFailed(error)
        }
    }
    
    // MARK: - Request Privacy Validation
    
    private func validateRequestPrivacy(_ request: URLRequest) throws {
        // Check URL is HTTPS
        guard let url = request.url,
              url.scheme == "https" else {
            throw APIPrivacyError.insecureProtocol
        }
        
        // Validate host is trusted
        guard let host = url.host,
              trustedHosts.contains(host) else {
            throw APIPrivacyError.untrustedHost
        }
        
        // Check for sensitive data in URL
        if containsSensitiveData(in: url.absoluteString) {
            throw APIPrivacyError.sensitiveDataInURL
        }
        
        // Validate request body if present
        if let bodyData = request.httpBody {
            try validateRequestBody(bodyData)
        }
    }
    
    private func validateRequestBody(_ data: Data) throws {
        // Convert to string for analysis (safe since this is our own API payload)
        guard let bodyString = String(data: data, encoding: .utf8) else {
            return // Can't analyze non-UTF8 data
        }
        
        // Check for potential privacy violations in the request body
        if containsSensitiveData(in: bodyString) {
            throw APIPrivacyError.sensitiveDataInBody
        }
    }
    
    private func containsSensitiveData(in content: String) -> Bool {
        let sensitivePatterns = [
            // Email patterns
            #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            // Phone patterns
            #"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"#,
            // Credit card patterns
            #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"#,
            // Social security patterns
            #"\b\d{3}[-]?\d{2}[-]?\d{4}\b"#
        ]
        
        for pattern in sensitivePatterns {
            if content.range(of: pattern, options: .regularExpression) != nil {
                logger.warning("Potential sensitive data detected in API request")
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Response Privacy Validation
    
    private func validateResponsePrivacy(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }
        
        // Check response headers for privacy compliance
        let headers = httpResponse.allHeaderFields
        
        // Validate TLS version
        if let tlsVersionHeader = headers["TLS-Version"] as? String {
            tlsVersion = tlsVersionHeader
            if !tlsVersionHeader.contains("1.3") {
                logger.warning("Response not using TLS 1.3: \(tlsVersionHeader)")
            }
        }
        
        // Check for tracking headers
        let trackingHeaders = ["Set-Cookie", "X-Tracking-ID", "X-Analytics"]
        for header in trackingHeaders {
            if headers[header] != nil {
                logger.warning("Potential tracking header detected: \(header)")
            }
        }
    }
    
    // MARK: - Privacy Headers Management
    
    private func addPrivacyHeaders(to request: URLRequest) -> URLRequest {
        var modifiedRequest = request
        
        let privacyHeaders = getPrivacyHeaders()
        for (key, value) in privacyHeaders {
            modifiedRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add request-specific privacy headers
        modifiedRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        modifiedRequest.setValue(generateRequestID(), forHTTPHeaderField: "X-Request-ID")
        
        return modifiedRequest
    }
    
    private func generateRequestID() -> String {
        return UUID().uuidString
    }
    
    // MARK: - Audit Logging
    
    private func addToAuditLog(_ entry: APIRequestAudit) {
        requestAuditLog.append(entry)
        
        // Maintain max log size
        if requestAuditLog.count > maxAuditLogSize {
            requestAuditLog.removeFirst()
        }
    }
    
    private func updateAuditEntry(_ entry: APIRequestAudit, success: Bool, responseSize: Int = 0, error: Error? = nil) {
        if let index = requestAuditLog.firstIndex(where: { $0.id == entry.id }) {
            requestAuditLog[index].success = success
            requestAuditLog[index].responseSize = responseSize
            requestAuditLog[index].error = error?.localizedDescription
            requestAuditLog[index].duration = Date().timeIntervalSince(entry.timestamp)
        }
    }
    
    // MARK: - Privacy Reporting
    
    func getPrivacyReport() -> APIPrivacyReport {
        let totalRequests = requestAuditLog.count
        let successfulRequests = requestAuditLog.filter { $0.success == true }.count
        let privacyCompliantRequests = requestAuditLog.filter { $0.privacyCompliant }.count
        
        return APIPrivacyReport(
            totalRequests: totalRequests,
            successfulRequests: successfulRequests,
            privacyCompliantRequests: privacyCompliantRequests,
            certificatePinningStatus: certificatePinningStatus,
            tlsVersion: tlsVersion,
            isNetworkSecure: isNetworkSecure,
            recentRequests: Array(requestAuditLog.suffix(10))
        )
    }
    
    func clearAuditLog() {
        requestAuditLog.removeAll()
        logger.info("API audit log cleared")
    }
    
    // MARK: - Security Status
    
    func validateSecurityStatus() -> SecurityValidationResult {
        var issues: [SecurityIssue] = []
        
        // Check TLS configuration
        if sessionConfiguration.tlsMinimumSupportedProtocolVersion != .TLSv13 {
            issues.append(SecurityIssue(type: .tlsConfiguration, description: "TLS 1.3 not enforced"))
        }
        
        // Check certificate pinning
        if certificatePinningStatus != .valid && !trustedHosts.isEmpty {
            issues.append(SecurityIssue(type: .certificatePinning, description: "Certificate pinning not validated"))
        }
        
        // Check network security
        if !isNetworkSecure {
            issues.append(SecurityIssue(type: .networkSecurity, description: "Network connection not secure"))
        }
        
        let overallScore = calculateSecurityScore(issues: issues)
        
        return SecurityValidationResult(
            score: overallScore,
            issues: issues,
            isSecure: issues.isEmpty
        )
    }
    
    private func calculateSecurityScore(issues: [SecurityIssue]) -> Double {
        let maxScore = 100.0
        let deduction = Double(issues.count) * 25.0
        return max(0.0, maxScore - deduction)
    }
}

// MARK: - Supporting Types

enum CertificatePinningStatus {
    case notConfigured
    case valid
    case invalid
}

enum APIPrivacyError: LocalizedError {
    case insecureProtocol
    case untrustedHost
    case sensitiveDataInURL
    case sensitiveDataInBody
    case requestFailed(Error)
    case certificateValidationFailed
    
    var errorDescription: String? {
        switch self {
        case .insecureProtocol:
            return "Request must use HTTPS protocol"
        case .untrustedHost:
            return "Request to untrusted host"
        case .sensitiveDataInURL:
            return "Sensitive data detected in URL"
        case .sensitiveDataInBody:
            return "Sensitive data detected in request body"
        case .requestFailed(let error):
            return "Network request failed: \(error.localizedDescription)"
        case .certificateValidationFailed:
            return "Certificate validation failed"
        }
    }
}

struct APIRequestAudit: Identifiable {
    let id = UUID()
    let url: String
    let method: String
    let timestamp: Date
    let privacyCompliant: Bool
    var success: Bool?
    var responseSize: Int = 0
    var error: String?
    var duration: TimeInterval = 0
}

struct APIPrivacyReport {
    let totalRequests: Int
    let successfulRequests: Int
    let privacyCompliantRequests: Int
    let certificatePinningStatus: CertificatePinningStatus
    let tlsVersion: String
    let isNetworkSecure: Bool
    let recentRequests: [APIRequestAudit]
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0.0 }
        return Double(successfulRequests) / Double(totalRequests)
    }
    
    var privacyComplianceRate: Double {
        guard totalRequests > 0 else { return 1.0 }
        return Double(privacyCompliantRequests) / Double(totalRequests)
    }
}

struct SecurityValidationResult {
    let score: Double
    let issues: [SecurityIssue]
    let isSecure: Bool
}

struct SecurityIssue {
    let type: SecurityIssueType
    let description: String
}

enum SecurityIssueType {
    case tlsConfiguration
    case certificatePinning
    case networkSecurity
    case privacyHeaders
}