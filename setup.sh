#!/bin/bash

# Super Locker - Automated Setup Script for macOS/Linux
# Bash script to install all requirements and set up the development environment

echo "================================="
echo "Super Locker Setup Script"
echo "Setting up development environment..."
echo "================================="

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

# Function to install on macOS
setup_macos() {
    echo "Setting up for macOS..."
    
    # Install Homebrew if not present
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install dependencies
    echo "Installing dependencies via Homebrew..."
    brew update
    brew install git node
    brew install --cask android-studio
    
    # Install Flutter
    echo "Installing Flutter..."
    if [ ! -d "/opt/flutter" ]; then
        sudo git clone https://github.com/flutter/flutter.git -b stable /opt/flutter
        sudo chown -R $(whoami) /opt/flutter
    fi
    
    # Add Flutter to PATH
    FLUTTER_PATH="/opt/flutter/bin"
    if [[ ":$PATH:" != *":$FLUTTER_PATH:"* ]]; then
        echo "Adding Flutter to PATH..."
        echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.zshrc
        echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.bash_profile
        export PATH="$PATH:/opt/flutter/bin"
    fi
}

# Function to install on Linux
setup_linux() {
    echo "Setting up for Linux..."
    
    # Update package manager
    sudo apt update
    
    # Install basic dependencies
    echo "Installing basic dependencies..."
    sudo apt install -y git curl unzip wget gnupg software-properties-common
    
    # Install Node.js
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    
    # Install Java (required for Android development)
    echo "Installing OpenJDK..."
    sudo apt install -y openjdk-11-jdk
    
    # Install Android Studio via snap
    echo "Installing Android Studio..."
    sudo snap install android-studio --classic
    
    # Install Flutter
    echo "Installing Flutter..."
    if [ ! -d "/opt/flutter" ]; then
        sudo git clone https://github.com/flutter/flutter.git -b stable /opt/flutter
        sudo chown -R $(whoami) /opt/flutter
    fi
    
    # Add Flutter to PATH
    FLUTTER_PATH="/opt/flutter/bin"
    if [[ ":$PATH:" != *":$FLUTTER_PATH:"* ]]; then
        echo "Adding Flutter to PATH..."
        echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.bashrc
        export PATH="$PATH:/opt/flutter/bin"
    fi
}

# Main installation process
case $OS in
    "macos")
        setup_macos
        ;;
    "linux")
        setup_linux
        ;;
    *)
        echo "Unsupported operating system: $OSTYPE"
        echo "Please install dependencies manually. See requirements.txt for details."
        exit 1
        ;;
esac

# Common setup for both platforms
echo "Installing Firebase CLI..."
npm install -g firebase-tools

echo "Installing FlutterFire CLI..."
dart pub global activate flutterfire_cli

# Enable desktop support (Linux only)
if [ "$OS" == "linux" ]; then
    echo "Enabling Flutter Linux desktop support..."
    flutter config --enable-linux-desktop
fi

# Run Flutter doctor
echo "Running Flutter doctor to verify installation..."
flutter doctor

echo "================================="
echo "Setup Complete!"
echo "================================="
echo ""
echo "Next steps:"
echo "1. Restart your terminal (or run: source ~/.bashrc / source ~/.zshrc)"
echo "2. Navigate to your project directory"
echo "3. Run: flutter pub get"
echo "4. Configure Firebase: firebase login && flutterfire configure"
if [ "$OS" == "macos" ]; then
    echo "5. Run the app: flutter run -d macos"
else
    echo "5. Run the app: flutter run -d linux"
fi
echo ""
echo "If you encounter any issues, check the requirements.txt file for troubleshooting."

# Make the script executable
chmod +x setup.sh 