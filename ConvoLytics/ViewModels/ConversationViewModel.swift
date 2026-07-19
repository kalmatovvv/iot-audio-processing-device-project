import Foundation
import Combine
import SwiftUI

@MainActor
class ConversationViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    
    // Hardware State Simulation
    @Published var isDeviceConnected: Bool = true
    @Published var deviceBatteryLevel: Int = 92
    @Published var simulatedStatus: Conversation.Status = .ready
    
    // Recording Timer Simulation
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var audioLevels: [CGFloat] = Array(repeating: 0.1, count: 20)
    
    private var recordingTimer: Timer?
    private var waveTimer: Timer?
    
    // Sample titles and templates for high-fidelity simulations
    private let mockSpeechTemplates: [(title: String, transcript: String, summary: String, keyPoints: [String], actionItems: [String], tags: [String])] = [
        (
            title: "Seed Round Pitch Deck Review",
            transcript: "Alright, let's review the pitch deck for our seed round. Slide 3 needs a clearer market size diagram—let's make sure we highlight the TAM of 24 billion. For slide 5, the competitive analysis grid is too cluttered. We should simplify it to show just our 3 main differentiators. Dave, can you handle the financials slide update by Thursday? And Sarah, let's schedule a dry run of the pitch with the team next Monday at 10 AM.",
            summary: "Discussion covering revisions for the seed round pitch deck. Key focus areas include clarifying the market size diagram, simplifying the competitive grid, and assigning task owners for financials and presentation dry runs.",
            keyPoints: [
                "Market size (TAM) needs to highlight the $24B opportunity on Slide 3.",
                "Competitive grid on Slide 5 is too busy and needs to focus on 3 key differentiators.",
                "Financial projections slide requires an update."
            ],
            actionItems: [
                "Update financial projections slide (Dave) - Due Thursday",
                "Simplify competitive grid on Slide 5 (Sarah)",
                "Schedule pitch dry run for next Monday at 10 AM (Sarah)"
            ],
            tags: ["Pitch", "Finance", "Strategy"]
        ),
        (
            title: "Smart Home Automated Lighting",
            transcript: "I want to automate the lighting in the living room and kitchen. Let's make it so when the motion sensor detects activity between 7 PM and 11 PM, the lights turn on to a warm 30 percent brightness. If it's after midnight, they should only turn on at 5 percent to avoid waking anyone up. Also, we need to buy two more Zigbee motion sensors and a smart dimmer plug for the standing lamp. Let's do the installation this Saturday afternoon.",
            summary: "Planning motion-activated smart lighting rules for the living room and kitchen. The user detailed time-specific brightness levels and planned to purchase additional Zigbee sensors for a weekend install.",
            keyPoints: [
                "Evening lighting set to 30% warm brightness (7 PM - 11 PM).",
                "Night-time lighting capped at 5% brightness to minimize disruption.",
                "System will run on Zigbee protocol via smart sensors."
            ],
            actionItems: [
                "Order 2 Zigbee motion sensors online.",
                "Purchase smart dimmer plug for the standing lamp.",
                "Configure Home Assistant automations on Saturday."
            ],
            tags: ["IoT", "Home", "DIY"]
        ),
        (
            title: "Weekly Grocery & Meal Prep",
            transcript: "Let's plan meals for next week. I was thinking of doing lemon herb chicken with roasted asparagus on Monday and Wednesday, and a big batch of vegetarian chili for Tuesday and Thursday. For breakfasts, we can stick to oatmeal and chia pudding. We need to buy chicken breasts, asparagus, lemons, black beans, canned tomatoes, chili powder, and avocados. Let's do the grocery shopping tomorrow morning before work.",
            summary: "Weekly meal plan outlining lunch and dinner prep featuring lemon herb chicken and vegetarian chili. A shopping list was compiled for a grocery run scheduled for tomorrow morning.",
            keyPoints: [
                "Meal prep planned for Monday through Thursday (Chicken & Chili).",
                "Breakfasts standardized around oats and chia seeds for efficiency.",
                "Shopping list finalized to avoid excess food waste."
            ],
            actionItems: [
                "Check pantry for spices and canned tomatoes.",
                "Buy fresh chicken, lemons, asparagus, and avocados.",
                "Prepare oatmeal and chia batches on Sunday evening."
            ],
            tags: ["Life", "Health", "Meal Prep"]
        ),
        (
            title: "Product Launch Marketing Campaign",
            transcript: "Our product launch is in three weeks, and we need to lock down the marketing plan. First, let's schedule three teaser posts on Instagram and LinkedIn for next week. Second, we need to draft the official press release and send it to our PR contact by Friday. Finally, we should set up a landing page with an email capture form to build a waitlist. We need to run some Google search ads with a 500 dollar budget to drive traffic.",
            summary: "Strategic discussion detailing the three-week countdown to the product launch. The marketing plan focuses on social media teasers, a press release draft, waitlist page launch, and search ad budgets.",
            keyPoints: [
                "Product release date set in 3 weeks.",
                "Teaser campaigns scheduled across Instagram and LinkedIn.",
                "Marketing acquisition relies on a pre-launch email waitlist landing page."
            ],
            actionItems: [
                "Draft press release and send to PR (Marketing team) - Due Friday",
                "Build landing page with email capture (Engineering) - Due next Tuesday",
                "Set up Google Ads campaign with $500 budget (Dave)"
            ],
            tags: ["Marketing", "Launch", "Product"]
        )
    ]
    
    private var cancellables = Set<AnyCancellable>()
    @Published var isLoading: Bool = false

    // Target endpoint URL of your deployed AWS API Gateway
    private let conversationsEndpoint = "https://4mbvl3522i.execute-api.us-west-1.amazonaws.com/conversations"

    init() {
        // Start with an empty list so mock conversations do not flash on launch
        self.conversations = []
        // Sync real recordings from the DynamoDB database
        fetchConversations()
    }

    func fetchConversations() {
        guard let url = URL(string: conversationsEndpoint) else { return }
        
        isLoading = true
        let startTime = Date()
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [Conversation].self, decoder: {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return decoder
            }())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                let remainingDelay = max(0.0, 3.0 - elapsed)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + remainingDelay) {
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        print("Error fetching conversations from cloud: \(error)")
                    }
                }
            } receiveValue: { [weak self] fetchedConversations in
                guard let self = self else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                let remainingDelay = max(0.0, 3.0 - elapsed)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + remainingDelay) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.conversations = fetchedConversations
                    }
                }
            }
            .store(in: &cancellables)
    }

    
    // MARK: - Simulation Controls
    
    func startSimulatedRecording() {
        guard simulatedStatus == .ready else { return }
        
        simulatedStatus = .recording
        recordingDuration = 0.0
        audioLevels = Array(repeating: 0.1, count: 20)
        
        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingDuration += 1.0
        }
        
        // Start audio waveform timer
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            for i in 0..<self.audioLevels.count {
                // Generate natural-looking wave heights between 0.15 and 0.95
                let change = CGFloat.random(in: -0.2...0.2)
                let newValue = max(0.1, min(0.9, (self.audioLevels[i] + change)))
                self.audioLevels[i] = newValue
            }
        }
    }
    
    func stopSimulatedRecording() {
        guard simulatedStatus == .recording else { return }
        
        recordingTimer?.invalidate()
        waveTimer?.invalidate()
        recordingTimer = nil
        waveTimer = nil
        
        let finalDuration = recordingDuration > 0 ? recordingDuration : Double.random(in: 15...45)
        
        // Step 1: Transcribing
        simulatedStatus = .transcribing
        
        // Simulate Transcription delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            // Step 2: Analyzing
            self.simulatedStatus = .analyzing
            
            // Simulate AI Analysis delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                // Randomly select a template to create a new conversation card
                let template = self.mockSpeechTemplates.randomElement() ?? self.mockSpeechTemplates[0]
                
                let newConversation = Conversation(
                    title: template.title,
                    date: Date(),
                    duration: finalDuration,
                    transcript: template.transcript,
                    summary: template.summary,
                    keyPoints: template.keyPoints,
                    actionItems: template.actionItems,
                    tags: template.tags,
                    status: .completed
                )
                
                // Add to list
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.conversations.insert(newConversation, at: 0)
                }
                
                // Reset state
                self.simulatedStatus = .ready
            }
        }
    }
    
    func toggleDeviceConnection() {
        withAnimation {
            isDeviceConnected.toggle()
            if isDeviceConnected {
                deviceBatteryLevel = Int.random(in: 60...100)
            } else {
                simulatedStatus = .ready
                recordingTimer?.invalidate()
                waveTimer?.invalidate()
                recordingTimer = nil
                waveTimer = nil
            }
        }
    }
    
    func deleteConversation(at offsets: IndexSet) {
        for index in offsets {
            let conversation = conversations[index]
            deleteConversationFromServer(id: conversation.id.uuidString.lowercased())
        }
        conversations.remove(atOffsets: offsets)
    }
    
    private func deleteConversationFromServer(id: String) {
        guard let url = URL(string: "\(conversationsEndpoint)?id=\(id)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        print("Sending DELETE request for conversation: \(id)")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error deleting conversation from server: \(error)")
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Successfully deleted conversation \(id) from server.")
            } else {
                print("Failed to delete conversation \(id) from server. Status: \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
            }
        }.resume()
    }

}
