//
//  ClaudeAPIClient.swift
//  Menuly
//
//  Direct API client for Claude 3.5 Sonnet with optimized prompts
//  Handles request/response processing with privacy-first design
//

import Foundation

/// Direct client for Claude API with optimized prompts for food visualization
/// Implements privacy-safe communication and structured response handling
class ClaudeAPIClient {
    
    // MARK: - Constants
    
    private enum APIConstants {
        static let baseURL = "https://api.anthropic.com/v1"
        static let messagesEndpoint = "/messages"
        static let model = "claude-3-5-sonnet-20241022"
        static let maxTokens = 1000
        static let temperature = 0.7
        static let apiVersion = "2023-06-01"
    }
    
    private enum PromptConstants {
        static let systemPrompt = """
        You are a culinary expert and food presentation specialist. Your role is to enhance menu dish descriptions with appetizing details while maintaining accuracy and cultural authenticity.

        Generate responses in this exact JSON format:
        {
            "description": "An appetizing, mouth-watering description that enhances the original menu text",
            "visualStyle": "Visual presentation and plating style suggestions",
            "ingredients": ["key", "ingredients", "list"],
            "preparationNotes": "Cooking method and preparation highlights"
        }

        Guidelines:
        - Keep descriptions accurate to the dish category and type
        - Use sensory language that appeals to taste, smell, and visual senses
        - Respect cultural authenticity and traditional preparation methods
        - Suggest realistic ingredients based on the dish name and category
        - Focus on presentation that enhances appetite appeal
        - Keep language professional yet enticing
        - Limit descriptions to 2-3 sentences for readability
        """
        
        static let userPromptTemplate = """
        Please create an appetizing visualization for this dish:
        
        Name: {dishName}
        Category: {dishCategory}
        Original Description: {dishDescription}
        
        Enhance this dish with appealing descriptions and presentation ideas while staying true to its category and likely preparation method.
        """
    }
    
    // MARK: - Properties
    
    private let networkManager: NetworkSecurityManager
    private let apiKeyManager: APIKeyManager
    
    // MARK: - Initialization
    
    init(
        networkManager: NetworkSecurityManager = .shared,
        apiKeyManager: APIKeyManager = .shared
    ) {
        self.networkManager = networkManager
        self.apiKeyManager = apiKeyManager
    }
    
    // MARK: - Public API
    
    /// Generate dish visualization using Claude API
    /// - Parameter dish: Privacy-safe dish payload
    /// - Returns: Result with visualization response or error
    func generateVisualization(for dish: DishAPIPayload) async -> Result<VisualizationAPIResponse, MenulyError> {
        // Validate privacy compliance
        guard dish.isPrivacySafe() else {
            return .failure(.privacyViolation("Dish payload failed privacy validation"))
        }
        
        // Get API key
        guard let apiKey = apiKeyManager.retrieveAPIKey() else {
            return .failure(.apiKeyMissing)
        }
        
        // Create request
        let requestResult = await createVisualizationRequest(for: dish, apiKey: apiKey)
        
        switch requestResult {
        case .success(let request):
            // Execute request
            return await executeRequest(request)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Validate API connectivity and key
    /// - Returns: Result indicating if API is accessible
    func validateConnectivity() async -> Result<Bool, MenulyError> {
        guard let apiKey = apiKeyManager.retrieveAPIKey() else {
            return .failure(.apiKeyMissing)
        }
        
        // Create minimal test request
        let testPayload = DishAPIPayload(
            name: "Test Dish",
            description: "Test description",
            category: "Main Course"
        )
        
        let result = await generateVisualization(for: testPayload)
        
        switch result {
        case .success:
            return .success(true)
        case .failure(let error):
            switch error {
            case .apiError(let message) where message.contains("Unauthorized"):
                return .failure(.apiError("Invalid API key"))
            case .networkError:
                return .failure(.networkError("Network connectivity issue"))
            default:
                return .failure(error)
            }
        }
    }
    
    // MARK: - Request Creation
    
    /// Create visualization request for Claude API
    /// - Parameters:
    ///   - dish: Privacy-safe dish data
    ///   - apiKey: API key for authentication
    /// - Returns: Configured URLRequest or error
    private func createVisualizationRequest(for dish: DishAPIPayload, apiKey: String) async -> Result<URLRequest, MenulyError> {
        // Create URL
        guard let url = URL(string: APIConstants.baseURL + APIConstants.messagesEndpoint) else {
            return .failure(.apiError("Invalid API URL"))
        }
        
        // Create request payload
        let requestPayload = createRequestPayload(for: dish)
        
        // Serialize to JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestPayload, options: [])
            
            // Create secure request
            return networkManager.createSecureRequest(
                url: url,
                method: "POST",
                body: jsonData,
                apiKey: apiKey
            )
        } catch {
            return .failure(.jsonParsingError)
        }
    }
    
    /// Create request payload for Claude API
    /// - Parameter dish: Dish data to process
    /// - Returns: Request payload dictionary
    private func createRequestPayload(for dish: DishAPIPayload) -> [String: Any] {
        // Create user prompt with dish data
        let userPrompt = PromptConstants.userPromptTemplate
            .replacingOccurrences(of: "{dishName}", with: dish.name)
            .replacingOccurrences(of: "{dishCategory}", with: dish.category)
            .replacingOccurrences(of: "{dishDescription}", with: dish.description ?? "No description provided")
        
        return [
            "model": APIConstants.model,
            "max_tokens": APIConstants.maxTokens,
            "temperature": APIConstants.temperature,
            "system": PromptConstants.systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ]
        ]
    }
    
