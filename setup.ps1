# Super Locker - Automated Setup Script for Windows
# PowerShell script to install all requirements and set up the development environment
# Run this script as Administrator

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Super Locker Setup Script" -ForegroundColor Cyan
Write-Host "Setting up development environment..." -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Enable Developer Mode
Write-Host "Enabling Windows Developer Mode..." -ForegroundColor Yellow
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
if (!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
Set-ItemProperty -Path $registryPath -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord

# Install Chocolatey if not present
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey package manager..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    refreshenv
}

# Install Git
Write-Host "Installing Git..." -ForegroundColor Yellow
choco install git -y

# Install Node.js
Write-Host "Installing Node.js..." -ForegroundColor Yellow
choco install nodejs -y

# Install Visual Studio Community with C++ tools
Write-Host "Installing Visual Studio Community with C++ tools..." -ForegroundColor Yellow
choco install visualstudio2022community --package-parameters "--add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended" -y

# Install Android Studio
Write-Host "Installing Android Studio..." -ForegroundColor Yellow
choco install androidstudio -y

# Refresh environment variables
refreshenv

# Install Flutter (manual installation for better control)
Write-Host "Installing Flutter SDK..." -ForegroundColor Yellow
$flutterPath = "C:\flutter"
if (!(Test-Path $flutterPath)) {
    git clone https://github.com/flutter/flutter.git -b stable $flutterPath
}

# Add Flutter to PATH if not already present
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
$flutterBinPath = "$flutterPath\bin"
if ($currentPath -notlike "*$flutterBinPath*") {
    Write-Host "Adding Flutter to system PATH..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$flutterBinPath", "Machine")
}

# Refresh environment
$env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine")

# Install Firebase CLI
Write-Host "Installing Firebase CLI..." -ForegroundColor Yellow
npm install -g firebase-tools

# Install FlutterFire CLI
Write-Host "Installing FlutterFire CLI..." -ForegroundColor Yellow
& "$flutterBinPath\dart" pub global activate flutterfire_cli

# Enable Windows desktop support
Write-Host "Enabling Flutter Windows desktop support..." -ForegroundColor Yellow
& "$flutterBinPath\flutter" config --enable-windows-desktop

# Run Flutter doctor to check setup
Write-Host "Running Flutter doctor to verify installation..." -ForegroundColor Yellow
& "$flutterBinPath\flutter" doctor

Write-Host "=================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Restart your terminal/PowerShell" -ForegroundColor White
Write-Host "2. Navigate to your project directory" -ForegroundColor White
Write-Host "3. Run: flutter pub get" -ForegroundColor White
Write-Host "4. Configure Firebase: firebase login && flutterfire configure" -ForegroundColor White
Write-Host "5. Run the app: flutter run -d windows" -ForegroundColor White
Write-Host ""
Write-Host "If you encounter any issues, check the requirements.txt file for troubleshooting." -ForegroundColor Yellow 