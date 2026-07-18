import SwiftUI

struct ConversationDetailView: View {
    var conversation: Conversation
    
    @State private var selectedTab: Int = 0 // 0 = Breakdown, 1 = Transcript, 2 = Chat
    @State private var isPlaying: Bool = false
    @State private var audioProgress: CGFloat = 0.35 // Mock current progress
    @State private var playbackSpeed: Double = 1.0 // 1.0, 1.5, 2.0
    @State private var completedActionItems: Set<String> = []
    
    // AI Chat Agent State
    @State private var messages: [ChatMessage] = []
    @State private var chatInput: String = ""
    @State private var isSending: Bool = false
    
    // Environment dismiss to support custom back button pop
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Elegant background
            Color.black.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                // 1. Pinned Top Section (Non-scrolling)
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    audioPlayerSection
                    tabSelector
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 2. Tab Contents (Dynamically scrollable depending on active tab)
                if selectedTab == 0 {
                    ScrollView {
                        breakdownTab
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                } else if selectedTab == 1 {
                    ScrollView {
                        transcriptTab
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                } else {
                    chatTab
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
            }
        }

        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            loadChatHistory()
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Back button and metadata inline row
            HStack(spacing: 12) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Back")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(white: 0.08))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(white: 0.22), lineWidth: 1)
                    )
                }
                
                // Date inline next to back button
                Text(conversation.formattedDate)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Tags
                HStack(spacing: 6) {
                    ForEach(conversation.tags, id: \.self) { tag in
                        Text(tag.uppercased())
                            .font(.system(size: 8, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(white: 0.12))
                            .cornerRadius(4)
                    }
                }
            }
            
            Text(conversation.title)
                .font(.system(.title3, design: .default))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(2)
        }
    }
    
    // MARK: - Audio Player
    private var audioPlayerSection: some View {
        HStack(spacing: 12) {
            // Play / Pause
            Button(action: {
                isPlaying.toggle()
            }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 36, height: 36)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            
            // Rewind 15s
            Button(action: {
                audioProgress = max(0.0, audioProgress - (15.0 / conversation.duration))
            }) {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }
            
            // Progress Bar & Timestamps
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(white: 0.16))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geo.size.width * audioProgress, height: 4)
                        
                        // Scrub handle
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .offset(x: geo.size.width * audioProgress - 5)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let percentage = value.location.x / geo.size.width
                                        audioProgress = max(0.0, min(1.0, percentage))
                                    }
                            )
                    }
                }
                .frame(height: 10)
                
                HStack {
                    let elapsed = conversation.duration * Double(audioProgress)
                    let remaining = conversation.duration - elapsed
                    
                    Text(formatTime(elapsed))
                        .font(.system(size: 9, design: .monospaced))
                    Spacer()
                    Text("-" + formatTime(remaining))
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(.gray)
            }
            
            // Fast Forward 15s
            Button(action: {
                audioProgress = min(1.0, audioProgress + (15.0 / conversation.duration))
            }) {
                Image(systemName: "goforward.15")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }
            
            // Speed Controller
            Button(action: {
                if playbackSpeed == 1.0 {
                    playbackSpeed = 1.5
                } else if playbackSpeed == 1.5 {
                    playbackSpeed = 2.0
                } else {
                    playbackSpeed = 1.0
                }
            }) {
                Text(String(format: "%.1fx", playbackSpeed))
                    .font(.system(size: 9, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 22)
                    .background(Color(white: 0.12))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(white: 0.2), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(white: 0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.14), lineWidth: 1)
        )
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            Button(action: { selectedTab = 0 }) {
                VStack(spacing: 8) {
                    Text("BREAKDOWN")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(selectedTab == 0 ? .white : .gray)
                    
                    Rectangle()
                        .fill(selectedTab == 0 ? Color.white : Color.clear)
                        .frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity)
            
            Button(action: { selectedTab = 1 }) {
                VStack(spacing: 8) {
                    Text("TRANSCRIPT")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(selectedTab == 1 ? .white : .gray)
                    
                    Rectangle()
                        .fill(selectedTab == 1 ? Color.white : Color.clear)
                        .frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity)
            
            Button(action: { selectedTab = 2 }) {
                VStack(spacing: 8) {
                    Text("CHAT")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(selectedTab == 2 ? .white : .gray)
                    
                    Rectangle()
                        .fill(selectedTab == 2 ? Color.white : Color.clear)
                        .frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Breakdown Tab
    private var breakdownTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Executive Summary
            VStack(alignment: .leading, spacing: 10) {
                Text("EXECUTIVE SUMMARY")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                    .fontWeight(.bold)
                    .tracking(1)
                
                Text(conversation.summary)
                    .font(.system(.body))
                    .foregroundColor(Color(white: 0.85))
                    .lineSpacing(4)
                    .padding(16)
                    .background(Color(white: 0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(white: 0.14), lineWidth: 1)
                    )
            }
            
            if let answer = conversation.answer, !answer.isEmpty {
                // QA Answer Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("ASSISTANT RESPONSE")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                        .fontWeight(.bold)
                        .tracking(1)
                    
                    Text(answer)
                        .font(.system(.body))
                        .foregroundColor(Color(white: 0.95))
                        .lineSpacing(4)
                        .padding(16)
                        .background(Color(white: 0.08))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(white: 0.18), lineWidth: 1)
                        )
                }
            }
            
            // Key Takeaways

            VStack(alignment: .leading, spacing: 12) {
                Text("KEY TAKEAWAYS")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                    .fontWeight(.bold)
                    .tracking(1)
                
                ForEach(conversation.keyPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 12) {
                        Text("—")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.gray)
                        Text(point)
                            .font(.system(.body))
                            .foregroundColor(Color(white: 0.8))
                    }
                    .padding(.bottom, 2)
                }
            }
            
            // Action Items
            VStack(alignment: .leading, spacing: 12) {
                Text("ACTION ITEMS")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                    .fontWeight(.bold)
                    .tracking(1)
                
                if conversation.actionItems.isEmpty {
                    Text("No action items detected by AI.")
                        .font(.system(.body))
                        .foregroundColor(.gray)
                } else {
                    ForEach(conversation.actionItems, id: \.self) { item in
                        let isCompleted = completedActionItems.contains(item)
                        HStack(alignment: .top, spacing: 12) {
                            Button(action: {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                    if isCompleted {
                                        completedActionItems.remove(item)
                                    } else {
                                        completedActionItems.insert(item)
                                    }
                                }
                            }) {
                                Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 18))
                                    .foregroundColor(isCompleted ? .white : .gray)
                            }
                            
                            Text(item)
                                .font(.system(.body))
                                .foregroundColor(isCompleted ? .gray : Color(white: 0.8))
                                .strikethrough(isCompleted, color: .gray)
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
            // Dynamic spacing padding
            Color.clear.frame(height: 50)
        }
    }
    
    // MARK: - Transcript Tab
    private var transcriptTab: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("FULL DIALOGUE")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
                .fontWeight(.bold)
                .tracking(1)
            
            Text(conversation.transcript)
                .font(.system(.body))
                .foregroundColor(Color(white: 0.85))
                .lineSpacing(6)
                .padding(16)
                .background(Color(white: 0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(white: 0.14), lineWidth: 1)
                )
            
            // Dynamic spacing padding
            Color.clear.frame(height: 50)
        }
    }
    
    // MARK: - Helper Formatting
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    // MARK: - Chat Tab
    private var chatTab: some View {
        VStack(spacing: 12) {
            HStack {
                Text("AI CHAT ASSISTANT")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                    .fontWeight(.bold)
                    .tracking(1)
                
                Spacer()
                
                if !messages.isEmpty {
                    Button(action: {
                        withAnimation {
                            messages.removeAll()
                        }
                        saveChatHistory()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            if messages.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    Text("Ask a Question")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                    Text("I can summarize, clarify details, or answer specific questions about this recording.")
                        .font(.system(.caption))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .background(Color(white: 0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(white: 0.12), lineWidth: 1)
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(messages) { message in
                                HStack {
                                    if message.role == "user" {
                                        Spacer()
                                        Text(message.content)
                                            .font(.system(.body))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color(white: 0.15))
                                            .cornerRadius(14)
                                            .padding(.leading, 40)
                                    } else {
                                        Text(message.content)
                                            .font(.system(.body))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color(red: 0.1, green: 0.45, blue: 0.9)) // Antigravity IDE Blue
                                            .cornerRadius(14)
                                            .padding(.trailing, 40)
                                        Spacer()
                                    }
                                }
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: message.role == "user" ? .trailing : .leading).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .onChange(of: messages) { _ in
                        if let last = messages.last {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Bottom Send Input Bar
            HStack(spacing: 8) {
                TextField("Ask assistant...", text: $chatInput)
                    .font(.system(.body))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(white: 0.18), lineWidth: 1)
                    )
                    .disabled(isSending)
                
                Button(action: {
                    sendChatMessage()
                }) {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .frame(width: 44, height: 40)
                            .background(Color.white)
                            .cornerRadius(8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 40)
                            .background(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            
            Color.clear.frame(height: 10)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func sendChatMessage() {
        let trimmed = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMessage = ChatMessage(role: "user", content: trimmed)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            messages.append(userMessage)
        }
        saveChatHistory()
        chatInput = ""
        isSending = true
        
        // Target backend chat API Gateway URL
        let chatEndpoint = "https://4mbvl3522i.execute-api.us-west-1.amazonaws.com/chat"
        guard let url = URL(string: chatEndpoint) else {
            isSending = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct ChatPayload: Codable {
            var conversationId: String
            var message: String
            var history: [ChatMessage]
        }
        
        let payload = ChatPayload(
            conversationId: conversation.id.uuidString.lowercased(),
            message: userMessage.content,
            history: Array(messages.dropLast())
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("Failed to encode payload: \(error)")
            isSending = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSending = false
                
                if let error = error {
                    print("Network error sending chat: \(error)")
                    let errorMsg = ChatMessage(role: "assistant", content: "Error: Unable to connect to assistant.")
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        self.messages.append(errorMsg)
                    }
                    self.saveChatHistory()
                    return
                }
                
                guard let data = data else { return }
                
                struct ChatResponse: Codable {
                    var reply: String
                }
                
                do {
                    let res = try JSONDecoder().decode(ChatResponse.self, from: data)
                    let assistantReply = ChatMessage(role: "assistant", content: res.reply)
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        self.messages.append(assistantReply)
                    }
                    self.saveChatHistory()
                } catch {
                    print("Failed to decode reply: \(error). Raw: \(String(data: data, encoding: .utf8) ?? "")")
                    let errorMsg = ChatMessage(role: "assistant", content: "Error: Failed to process assistant response.")
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        self.messages.append(errorMsg)
                    }
                    self.saveChatHistory()
                }
            }
        }.resume()
    }
    
    // MARK: - Local Chat Persistence (24 Hour Expiry)
    private struct PersistedChat: Codable {
        var timestamp: Date
        var messages: [ChatMessage]
    }
    
    private func loadChatHistory() {
        let key = "chat_history_\(conversation.id.uuidString.lowercased())"
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        
        do {
            let persisted = try JSONDecoder().decode(PersistedChat.self, from: data)
            let elapsed = Date().timeIntervalSince(persisted.timestamp)
            
            // Limit to 24 hours (24 * 60 * 60 seconds)
            if elapsed < 24 * 60 * 60 {
                self.messages = persisted.messages
            } else {
                UserDefaults.standard.removeObject(forKey: key)
                print("Local chat history for \(conversation.id) expired and was cleared.")
            }
        } catch {
            print("Failed to decode persisted chat: \(error)")
        }
    }
    
    private func saveChatHistory() {
        let key = "chat_history_\(conversation.id.uuidString.lowercased())"
        if messages.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        
        let persisted = PersistedChat(timestamp: Date(), messages: messages)
        do {
            let data = try JSONEncoder().encode(persisted)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to serialize/save chat history: \(error)")
        }
    }
}

struct ConversationDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationDetailView(conversation: Conversation.mockConversations[0])
    }
}
