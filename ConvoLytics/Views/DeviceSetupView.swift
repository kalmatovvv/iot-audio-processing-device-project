import SwiftUI

struct DeviceSetupView: View {
    @ObservedObject var viewModel: ConversationViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var wifiSsid = "HomeNetwork_5G"
    @State private var isConfiguringWifi = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Drag indicator / header
                headerBar
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Device pairing status toggle
                        devicePairingCard
                        
                        // Technical Flow Chart Diagram
                        flowDiagramSection
                        
                        // Step-by-Step guide
                        hardwareGuideSection
                        
                        // Cloud credentials panel
                        settingsPanel
                        
                        Color.clear.frame(height: 30)
                    }
                    .padding()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            Text("DEVICE CONTROL")
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .tracking(2)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(white: 0.3))
            }
        }
        .padding()
        .background(Color(white: 0.05))
    }
    
    // MARK: - Pairing Card
    private var devicePairingCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONVOLYTICS PROTOTYPE")
                        .font(.system(.headline))
                        .fontWeight(.bold)
                    Text(viewModel.isDeviceConnected ? "Connected via Bluetooth LE" : "Disconnected")
                        .font(.system(.caption))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Connection toggle switch
                Toggle("", isOn: Binding(
                    get: { viewModel.isDeviceConnected },
                    set: { _ in viewModel.toggleDeviceConnection() }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .white))
            }
            
            Divider()
                .background(Color(white: 0.16))
            
            if viewModel.isDeviceConnected {
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Image(systemName: "battery.75")
                            .foregroundColor(.white)
                        Text("\(viewModel.deviceBatteryLevel)% Power")
                            .font(.system(.caption, design: .monospaced))
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "wifi")
                            .foregroundColor(.white)
                        Text(wifiSsid)
                            .font(.system(.caption, design: .monospaced))
                    }
                    
                    Spacer()
                }
                .foregroundColor(.gray)
            } else {
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundColor(.gray)
                    Text("Searching for ConvoLytics nearby...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .background(Color(white: 0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.18), lineWidth: 1)
        )
    }
    
    // MARK: - Flow Chart
    private var flowDiagramSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DATA PIPELINE SCHEMATIC")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
                .fontWeight(.bold)
                .tracking(1)
            
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    DiagramNode(icon: "mic.fill", label: "Mic Device", sublabel: "WAV Audio")
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundColor(.gray)
                    Spacer()
                    DiagramNode(icon: "icloud.and.arrow.up", label: "AWS S3", sublabel: "Storage Bucket")
                    Spacer()
                }
                
                Image(systemName: "arrow.down")
                    .foregroundColor(.gray)
                    .padding(.vertical, 2)
                
                HStack {
                    Spacer()
                    DiagramNode(icon: "sparkles", label: "AI Backend", sublabel: "Whisper & LLM")
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundColor(.gray)
                    Spacer()
                    DiagramNode(icon: "iphone", label: "Mobile App", sublabel: "Conversations Feed")
                    Spacer()
                }
            }
            .padding(16)
            .background(Color(white: 0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(white: 0.14), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Hardware Guide
    private var hardwareGuideSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("HARDWARE OPERATIONAL GUIDE")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
                .fontWeight(.bold)
                .tracking(1)
            
            VStack(spacing: 12) {
                GuideStepRow(step: "1", title: "Power on the Mic", description: "Hold the power slider on the bottom. The indicator LED will pulse white, signaling standard standby mode.")
                
                GuideStepRow(step: "2", title: "Single-Tap to Record", description: "Click the main action button once to begin recording. The LED turns solid white to confirm recording.")
                
                GuideStepRow(step: "3", title: "Tap Again to Upload", description: "Click the action button a second time to stop. The audio chunk immediately streams over Wi-Fi to the cloud.")
                
                GuideStepRow(step: "4", title: "Automatic App Refresh", description: "The server runs Whisper transcription and LLM semantic breakdown, pushing the new entry directly to this feed.")
            }
        }
    }
    
    // MARK: - Settings Panel
    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEVICE CONFIGURATION")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
                .fontWeight(.bold)
                .tracking(1)
            
            VStack(spacing: 16) {
                // Wi-Fi settings row
                HStack {
                    Text("Device Wi-Fi Network")
                        .font(.system(.body))
                    Spacer()
                    Text(wifiSsid)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Divider()
                    .background(Color(white: 0.16))
                
                // Cloud Sync Endpoints
                HStack {
                    Text("AWS S3 Target Region")
                        .font(.system(.body))
                    Spacer()
                    Text("us-east-1 (Virginia)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Divider()
                    .background(Color(white: 0.16))
                
                HStack {
                    Text("API Sync Status")
                        .font(.system(.body))
                    Spacer()
                    Text("Connected")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(18)
            .background(Color(white: 0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(white: 0.18), lineWidth: 1)
            )
        }
    }
}

// MARK: - Subcomponents
struct DiagramNode: View {
    var icon: String
    var label: String
    var sublabel: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color(white: 0.15))
                .clipShape(Circle())
            
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
            
            Text(sublabel)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
        }
        .frame(width: 95)
    }
}

struct GuideStepRow: View {
    var step: String
    var title: String
    var description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(step)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .background(Color.white)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.body))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(.subheadline))
                    .foregroundColor(.gray)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(white: 0.06))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(white: 0.15), lineWidth: 1)
        )
    }
}
#Preview {
    DeviceSetupView(viewModel: ConversationViewModel())
}
