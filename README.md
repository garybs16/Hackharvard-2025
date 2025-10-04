# 📘 ReadAR — AI-Powered Reading & Comprehension Assistant
*HackHarvard 2025 Project*

ReadAR is a cross-platform SwiftUI app that helps you **read smarter** using AI.  
It connects your iOS interface to a lightweight Node.js backend that provides instant definitions, explanations, and reading features — all through a clean and interactive UI.

---

## 🚀 Overview

ReadAR makes reading, understanding, and interacting with text faster and more intuitive.  
The app communicates with a backend service that exposes simple REST APIs to define terms, explain passages, and preview PDFs.

### ✨ Core Features

| Feature | Description |
|----------|-------------|
| 🧠 **AI Definitions** | Get quick, contextual definitions for any term |
| 💬 **Explain Text** | Send a paragraph and receive an easy-to-understand summary |
| 📄 **PDF Preview** | View PDFs directly inside the app using `PDFKit` |
| 🌐 **Cross-Platform Communication** | Swift frontend + Node backend with full API parity |
| 🧰 **Expandable** | Easily extendable to use real AI models or cloud APIs |

---

## 🧩 Project Architecture

📦 Hackharvard-2025-main/
├── backend.js # Express backend server
├── package.json # Backend dependencies & scripts
├── key.env # Example environment variable file
│
├── ReadApp.swift # SwiftUI entry point (main app)
├── ReadARDataModels.swift # Codable models for API responses
├── ReadARNetworkClient.swift # Networking layer for API calls
├── ReadARUIExtensions.swift # UI helper extensions (e.g., Color hex)
├── PDFViewer.swift # PDFKit-based PDF viewer component
│
└── README.md # You're reading this!
