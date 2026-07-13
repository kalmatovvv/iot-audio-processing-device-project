import SwiftUI

struct ConversationDetailView: View {
    var conversation: Conversation
    
    @State private var selectedTab: Int = 0 // 0 = Breakdown, 1 = Transcript
    @State private var isPlaying: Bool = false
    @State private var audioProgress: CGFloat = 0.35 // Mock current progress
    @State private var playbackSpeed: Double = 1.0 // 1.0, 1.5, 2.0
    @State private var completedActionItems: Set<String> = []
    
    var body: some View {
        ZStack {
            // Elegant background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title and Metadata Block
                        headerSection
                        
                        // Audio Player section
                        audioPlayerSection
                        
                        // Tab Selector
                        tabSelector
                        
                        // Tab Contents
                        if selectedTab == 0 {
                            breakdownTab
                        } else {
                            transcriptTab
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date & Tags
            HStack {
                Text(conversation.formattedDate)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Tags
                HStack(spacing: 6) {
                    ForEach(conversation.tags, id: \.self) { tag in
                        Text(tag.uppercased())
                            .font(.system(size: 9, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(white: 0.12))
                            .cornerRadius(4)
                    }
                }
            }
            
            Text(conversation.title)
                .font(.system(.title2, design: .default))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(3)
        }
    }
    
    // MARK: - Audio Player
    private var audioPlayerSection: some View {
        VStack(spacing: 12) {
            // Progress Bar
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
                        .frame(width: 12, height: 12)
                        .offset(x: geo.size.width * audioProgress - 6)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let percentage = value.location.x / geo.size.width
                                    audioProgress = max(0.0, min(1.0, percentage))
                                }
                        )
                }
            }
            .frame(height: 12)
            
            // Timestamps
            HStack {
                let elapsed = conversation.duration * Double(audioProgress)
                let remaining = conversation.duration - elapsed
                
                Text(formatTime(elapsed))
                    .font(.system(.caption, design: .monospaced))
                
                Spacer()
                
                Text("-" + formatTime(remaining))
                    .font(.system(.caption, design: .monospaced))
            }
            .foregroundColor(.gray)
            
            // Player Controls
            HStack(spacing: 40) {
                // Rewind 15s
                Button(action: {
                    audioProgress = max(0.0, audioProgress - (15.0 / conversation.duration))
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                // Play / Pause
                Button(action: {
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.black)
                        .frame(width: 60, height: 60)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                
                // Fast Forward 15s
                Button(action: {
                    audioProgress = min(1.0, audioProgress + (15.0 / conversation.duration))
                }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, 8)
            .overlay(alignment: .trailing) {
                // Playback speed controller
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
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 26)
                        .background(Color(white: 0.12))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(white: 0.2), lineWidth: 1)
                        )
                }
                .padding(.trailing, 10)
            }
        }
        .padding(20)
        .background(Color(white: 0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(white: 0.15), lineWidth: 1)
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
}

struct ConversationDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationDetailView(conversation: Conversation.mockConversations[0])
    }
}
