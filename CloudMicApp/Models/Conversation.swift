import Foundation

struct Conversation: Identifiable, Codable, Hashable {
    enum Status: String, Codable, Hashable {
        case ready = "Ready"
        case recording = "Recording..."
        case transcribing = "Transcribing..."
        case analyzing = "Analyzing..."
        case completed = "Synced & Analyzed"
        case failed = "Failed"
    }

    var id = UUID()
    var title: String
    var date: Date
    var duration: TimeInterval
    var transcript: String
    var summary: String
    var keyPoints: [String]
    var actionItems: [String]
    var tags: [String]
    var status: Status
    var answer: String?

    
    // Formatted date string helper
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Formatted duration helper (e.g. "02:45")
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// Extension to provide robust mock data for initial load
extension Conversation {
    static var mockConversations: [Conversation] {
        return [
            Conversation(
                title: "Voice Mic App Design & Color Palette",
                date: Date().addingTimeInterval(-3600 * 2), // 2 hours ago
                duration: 84, // 1m 24s
                transcript: "Let's align on the aesthetic for the new iOS app. I really want a super modern feel. Let's go with a grayscale look—pure black backgrounds, deep charcoal cards, white text, and very subtle gray borders. Minimalist typography, maybe monospaced font details. We'll show a connected mic state on the home screen, and when they click inside, there should be a gorgeous audio player and clean tabs for the AI summary, key takeaways, and action items. Make sure we use native materials like thin blur overlays if possible.",
                summary: "Discussion regarding the aesthetic direction of the new iOS companion app. The team decided on a grayscale visual theme (black, white, gray) with glassmorphic elements, monospaced typography, and clean tab navigation.",
                keyPoints: [
                    "Visual theme approved: high contrast grayscale/dark mode.",
                    "Integrate custom cards with thin borders and ultra-thin materials.",
                    "Use monospaced fonts for technical metadata (timestamps, status)."
                ],
                actionItems: [
                    "Design UI mocks in black and white.",
                    "Implement Custom Audio player in SwiftUI.",
                    "Configure Material Blur backgrounds on Detail Views."
                ],
                tags: ["Design", "iOS", "Palette"],
                status: .completed
            ),
            Conversation(
                title: "Hardware Mic Prototype Spec",
                date: Date().addingTimeInterval(-3600 * 24), // Yesterday
                duration: 172, // 2m 52s
                transcript: "For the hardware prototype, we need a small casing with a high-sensitivity MEMS microphone, a single push button to start and stop recordings, a rechargeable lithium battery, and an ESP32 chip for Wi-Fi/Bluetooth. When the button is pressed, the LED flashes pulsing white. It records the audio in WAV format, writes it to flash memory, and immediately uploads it to our AWS S3 bucket over Wi-Fi once the button is pressed again. The cloud server will pick it up, run Whisper, send the text to Gemini, and push the JSON update to the iOS app.",
                summary: "Architectural outline of the physical mic recording device. It utilizes an ESP32 for cloud upload, a MEMS microphone, a simple push button, and communicates via AWS S3 to trigger the transcription and AI analysis pipeline.",
                keyPoints: [
                    "Hardware core will run on an ESP32 microcontroller with Wi-Fi.",
                    "WAV format selected for high-quality speech-to-text recognition.",
                    "AWS S3 acts as the middle-ground upload bucket triggering Lambda pipelines."
                ],
                actionItems: [
                    "Order ESP32 development boards.",
                    "Write initial firmware code for audio recording in WAV format.",
                    "Configure Whisper API endpoint in AWS Lambda."
                ],
                tags: ["Hardware", "Firmware", "AWS"],
                status: .completed
            )
        ]
    }
}
