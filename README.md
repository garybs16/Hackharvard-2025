# 🍎 VisionAssist — HackHarvard 2025

### 🏆 Built for HackHarvard 2025  
**VisionAssist** is a next-generation **Apple Vision Pro application** that redefines spatial interaction through **gesture recognition**, **real-time environment mapping**, and **AI-driven context awareness**.  
Built on **VisionOS**, it bridges the gap between human intuition and spatial computing — merging **augmented reality**, **machine learning**, and **computer vision** into a single immersive platform.

---

## ⚙️ Technical Overview

VisionAssist leverages the **Apple Vision Pro’s advanced sensor array** and **VisionOS SDK** to interpret user gestures, facial cues, and real-world objects. The system integrates **spatial mapping**, **hand tracking**, and **scene understanding** to enable natural, touchless interaction in 3D space.

Core innovations include:
- **Spatial Anchoring:** Persistent digital overlays attached to real-world coordinates.  
- **Hand Gesture Recognition:** Dynamic gesture input powered by VisionOS frameworks and ML models.  
- **AI Context Engine:** On-device neural model that predicts user intent and optimizes UI flow.  
- **Realtime Raycasting:** Detects object boundaries for precise interaction with virtual interfaces.  

---

## 🧠 Features

- ✋ **Gesture-Based Navigation** — Control apps and content through natural motion and hand signals.  
- 🌍 **Spatial Awareness** — Uses LiDAR and VisionOS spatial mapping to render AR overlays in real-time.  
- 🧩 **Adaptive UI Layer** — Interfaces dynamically adjust based on gaze, gesture, and context.  
- 🔊 **Seamless Multimodal Input** — Integrates gaze, gesture, and voice for a unified interaction model.  
- ⚡ **On-Device Inference** — AI runs locally for low-latency feedback and privacy preservation.

---

## 🧰 Tech Stack

| Component | Technology |
|------------|-------------|
| **Platform** | VisionOS (Apple Vision Pro) |
| **Language** | Swift / SwiftUI |
| **Frameworks** | RealityKit, ARKit, CoreML, Vision |
| **AI/ML** | On-device CoreML models (gesture classification & object recognition) |
| **3D Rendering** | Reality Composer Pro / SceneKit |
| **Backend (optional)** | Python / FastAPI microservice (for analytics or model updates) |

---

## 🧩 System Architecture

+--------------------------+
| VisionAssist (VisionOS) |
+-----------+--------------+
|
v
+-----------+--------------+
| Vision + CoreML Engine |
| - Gesture Recognition |
| - Scene Understanding |
+-----------+--------------+
|
v
+-----------+--------------+
| RealityKit UI Renderer |
| - 3D Overlays |
| - Spatial Anchors |
+-----------+--------------+
|
v
+-----------+--------------+
| Backend API (optional) |
| - Data sync / analytics |
+--------------------------+


---

## 🧪 Installation & Setup

### Requirements
- macOS 14.0+ with Xcode 15+  
- Apple Vision Pro device or VisionOS simulator  
- VisionOS SDK installed via Xcode  

### Running the App
```bash
# Clone the repository
git clone https://github.com/yourusername/VisionAssist.git
cd VisionAssist

# Open the Xcode project
open VisionAssist.xcodeproj

# Build & deploy to Vision Pro / VisionOS Simulator

📈 Impact

Designed and prototyped under HackHarvard 2025, demonstrating real-world applications of spatial AI and mixed reality.

Showcases how Apple Vision Pro can revolutionize education, accessibility, and productivity through gesture-first interaction.

Developed with a focus on low-latency UX, energy efficiency, and on-device ML inference.

🧑‍💻 Team & Credits

Developer: Gary Samuel, Eason Ying, Kyle Kelly, Nancy Pazzi
Event: HackHarvard 2025 — Harvard University
Category: Spatial Computing / AI Interaction
Location: Cambridge, MA


🎓 HackHarvard Prestige

This project was conceptualized and built during HackHarvard 2025, one of the world’s most prestigious university hackathons.
It embodies the event’s mission — innovation through interdisciplinary technology, merging AI, AR, and human-centered design to define the future of spatial computing.


---

Would you like me to make a **README variant** focused more on **“pitch-style storytelling”** (like what you’d show HackHarvard judges during demo day — elegant, slightly marketing-driven, and visually structured)?  
That version reads like a **startup launch page**, not just a technical doc.