    // MARK: - Request Execution
    
    /// Execute API request with retry logic
    /// - Parameter request: URLRequest to execute
    /// - Returns: Result with visualization response or error
    private func executeRequest(_ request: URLRequest) async -> Result<VisualizationAPIResponse, MenulyError> {
        return await withCheckedContinuation { continuation in
            networkManager.performSecureRequestWithRetry(request) { result in
                switch result {
                case .success(let (data, response)):
                    let processedResult = self.processResponse(data: data, response: response)
                    continuation.resume(returning: processedResult)
                case .failure(let error):
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }
    
    // MARK: - Response Processing
    
    /// Process Claude API response
    /// - Parameters:
    ///   - data: Response data
    ///   - response: HTTP response
    /// - Returns: Processed visualization response or error
    private func processResponse(data: Data, response: HTTPURLResponse) -> Result<VisualizationAPIResponse, MenulyError> {
        // Parse JSON response
        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure(.jsonParsingError)
            }
            
            // Handle API errors
            if let error = jsonObject["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                return .failure(.apiError(errorMessage))
            }
            
            // Extract content from Claude response
            guard let content = extractContentFromResponse(jsonObject) else {
                return .failure(.jsonParsingError)
            }
            
            // Parse visualization data
            let visualizationResult = parseVisualizationContent(content)
            
            switch visualizationResult {
            case .success(let visualization):
                let response = VisualizationAPIResponse(
                    success: true,
                    visualization: visualization,
                    error: nil
                )
                return .success(response)
            case .failure(let error):
                return .failure(error)
            }
            
        } catch {
            return .failure(.jsonParsingError)
        }
    }
    
    /// Extract content from Claude API response structure
    /// - Parameter response: Parsed JSON response
    /// - Returns: Content string or nil
    private func extractContentFromResponse(_ response: [String: Any]) -> String? {
        // Claude API response structure: content -> [block] -> text
        guard let content = response["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            return nil
        }
        
        return text
    }
    
    /// Parse visualization content from Claude response
    /// - Parameter content: Raw content string from Claude
    /// - Returns: Parsed visualization data or error
    private func parseVisualizationContent(_ content: String) -> Result<VisualizationAPIResponse.VisualizationData, MenulyError> {
        // Try to extract JSON from Claude's response
        let jsonContent = extractJSONFromContent(content)
        
        do {
            guard let jsonData = jsonContent.data(using: .utf8),
                  let visualization = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return .failure(.jsonParsingError)
            }
            
            // Extract required fields
            guard let description = visualization["description"] as? String,
                  let visualStyle = visualization["visualStyle"] as? String,
                  let ingredients = visualization["ingredients"] as? [String],
                  let preparationNotes = visualization["preparationNotes"] as? String else {
                return .failure(.jsonParsingError)
            }
            
            // Validate content safety
            guard validateContentSafety(description: description, visualStyle: visualStyle, preparationNotes: preparationNotes) else {
                return .failure(.privacyViolation("Content failed safety validation"))
            }
            
            let visualizationData = VisualizationAPIResponse.VisualizationData(
                description: description,
                visualStyle: visualStyle,
                ingredients: ingredients,
                preparationNotes: preparationNotes
            )
            
            return .success(visualizationData)
            
        } catch {
            return .failure(.jsonParsingError)
        }
    }
    
