# CloudMic: Serverless IoT Audio Ingestion & AI Semantic Analysis Pipeline

CloudMic is a serverless backend and companion iOS application designed to capture, process, and analyze speech from IoT microcontrollers. The system converts raw audio, transcribes it, runs semantic analysis via AI models in Amazon Bedrock, and updates a mobile dashboard.

---

## 🏗️ High-Level Cloud Architecture

The pipeline uses a completely serverless event-driven architecture on AWS to handle scaling and cost efficiency.

![AWS Cloud Architecture](AWS_Arch_IOT.jpeg)


### Key Stages:
1. **Secure Ingestion**: IoT devices fetch authorization keys to stream raw audio recordings directly and securely to Amazon S3.
2. **Audio Pipeline**: Uploaded audio is processed and transcribed asynchronously using event-driven Lambda triggers and Amazon Transcribe.
3. **AI Semantics**: Large language models hosted on Amazon Bedrock process the speech transcript to extract topics, executive summaries, takeaways, action items, and Q&A answers.
4. **Data Sync**: The structured results are stored in Amazon DynamoDB and served to the iOS application via API Gateway.

---

## 🌟 Key Features

* **IoT-Ready Ingestion**: Presigned secure URLs allow memory-constrained hardware to upload data without storing persistent credentials.
* **Semantic Analysis**: Extract key intelligence, summaries, and action steps automatically.
* **Assistant Q&A**: Detects questions asked in the audio and embeds corresponding AI-generated answers directly in your feed.
* **Modern Grayscale UI**: Native iOS SwiftUI application designed with high-contrast grayscale palettes, featuring interactive detail tabs and swipe-to-refresh sync.

---

## 🔌 Hardware & Physical Setup

This project uses an ESP32-S3 microcontroller connected to a digital microphone and SD card module to record voice conversations locally and upload them to AWS.

![IoT Device Physical Setup](IOT_device_setup.jpg)

### Components Involved:
1. **ESP32-S3 Dev Module**: Core dual-core processor managing the audio recording task, local buffers, and Wi-Fi transmission.
2. **INMP441 I2S Microphone**: High-precision omnidirectional microphone providing direct I2S digital audio output (eliminating analog noise).
3. **MicroSD SPI Breakout Board**: Buffers raw `.wav` recordings locally before triggering the S3 upload client.
4. **Push Button Switch**: Acts as the physical user trigger to start/stop recordings.

### Circuit Wiring Schematic:

```mermaid
graph TD
%% Core Controller
subgraph Core ["ESP32-S3 Dev Module"]
ESP[ESP32-S3 Processor]

    %% Power & Ground
    3V3((3V3 Pin))
    5V((5V / VBUS Pin))
    GND1((GND Pin))
    GND2((GND Pin))
    GND3((GND Pin))
    
    %% GPIO - MicroSD (SPI)
    CS10([GPIO 10 - CS])
    MOSI11([GPIO 11 - MOSI])
    SCK12([GPIO 12 - SCK])
    MISO13([GPIO 13 - MISO])
    
    %% GPIO - Microphone (I2S)
    WS4([GPIO 4 - WS])
    SCK5([GPIO 5 - SCK])
    SD6([GPIO 6 - SD])
    
    %% GPIO - UI
    BTN1([GPIO 1])
end

%% Storage Module
subgraph Storage ["MicroSD SPI Breakout Board"]
    SD_CS[CS Pin]
    SD_SCK[SCK Pin]
    SD_MOSI[MOSI Pin]
    SD_MISO[MISO Pin]
    SD_VCC[VCC Pin<br>Requires 5V]
    SD_GND[GND Pin]
    SD_CARD[(MicroSD Card<br>FAT32 Format)]
end

%% Audio Capture
subgraph Audio ["INMP441 I2S Microphone"]
    MIC_VDD[VDD Pin<br>Requires 3.3V]
    MIC_GND[GND Pin]
    MIC_LR[L/R Pin<br>Grounded for Left Ch.]
    MIC_WS[WS / Word Select]
    MIC_SCK[SCK / Serial Clock]
    MIC_SD[SD / Serial Data]
end

%% User Interface
subgraph UI ["User Interface"]
    PUSHBTN((Push Button))
end

%% Decoupling Filter
subgraph Filter ["Noise Filter"]
    CAP_POS[10uF Capacitor +<br>Long Leg]
    CAP_NEG[10uF Capacitor -<br>Short Leg]
end

%% --- Connections ---

%% Power Connections
3V3 -->|3.3V Power| MIC_VDD
5V -->|5V Power| SD_VCC
GND1 -->|Common Ground| MIC_GND
GND1 -->|Channel Select| MIC_LR
GND2 -->|Common Ground| SD_GND
GND3 -->|Switch Ground| PUSHBTN

%% Decoupling Capacitor Connections
CAP_POS ===|Positive Filter| MIC_VDD
CAP_NEG ===|Negative Filter| MIC_GND

%% MicroSD SPI Connections
CS10 ===|Chip Select| SD_CS
SCK12 ===|SPI Clock| SD_SCK
MOSI11 ===|Master Out, Slave In| SD_MOSI
MISO13 ===|Master In, Slave Out| SD_MISO

%% Microphone I2S Connections
WS4 -.-|Word Select / L-R Clock| MIC_WS
SCK5 -.-|Serial Clock / Bit Clock| MIC_SCK
SD6 -.-|Serial Data Out| MIC_SD

%% Button Connection
BTN1 ---|Signal <br> Internal Pull-up| PUSHBTN

%% Styling
classDef esp fill:#2d2f38,stroke:#0b57d0,stroke-width:2px,color:#fff;
classDef storage fill:#1f3760,stroke:#7fcfff,stroke-width:2px,color:#fff;
classDef audio fill:#0f5223,stroke:#6dd58c,stroke-width:2px,color:#fff;
classDef ui fill:#3a3f50,stroke:#fcbd00,stroke-width:2px,color:#fff;
classDef filter fill:#5a2d82,stroke:#dca3ff,stroke-width:2px,color:#fff;
classDef pin fill:#444746,stroke:#c4c7c5,color:#fff,stroke-width:1px;

class Core esp;
class Storage storage;
class Audio audio;
class UI ui;
class Filter filter;
class 3V3,5V,GND1,GND2,GND3,CS10,MOSI11,SCK12,MISO13,WS4,SCK5,SD6,BTN1,CAP_POS,CAP_NEG pin;
```

---



## 🚀 Setup & Deployment Overview


### Infrastructure Deployment
The infrastructure is configured via Terraform. To deploy:
1. Initialize Terraform plugins:
   ```bash
   terraform init
   ```
2. Build the cloud stack:
   ```bash
   terraform apply
   ```

### iOS Application Setup
1. Open the Swift project in Xcode:
   ```bash
   open the CloudMicApp.xcodeproj
   ```
2. Update your API Gateway endpoint constant in `ConversationViewModel.swift`.
3. Set your developer signing team under target properties, compile, and run on your device.