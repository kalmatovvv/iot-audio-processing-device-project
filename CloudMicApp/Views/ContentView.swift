import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ConversationViewModel()
    @State private var showingSetup = false
    @State private var selectedConversation: Conversation?
    
    var body: some View {
        NavigationStack {
            ZKeyframeView(viewModel: viewModel, showingSetup: $showingSetup, selectedConversation: $selectedConversation)
                .navigationDestination(for: Conversation.self) { convo in
                    ConversationDetailView(conversation: convo)
                }
                .sheet(isPresented: $showingSetup) {
                    DeviceSetupView(viewModel: viewModel)
                }
        }
    }
}

// Inner View containing the structural elements
struct ZKeyframeView: View {
    @ObservedObject var viewModel: ConversationViewModel
    @Binding var showingSetup: Bool
    @Binding var selectedConversation: Conversation?
    
    var body: some View {
        ZStack {
            // Dark elegant background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                headerView
                
                // Active Device Status bar
                deviceStatusBar
                
                // Conversations Feed
                if viewModel.conversations.isEmpty {
                    ScrollView {
                        emptyFeedView
                            .frame(minHeight: 500)
                    }
                    .refreshable {
                        viewModel.fetchConversations()
                    }
                } else {
                    feedListView
                }
            }
            
            // Simulation Controls Overlay
            simulationOverlay
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("CLOUDMIC")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .tracking(2)
                
                Text("Conversations")
                    .font(.system(.title, design: .default))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Device Settings Button
            Button(action: { showingSetup = true }) {
                Image(systemName: "cpu")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(white: 0.12))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color(white: 0.2), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 15)
    }
    
    // MARK: - Device Status Bar
    private var deviceStatusBar: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isDeviceConnected ? Color.white : Color.gray)
                    .frame(width: 8, height: 8)
                    .shadow(color: viewModel.isDeviceConnected ? .white.opacity(0.5) : .clear, radius: 4)
                
                Text(viewModel.isDeviceConnected ? "MIC_PROTOTYPE_01" : "DEVICE DISCONNECTED")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.isDeviceConnected ? .white : .gray)
            }
            
            Spacer()
            
            if viewModel.isDeviceConnected {
                HStack(spacing: 4) {
                    Image(systemName: "battery.100")
                        .font(.system(size: 11))
                    Text("\(viewModel.deviceBatteryLevel)%")
                        .font(.system(.caption2, design: .monospaced))
                }
                .foregroundColor(.gray)
            } else {
                Text("Tap to pair")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
                    .underline()
                    .onTapGesture {
                        showingSetup = true
                    }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(white: 0.06))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(white: 0.15), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.bottom, 15)
    }
    
    // MARK: - Empty Feed
    private var emptyFeedView: some View {
        VStack(spacing: 15) {
            Spacer()
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No conversations synchronized yet")
                .font(.system(.headline))
                .foregroundColor(.white)
            Text("Power on your CloudMic and press the button to record. The transcription will appear here automatically.")
                .font(.system(.subheadline))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
    
    // MARK: - Conversations List
    private var feedListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.conversations) { convo in
                    NavigationLink(value: convo) {
                        ConversationCard(conversation: convo)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            if let index = viewModel.conversations.firstIndex(where: { $0.id == convo.id }) {
                                withAnimation {
                                    viewModel.deleteConversation(at: IndexSet(integer: index))
                                }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                // Add padding at bottom to prevent floating action overlaps
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal)
        }
        .refreshable {
            viewModel.fetchConversations()
        }
    }

    
    // MARK: - Simulation Overlay Widget
    private var simulationOverlay: some View {
        VStack {
            Spacer()
            
            if viewModel.simulatedStatus != .ready {
                VStack(spacing: 16) {
                    // Title block based on state
                    HStack {
                        Image(systemName: stateIcon(for: viewModel.simulatedStatus))
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .bold))
                            .modifier(StatusPulseModifier(status: viewModel.simulatedStatus))
                        
                        Text(viewModel.simulatedStatus.rawValue.uppercased())
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if viewModel.simulatedStatus == .recording {
                            Text(formatDuration(viewModel.recordingDuration))
                                .font(.system(.headline, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Waveform for recording
                    if viewModel.simulatedStatus == .recording {
                        HStack(spacing: 3) {
                            ForEach(0..<viewModel.audioLevels.count, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white)
                                    .frame(width: 4, height: max(6, viewModel.audioLevels[index] * 40))
                                    .animation(.spring(response: 0.15, dampingFraction: 0.5), value: viewModel.audioLevels[index])
                            }
                        }
                        .frame(height: 50)
                        
                        Button(action: {
                            viewModel.stopSimulatedRecording()
                        }) {
                            Text("FINISH & SYNC")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .cornerRadius(8)
                        }
                    } else {
                        // Progress loading indicator steps for Transcribing/Analyzing
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressRow(title: "WAV package uploaded to AWS S3", isDone: true)
                            ProgressRow(title: "Running Whisper V3 transcription", isDone: viewModel.simulatedStatus == .analyzing)
                            ProgressRow(title: "Analyzing semantics with AI breakdown", isDone: false)
                        }
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                            .padding(.vertical, 5)
                    }
                }
                .padding(20)
                .background(Color(white: 0.08))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(white: 0.2), lineWidth: 1)
                )
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .shadow(color: .black.opacity(0.8), radius: 20, y: 10)
            } else if viewModel.isDeviceConnected {
                // Floating Sim Trigger button when idle and device is paired
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        viewModel.startSimulatedRecording()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                        Text("SIMULATE RECORDING")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .white.opacity(0.15), radius: 10, y: 5)
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func stateIcon(for status: Conversation.Status) -> String {
        switch status {
        case .recording: return "waveform"
        case .transcribing: return "arrow.up.circle"
        case .analyzing: return "sparkles"
        default: return "hourglass"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Progress Row View
struct ProgressRow: View {
    var title: String
    var isDone: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isDone ? .white : .gray)
                .font(.system(size: 13))
            
            Text(title)
                .font(.system(.caption, design: .default))
                .foregroundColor(isDone ? .white : .gray)
            
            Spacer()
        }
    }
}

// MARK: - Pulse Animation Modifier
struct StatusPulseModifier: ViewModifier {
    var status: Conversation.Status
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                if status == .recording {
                    withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        scale = 1.3
                    }
                }
            }
    }
}

// MARK: - Card Component
struct ConversationCard: View {
    var conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Row (Title & Date)
            HStack(alignment: .top) {
                Text(conversation.title)
                    .font(.system(.headline))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Spacer()
                
                Text(conversation.formattedDate)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            // Summary Text
            Text(conversation.summary)
                .font(.system(.subheadline))
                .foregroundColor(Color(white: 0.7))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .padding(.bottom, 4)
            
            // Bottom Metadata row
            HStack {
                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(conversation.formattedDuration)
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundColor(.gray)
                
                Spacer()
                
                // Tags
                HStack(spacing: 6) {
                    ForEach(conversation.tags.prefix(3), id: \.self) { tag in
                        Text(tag.uppercased())
                            .font(.system(size: 9, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(white: 0.15))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(white: 0.25), lineWidth: 0.5)
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.16), lineWidth: 1)
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
