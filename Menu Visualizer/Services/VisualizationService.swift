//
//  VisualizationService.swift
//  Menu Visualizer
//
//  Secure API service for Claude AI visualization generation
//

import Foundation
import SwiftUI
import OSLog

/// Secure service for generating dish visualizations using Claude API
@MainActor
final class VisualizationService: ObservableObject {
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0.0
    @Published var lastGeneratedVisualization: VisualizationResponse?
    
    private let session: URLSession
    private let logger = Logger(subsystem: "com.menuly.visualization", category: "API")
    
    // MARK: - Configuration
    
    private struct APIConfiguration {
        static let baseURL = "https://api.anthropic.com/v1"
        static let timeout: TimeInterval = 30
        static let maxRetries = 3
        static let apiVersion = "2023-06-01"
    }
    
    // MARK: - Initialization
    
    init() {
        // Configure session for privacy and security
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConfiguration.timeout
        configuration.timeoutIntervalForResource = APIConfiguration.timeout * 2
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsConstrainedNetworkAccess = false
        configuration.allowsExpensiveNetworkAccess = false
        
        // Privacy settings
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Visualization Generation
    
    func generateVisualization(for dish: Dish) async -> Result<VisualizationResponse, MenulyError> {
        guard !isGenerating else {
            return .failure(.apiRequestFailed("Generation already in progress"))
        }
        
        isGenerating = true
        generationProgress = 0.0
        
        let request = VisualizationRequest(dish: dish)
        
        return await withTaskGroup(of: Result<VisualizationResponse, MenulyError>.self) { group in
            group.addTask { [weak self] in
                await self?.performVisualizationRequest(request) ?? .failure(.apiRequestFailed("Service unavailable"))
            }
            
            // Add timeout task
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(APIConfiguration.timeout * 1_000_000_000))
                return .failure(.processingTimeout)
            }
            
            // Return first result (either success or timeout)
            let result = await group.next() ?? .failure(.apiRequestFailed("No response"))
            group.cancelAll()
            
            await MainActor.run {
                self.isGenerating = false
                self.generationProgress = 0.0
            }
            
            return result
        }
    }
    
    private func performVisualizationRequest(_ request: VisualizationRequest) async -> Result<VisualizationResponse, MenulyError> {
        var attempt = 0
        
        while attempt < APIConfiguration.maxRetries {
            attempt += 1
            
            let result = await executeAPIRequest(request)
            
            switch result {
            case .success(let response):
                lastGeneratedVisualization = response
                return .success(response)
            case .failure(let error):
                // Check if we should retry
                if case .apiRateLimited = error, attempt < APIConfiguration.maxRetries {
                    // Wait before retry (exponential backoff)
                    let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                }
                return .failure(error)
            }
        }
        
        return .failure(.apiRequestFailed("Max retries exceeded"))
    }
    
    private func executeAPIRequest(_ request: VisualizationRequest) async -> Result<VisualizationResponse, MenulyError> {
        await updateProgress(0.1)
        
        // Create URL request
        guard let url = URL(string: "\(APIConfiguration.baseURL)/messages") else {
            return .failure(.invalidAPIResponse)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(APIConfiguration.apiVersion, forHTTPHeaderField: "anthropic-version")
        
        // Get API key from secure storage (placeholder - implement secure storage)
        guard let apiKey = getAPIKey() else {
            return .failure(.authenticationFailed)
        }
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        await updateProgress(0.2)
        
        // Create request body
        let requestBody = createRequestBody(for: request)
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            logger.error("Failed to encode request body: \(error)")
            return .failure(.apiRequestFailed("Invalid request format"))
        }
        
        await updateProgress(0.3)
        
        // Execute request
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            await updateProgress(0.8)
            
            // Handle HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidAPIResponse)
            }
            
            return await processAPIResponse(data: data, httpResponse: httpResponse, requestId: request.requestId)
            
        } catch {
            logger.error("API request failed: \(error)")
            
            if error.localizedDescription.contains("network") {
                return .failure(.networkUnavailable)
            } else {
                return .failure(.apiRequestFailed(error.localizedDescription))
            }
        }
    }
    
    private func createRequestBody(for request: VisualizationRequest) -> [String: Any] {
        let prompt = """
        Create an appetizing, restaurant-quality description for a dish called "\(request.dishName)".
        
        \(request.description.map { "Description: \($0)" } ?? "")
        \(request.dietaryInfo.isEmpty ? "" : "Dietary info: \(request.dietaryInfo.joined(separator: ", "))")
        
        Respond with a detailed, mouth-watering description that would make someone want to order this dish. Focus on flavors, textures, presentation, and visual appeal. Keep it concise but enticing.
        """
        
        return [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 200,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
    }
    
    private func processAPIResponse(data: Data, httpResponse: HTTPURLResponse, requestId: String) async -> Result<VisualizationResponse, MenulyError> {
        await updateProgress(0.9)
        
        switch httpResponse.statusCode {
        case 200:
            return parseSuccessResponse(data: data, requestId: requestId)
        case 401:
            return .failure(.authenticationFailed)
        case 429:
            return .failure(.apiRateLimited)
        case 400...499:
            return .failure(.apiRequestFailed("Client error: \(httpResponse.statusCode)"))
        case 500...599:
            return .failure(.apiRequestFailed("Server error: \(httpResponse.statusCode)"))
        default:
            return .failure(.invalidAPIResponse)
        }
    }
    
    private func parseSuccessResponse(data: Data, requestId: String) -> Result<VisualizationResponse, MenulyError> {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                return .failure(.invalidAPIResponse)
            }
            
            let response = VisualizationResponse(
                requestId: requestId,
                imageUrl: nil, // Claude doesn't return images directly
                imageData: nil,
                description: text,
                processingTime: nil,
                success: true,
                error: nil
            )
            
            return .success(response)
            
        } catch {
            logger.error("Failed to parse API response: \(error)")
            return .failure(.invalidAPIResponse)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            self.generationProgress = progress
        }
    }
    
    private func getAPIKey() -> String? {
        // TODO: Implement secure API key storage
        // This should use Keychain Services in a real implementation
        // For now, return a placeholder that would need to be configured
        return ProcessInfo.processInfo.environment["CLAUDE_API_KEY"]
    }
    
    // MARK: - Cleanup (Privacy Compliance)
    
    func clearCache() async {
        lastGeneratedVisualization = nil
        
        // Clear URL session cache
        await Task.detached {
            self.session.configuration.urlCache?.removeAllCachedResponses()
        }.value
    }
    
    deinit {
        Task {
            await clearCache()
        }
    }
}

// MARK: - Network Monitoring

extension VisualizationService {
    func checkNetworkAvailability() async -> Bool {
        do {
            let url = URL(string: "https://api.anthropic.com/v1/health")!
            let (_, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode < 500
            }
            return false
        } catch {
            return false
        }
    }
}

// MARK: - Preview Support

extension VisualizationService {
    static var preview: VisualizationService {
        return VisualizationService()
    }
    
    func generateMockVisualization(for dish: Dish) -> VisualizationResponse {
        return VisualizationResponse(
            requestId: UUID().uuidString,
            imageUrl: nil,
            imageData: nil,
            description: "A beautifully presented \(dish.name) with vibrant colors and appealing presentation that showcases the chef's attention to detail.",
            processingTime: 2.5,
            success: true,
            error: nil
        )
    }
}