    /// Extract JSON content from Claude's text response
    /// - Parameter content: Full content string
    /// - Returns: JSON string
    private func extractJSONFromContent(_ content: String) -> String {
        // Look for JSON block in response
        if let jsonStart = content.range(of: "{"),
           let jsonEnd = content.range(of: "}", options: .backwards) {
            let jsonRange = jsonStart.lowerBound..<content.index(after: jsonEnd.lowerBound)
            return String(content[jsonRange])
        }
        
        // If no JSON block found, return the content as-is
        return content
    }
    
    /// Validate content for safety and appropriateness
    /// - Parameters:
    ///   - description: Dish description
    ///   - visualStyle: Visual style description
    ///   - preparationNotes: Preparation notes
    /// - Returns: True if content is safe
    private func validateContentSafety(description: String, visualStyle: String, preparationNotes: String) -> Bool {
        let allContent = [description, visualStyle, preparationNotes].joined(separator: " ").lowercased()
        
        // Basic content validation (can be expanded)
        let inappropriateTerms = ["alcohol", "wine", "beer", "liquor", "inappropriate", "unsafe"]
        
        for term in inappropriateTerms {
            if allContent.contains(term) {
                // Allow some food-related alcohol terms in cooking context
                if term.contains("alcohol") && (allContent.contains("cooking") || allContent.contains("sauce")) {
                    continue
                }
                return false
            }
        }
        
        // Validate length limits
        guard description.count <= 500,
              visualStyle.count <= 300,
              preparationNotes.count <= 300 else {
            return false
        }
        
        return true
    }
    
    // MARK: - Utility Methods
    
    /// Get API client status for diagnostics
    /// - Returns: Dictionary with client status information
    func getClientStatus() -> [String: Any] {
        return [
            "apiKeyAvailable": apiKeyManager.hasValidAPIKey(),
            "baseURL": APIConstants.baseURL,
            "model": APIConstants.model,
            "networkSecurity": networkManager.getPrivacyCompliantNetworkStatus(),
            "version": "1.0"
        ]
    }
    
    /// Create privacy-compliant audit log entry
    /// - Parameter operation: The operation performed
    /// - Returns: Privacy-safe audit log entry
    func createAuditLogEntry(for operation: String) -> [String: Any] {
        return [
            "timestamp": Date().timeIntervalSince1970,
            "operation": operation,
            "model": APIConstants.model,
            "apiVersion": APIConstants.apiVersion,
            "client": "ClaudeAPIClient",
            "version": "1.0"
        ]
    }
}

// MARK: - Testing Support

#if DEBUG
extension ClaudeAPIClient {
    
    /// Create test response for development/testing
    /// - Parameter dish: Dish to create test response for
    /// - Returns: Mock visualization response
    func createTestResponse(for dish: DishAPIPayload) -> VisualizationAPIResponse {
        let testVisualization = VisualizationAPIResponse.VisualizationData(
            description: "A beautifully presented \(dish.name) featuring vibrant colors and expert plating that showcases the chef's attention to detail.",
            visualStyle: "Modern plating with clean lines and artistic garnish arrangement",
            ingredients: ["fresh herbs", "seasonal vegetables", "premium protein"],
            preparationNotes: "Carefully prepared using traditional techniques with a contemporary presentation"
        )
        
        return VisualizationAPIResponse(
            success: true,
            visualization: testVisualization,
            error: nil
        )
    }
    
    /// Validate prompt structure for testing
    /// - Parameter dish: Dish to validate prompt for
    /// - Returns: Generated prompt string
    func validatePromptGeneration(for dish: DishAPIPayload) -> String {
        return PromptConstants.userPromptTemplate
            .replacingOccurrences(of: "{dishName}", with: dish.name)
            .replacingOccurrences(of: "{dishCategory}", with: dish.category)
            .replacingOccurrences(of: "{dishDescription}", with: dish.description ?? "No description provided")
    }
}
#endif