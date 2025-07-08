# Passquarium Windows Installer

This directory contains the NSIS installer configuration for creating a professional Windows installer for Passquarium.

## 🚀 Quick Start

### Prerequisites

1. **NSIS (Nullsoft Scriptable Install System)**
   ```bash
   # Install via Chocolatey (recommended)
   choco install nsis
   
   # Or download from: https://nsis.sourceforge.io/Download
   ```

2. **Flutter SDK** (already installed for your project)

### Creating the Installer

Run the automated installer creation script from the project root:

```powershell
# From the project root directory
.\create_installer.ps1
```

This script will:
1. ✅ Clean and build your Flutter app for Windows
2. ✅ Verify all dependencies are present
3. ✅ Create a professional Windows installer using NSIS
4. ✅ Generate `PassquariumInstaller_v1.6.exe`

## 📦 What the Installer Includes

### Core Features
- ✅ Professional installation wizard with modern UI
- ✅ Automatic detection and removal of previous versions
- ✅ Registry entries for Add/Remove Programs
- ✅ Desktop, Start Menu, and Quick Launch shortcuts
- ✅ Proper uninstaller with user data cleanup options
- ✅ File association and version information

### Installation Components
- **Core Application** (Required): Main Passquarium executable and Flutter runtime
- **Desktop Shortcut**: Creates shortcut on user's desktop
- **Start Menu Shortcuts**: Creates program group in Start Menu
- **Quick Launch Shortcut**: Adds to Quick Launch toolbar

## 🛠️ Manual Installer Creation

If you prefer to create the installer manually:

1. **Build the Flutter app:**
   ```bash
   flutter build windows --release
   ```

2. **Compile the NSIS script:**
   ```bash
   cd installer
   makensis passquarium_installer.nsi
   ```

## 📋 Installer Configuration

### Key Files
- `passquarium_installer.nsi` - Main NSIS installer script
- `LICENSE.txt` - License agreement shown during installation
- `README.md` - This documentation file

### Customization Options

Edit `passquarium_installer.nsi` to modify:

```nsis
!define APP_NAME "Passquarium"
!define APP_VERSION "1.6"
!define APP_PUBLISHER "Passquarium Team"
!define APP_URL "https://github.com/yourusername/passquarium"
!define APP_DESCRIPTION "Secure Password Manager with Military-Grade Encryption"
```

## 🔒 Code Signing (Optional)

For production distribution, consider code signing your installer:

1. **Obtain a code signing certificate** from a trusted CA
2. **Sign the installer** using SignTool:
   ```bash
   signtool sign /f "certificate.pfx" /p "password" /t "http://timestamp.verisign.com/scripts/timstamp.dll" PassquariumInstaller_v1.6.exe
   ```

## 🧪 Testing the Installer

### Pre-Release Testing Checklist
- [ ] Install on clean Windows 10/11 machine
- [ ] Verify all shortcuts are created correctly
- [ ] Test application launches and functions properly
- [ ] Verify uninstaller removes all components
- [ ] Check Add/Remove Programs entry is correct
- [ ] Test upgrade installation (install over existing version)

### Test Environments
- ✅ Windows 10 (64-bit)
- ✅ Windows 11 (64-bit)
- ✅ Clean virtual machine
- ✅ Machine with previous version installed

## 📊 Installer Statistics

The installer will typically be:
- **Size**: ~50-80 MB (includes Flutter runtime)
- **Installation time**: 30-60 seconds
- **Disk space required**: ~150-200 MB
- **Supported OS**: Windows 10/11 (64-bit)

## 🐛 Troubleshooting

### Common Issues

**NSIS not found:**
```bash
# Install NSIS via Chocolatey
choco install nsis

# Or add NSIS to your PATH manually
```

**Flutter build fails:**
```bash
flutter clean
flutter pub get
flutter build windows --release
```

**Installer compilation errors:**
- Check file paths in the NSIS script
- Ensure all referenced files exist
- Verify NSIS syntax

### Support
- Check the main project README.md for Flutter-specific issues
- Review NSIS documentation: https://nsis.sourceforge.io/Docs/
- Open an issue in the project repository

## 📝 License

The installer script is provided under the same license as the main Passquarium application (MIT License). 