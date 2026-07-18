import Foundation

struct ChatMessage: Identifiable, Codable, Hashable, Equatable {
    var id = UUID()
    var role: String // "user" or "assistant"
    var content: String
    
    // Mapping keys to ensure matching payloads with Python backend
    enum CodingKeys: String, CodingKey {
        case role
        case content
    }
}
