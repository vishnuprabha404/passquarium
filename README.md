# Passquarium - Secure Password Manager

## 👋 Personal Introduction

Hi! This is a multiplatform password manager app I built using Flutter for myself to solve my personal password management struggles. I was having trouble storing all my passwords securely across different devices and platforms, so I decided to create my own solution with military-grade security.

The app currently works on Android and Windows, using AES-256 encryption to keep everything secure. I'm planning to implement more updates in the future, including:
- 🌐 Custom browser plugins for Chrome, Firefox, and Edge
- 🔧 Auto-fill functionality for websites and apps  
- 📊 Advanced security analytics and breach monitoring
- 🎨 More themes and customization options
- 🔄 Enhanced sync capabilities across more platforms


---

## 🔐 About This Project

Passquarium is a secure, cross-platform password manager built with Flutter that works on Android and Windows. It uses military-grade AES-256 encryption to protect your passwords with multiple layers of security.

## 🎯 Features

### 🔐 Multi-Layer Security
- **Device Authentication**: Biometric authentication (fingerprint, face ID) or device PIN
- **Master Password**: Strong master password requirement with PBKDF2 hashing
- **AES-256 Encryption**: All passwords encrypted with AES-256-CBC before storage
- **PBKDF2 Key Derivation**: 100,000 iterations for secure key generation
- **Auto-Lock**: Automatic app locking after 60 seconds of inactivity
- **Secure Clipboard**: Auto-clear clipboard after 15 seconds
- **No Plain Text Storage**: Passwords are never stored in plain text

### 📱 Cross-Platform Support
- **Android**: Full biometric authentication support (fingerprint, face ID, device PIN)
- **Windows**: Windows Hello integration with fallback authentication
- **Responsive UI**: Adapts to different screen sizes and orientations

### 🚀 Core Functionality
- **Password Management**: Add, edit, delete, and search passwords
- **Advanced Search**: Search by website, username, category with filtering
- **Password Generation**: Built-in secure password generator with customizable rules
- **Password Strength Indicator**: Real-time password strength analysis
- **Category Organization**: Organize passwords by categories
- **Secure Password Viewing**: Biometric authentication required to view passwords

### ☁️ Cloud Sync
- **Firebase Integration**: Encrypted data sync across devices
- **Offline Support**: Works without internet connection
- **Device-Specific Storage**: Each device has its own encrypted vault
- **Real-time Sync**: Automatic synchronization when online

## 📋 System Requirements

### Development Requirements
- **Operating System**: Windows 10/11, macOS 10.14+, or Linux (Ubuntu 18.04+)
- **Flutter SDK**: 3.32.0+ (latest stable)
- **Dart SDK**: 3.8.0+ (included with Flutter)
- **Android Studio**: 2024.2+ or VS Code with Flutter extension
- **Git**: For version control
- **Node.js**: 18.0+ (for Firebase CLI)
- **Firebase Account**: For cloud storage

### Target Platform Requirements

#### Android
- **Minimum SDK**: API 23 (Android 6.0)
- **Target SDK**: API 34 (Android 14)
- **Compile SDK**: API 34
- **Biometric Support**: Device with fingerprint sensor or face unlock
- **Storage**: 50MB free space

#### Windows
- **Windows Version**: Windows 10 version 1903+ (64-bit)
- **Windows Hello**: Recommended for biometric authentication
- **Storage**: 100MB free space
- **RAM**: 4GB minimum, 8GB recommended

## 🛠️ Installation & Setup

### Step 1: Quick Setup (Automated)

For the fastest setup, use our automated installation scripts:

#### Windows (PowerShell - Run as Administrator)
```powershell
# Download and run the setup script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/vishnuprabha404/passquarium/master/setup.ps1" -OutFile "setup.ps1"
.\setup.ps1
```

Or run the local script:
```powershell
.\setup.ps1
```

#### macOS/Linux (Bash)
```bash
# Download and run the setup script
curl -fsSL https://raw.githubusercontent.com/vishnuprabha404/passquarium/master/setup.sh | bash

# Or run the local script
chmod +x setup.sh
./setup.sh
```

### Step 1 (Alternative): Manual Installation

If you prefer manual installation or the automated script fails:

