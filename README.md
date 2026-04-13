# WealthFam Mobile: Financial Forensics on the Go

WealthFam Mobile is a Flutter-based Android application that serves as the primary real-time ingestion source for the WealthFam ecosystem.

## ✨ Core Functionalities

### 1. SMS Ingestion (Real-Time)
The app runs a background service that listens for transactional SMS from banks and credit cards. It immediately hashes the content and forwards it to the Parser Microservice for processing.

### 2. Mobile Dashboard
A streamlined version of the web dashboard, providing "at-a-glance" stats:
- Current Month Spends
- Recent Transactions
- Budget Alerting

### 3. Account Management
Users can view and manage their linked bank accounts and mutual fund portfolios directly from the app.

## 🛠️ Tech Stack
- **Flutter**: Cross-platform framework (optimized for Android).
- **Dart**: Strong, typed language for robust app logic.
- **SMS Listeners**: Native integration for high-reliability background ingestion.
- **REST API**: Communicates with the Backend and Parser services.

## 🏁 Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Android Studio / VS Code
- Android Device (physical device required for SMS testing)

### Installation
1. Clone the repository.
2. Run `flutter pub get`.
3. Configure the backend URL in `lib/config.dart`.
4. Build and install:
   ```bash
   flutter run --release
   ```

## 🔐 Permissions Required
- **RECEIVE_SMS / READ_SMS**: Critical for the ingestion engine.
- **INTERNET**: To sync data with the WealthFam cloud/server.

---
*WealthFam: Invisible Financial Automation*