#### Install Flutter
```bash
# Windows (using Git)
git clone https://github.com/flutter/flutter.git -b stable C:\flutter
# Add C:\flutter\bin to your PATH

# macOS (using Homebrew)
brew install flutter

# Linux
sudo snap install flutter --classic
```

#### Install Node.js and Firebase CLI
```bash
# Install Node.js (visit nodejs.org for Windows installer)

# Install Firebase CLI globally
npm install -g firebase-tools

# Install FlutterFire CLI
dart pub global activate flutterfire_cli
```

#### Install Android Studio
1. Download from [developer.android.com](https://developer.android.com/studio)
2. Install with default settings
3. Install Flutter and Dart plugins

### Step 2: Clone and Setup Project

```bash
# Clone the repository
git clone https://github.com/vishnuprabha404/passquarium.git
cd passquarium

# Install Flutter dependencies
flutter pub get

# Verify Flutter installation
flutter doctor
```

**📍 Repository Information:**
- **Official Repository**: [https://github.com/vishnuprabha404/passquarium](https://github.com/vishnuprabha404/passquarium)
- **Branch**: `master`
- **Issues & Bug Reports**: [GitHub Issues](https://github.com/vishnuprabha404/passquarium/issues)
- **Security Disclosures**: Contact [vishnuprabha404@gmail.com](mailto:vishnuprabha404@gmail.com)

### Step 3: Firebase Configuration

⚠️ **CRITICAL**: This app requires Firebase to function. Without proper Firebase setup, the app will not compile or run.

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or select existing project
3. Enable Authentication in "Build" → "Authentication" → "Get Started"
4. Enable Email/Password sign-in method
5. Enable Firestore Database in "Build" → "Firestore Database"
6. Choose "Start in test mode" (we'll configure security rules later)

#### Configure Firebase for Flutter (MANDATORY)
```bash
# Login to Firebase
firebase login

# Configure Firebase for your Flutter project
flutterfire configure

# Select your Firebase project
# Choose platforms: Android, Windows
# This will generate lib/firebase_options.dart and android/app/google-services.json
```

⚠️ **Important**: After running `flutterfire configure`, you should see:
- ✅ `lib/firebase_options.dart` created
- ✅ `android/app/google-services.json` created  
- ✅ No build errors when running `flutter pub get`

#### Set Firestore Security Rules
In Firebase Console → Firestore → Rules, replace with:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/passwords/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Step 3.5: Verify Setup (BEFORE BUILDING)

Before proceeding to platform-specific setup, verify your configuration:

```bash
# 1. Check that Firebase files were created
ls lib/firebase_options.dart
ls android/app/google-services.json

# 2. Install dependencies
flutter pub get

# 3. Verify no import errors
flutter analyze

# 4. Test compilation (should not fail)
flutter build windows --debug  # For Windows
# OR
flutter build apk --debug      # For Android
```

**Expected Results:**
- ✅ No "file not found" errors for firebase_options.dart
- ✅ No build failures related to Firebase
- ✅ App builds successfully (may have runtime errors, but should compile)

**If you get errors:**
- ❌ `Error: Could not resolve firebase_options.dart` → Run `flutterfire configure` again
- ❌ `google-services.json not found` → Run `flutterfire configure` and select Android platform
- ❌ `Firebase project not found` → Verify you selected the correct project in `flutterfire configure`

### Step 4: Platform-Specific Setup

#### Android Setup
1. **Update build configuration** (`android/app/build.gradle`) - Note: This is already configured:
```gradle
android {
    compileSdkVersion 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    defaultConfig {
        applicationId "com.passquarium.app"
        minSdkVersion 23
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }
}
```

2. **Add permissions** (`android/app/src/main/AndroidManifest.xml`) - Note: These are already configured:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Biometric permissions -->
    <uses-permission android:name="android.permission.USE_BIOMETRIC" />
    <uses-permission android:name="android.permission.USE_FINGERPRINT" />
    
    <!-- Network permissions for Firebase -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <application
        android:label="Passquarium"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- Your app configuration -->
    </application>
</manifest>
```

#### Windows Setup
1. **Enable Windows support**:
```bash
flutter config --enable-windows-desktop
```

2. **Update CMakeLists.txt** (if needed):
```cmake
# windows/CMakeLists.txt - should be automatically configured
cmake_minimum_required(VERSION 3.14)
project(passquarium LANGUAGES CXX)
```

### Step 5: Enable Developer Mode (Windows)

For development on Windows, enable Developer Mode:
```bash
# Open PowerShell as Administrator and run:
start ms-settings:developers
# Toggle "Developer Mode" to ON
```

## 🚀 Running the Application

### Development Mode

#### Run on Android
```bash
# List available devices
flutter devices

# Run on connected Android device
flutter run

# Run on Android emulator
flutter run -d android

# Run with hot reload (recommended for development)
flutter run --debug
```

#### Run on Windows
```bash
# Run on Windows desktop
flutter run -d windows

# Run with hot reload
flutter run -d windows --debug
```

#### Run with specific flavors
```bash
# Development mode with detailed logging
flutter run --debug --dart-define=ENVIRONMENT=development

# Release mode for testing
flutter run --release
```

### Building for Release

#### Android Release Build
```bash
# Build APK for testing
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release

# Build APK for specific architecture
flutter build apk --release --target-platform android-arm64
```

#### Windows Release Build
```bash
# Build Windows executable
flutter build windows --release

# The executable will be in: build/windows/x64/runner/Release/
```

### Troubleshooting Platform Issues

#### Android Issues
```bash
# If Gradle issues occur
cd android && ./gradlew clean && cd ..
flutter clean && flutter pub get

# If build fails
flutter doctor --android-licenses
```

#### Windows Issues
```bash
# If Windows build fails
flutter clean
flutter pub get
flutter build windows --verbose
```

## 🏗️ Project Architecture

```
passquarium/
├── lib/
│   ├── main.dart                    # App entry point with providers
│   ├── firebase_options.dart        # Auto-generated Firebase config
│   │
│   ├── models/
│   │   └── password_entry.dart      # Password data model with encryption fields
│   │
│   ├── services/
│   │   ├── auth_service.dart        # Biometric & device authentication
│   │   ├── encryption_service.dart  # AES-256 encryption with PBKDF2
│   │   ├── firestore_service.dart   # Cloud storage & synchronization
│   │   ├── auto_lock_service.dart   # Inactivity tracking & auto-lock
│   │   ├── clipboard_manager.dart   # Secure clipboard operations
│   │   ├── password_service.dart    # Password CRUD operations
│   │   └── key_service.dart         # Vault key management
│   │
│   ├── providers/
│   │   └── app_provider.dart        # State management (App, Password, UI, Settings)
│   │
│   ├── config/
│   │   └── app_config.dart          # App configuration and constants
│   │
│   ├── screens/
│   │   ├── splash_screen.dart       # App initialization & loading
│   │   ├── device_auth_screen.dart  # Biometric authentication
│   │   ├── email_auth_screen.dart   # Email authentication with master key
│   │   ├── home_screen.dart         # Main dashboard
│   │   ├── add_password_screen.dart # Password creation form
│   │   ├── edit_password_screen.dart # Password editing form
│   │   ├── search_password_screen.dart # Advanced search with security
│   │   └── password_generator_screen.dart # Password generator
│   │
│   ├── widgets/
│   │   ├── password_strength_indicator.dart # Visual password strength
│   │   └── secure_clipboard_button.dart     # Clipboard with countdown
│   │
│   └── utils/                  # Utility functions and helpers
│
├── assets/images/               # App icons and images
├── android/                    # Android-specific configuration
├── windows/                    # Windows-specific configuration
├── ios/                        # iOS-specific configuration
├── macos/                      # macOS-specific configuration
├── linux/                      # Linux-specific configuration
├── web/                        # Web-specific configuration
├── test/                       # Unit and integration tests
├── docs/                       # Documentation files
├── installer/                  # Windows installer configuration
├── pubspec.yaml               # Flutter dependencies
├── requirements.txt           # Development requirements
├── setup.ps1                  # Windows setup script
├── setup.sh                   # macOS/Linux setup script
└── notes.txt                  # Project development log
```

## 🔒 Security Architecture

```
User Input (Password)
        │
        ▼
┌─────────────────┐
│ Master Password │ ──────┐
│ (User Input)    │       │
└─────────────────┘       │
        │                 │
        ▼                 ▼
┌─────────────────┐ ┌──────────────────┐
│ PBKDF2 Key      │ │ Random Salt      │
│ Derivation      │ │ Generation       │
│ (100k iterations)│ │ (32 bytes)      │
└─────────────────┘ └──────────────────┘
        │                 │
        └─────────┬───────┘
                  ▼
        ┌──────────────────┐
        │ AES-256-CBC      │
        │ Encryption       │
        │ + Unique IV      │
        └──────────────────┘
                  │
                  ▼
        ┌──────────────────┐
        │ Firebase         │
        │ (Encrypted Data) │
        │ + Device ID      │
        └──────────────────┘
```

## 📦 Dependencies

See [`requirements.txt`](requirements.txt) for the complete installation guide including system requirements, troubleshooting, and step-by-step setup instructions.

**Key Flutter Dependencies:**
- `flutter`: 3.32.0+
- `firebase_core`: ^3.14.0
- `cloud_firestore`: ^5.6.9
- `local_auth`: ^2.3.0
- `encrypt`: ^5.0.3
- `flutter_secure_storage`: ^9.2.4
- `provider`: ^6.1.5

**Setup Files:**
- [`setup.ps1`](setup.ps1) - Automated Windows setup script
- [`setup.sh`](setup.sh) - Automated macOS/Linux setup script
- [`requirements.txt`](requirements.txt) - Comprehensive requirements and troubleshooting guide

## 🤝 Contributing

1. Fork the repository at [https://github.com/vishnuprabha404/passquarium](https://github.com/vishnuprabha404/passquarium)
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and test thoroughly
4. Run tests: `flutter test`
5. Run code analysis: `flutter analyze`
6. Commit changes: `git commit -m 'Add amazing feature'`
7. Push to branch: `git push origin feature/amazing-feature`
8. Open a Pull Request

## 🛣️ Roadmap & Personal Development Plan

### Immediate Goals (Next 3 Months)
- [ ] Complete UI polish and theme customization
- [ ] Implement comprehensive testing suite
- [ ] Add password import/export functionality
- [ ] Create browser extension for Chrome (primary focus)
- [ ] Enhance search functionality with advanced filters

### Medium-term Goals (6 Months)
- [ ] Browser extensions for Firefox and Edge
- [ ] Auto-fill functionality for websites and apps
- [ ] iOS and macOS support expansion
- [ ] Password breach monitoring and alerts
- [ ] Advanced password analytics and insights

### Long-term Vision (1 Year+)
- [ ] Custom synchronization server (self-hosted option)
- [ ] Linux desktop support
- [ ] Two-factor authentication integration
- [ ] Family sharing features
- [ ] Advanced audit logging and security reports

### Security Enhancements (Ongoing)
- [ ] Hardware security module integration
- [ ] Enhanced zero-knowledge architecture
- [ ] Advanced threat detection and response
- [ ] Regular security audits and penetration testing

## 📅 Project Updates

### Version 2.0 
- ✅ **Core Implementation Complete**: All basic password management features implemented
- ✅ **Cross-Platform Support**: Android and Windows builds working
- ✅ **Security Features**: AES-256 encryption, biometric auth, auto-lock, secure clipboard
- ✅ **State Management**: Comprehensive provider-based architecture
- ✅ **Documentation**: Complete setup guides and troubleshooting documentation
- 🔄 **Current Focus**: Testing, UI improvements, and browser plugin development

### Next Update Goals
- 🎯 **Browser Plugin Development**: Starting with Chrome extension
- 🎯 **Enhanced UI/UX**: Material Design 3 implementation
- 🎯 **Performance Optimization**: Faster app startup and smoother animations
- 🎯 **Advanced Features**: Password generator improvements and categories

---

**⚠️ Security Notice**: This app handles sensitive data. Always use strong, unique passwords and keep your devices secure. The developer is not responsible for any data loss or security breaches resulting from improper use.

**🐛 Found a bug?** Please open an issue on [GitHub Issues](https://github.com/vishnuprabha404/passquarium/issues) with detailed steps to reproduce.

**🔐 Security Issues**: Please email vishnuprabha404@gmail.com for responsible disclosure. 
