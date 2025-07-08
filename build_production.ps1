# Passquarium - Production Build Script
# This script builds a clean, production-ready version of the app

Write-Host "🔒 Passquarium - Production Build Script" -ForegroundColor Blue
Write-Host "==========================================" -ForegroundColor Blue

# Check if Flutter is installed
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Flutter found" -ForegroundColor Green

# Clean previous builds
Write-Host "🧹 Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "📦 Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Analyze code for issues
Write-Host "🔍 Analyzing code..." -ForegroundColor Yellow
flutter analyze

# Build for Windows (Release mode)
Write-Host "🏗️ Building Windows release..." -ForegroundColor Yellow
flutter build windows --release

# Check if build was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build completed successfully!" -ForegroundColor Green
    Write-Host "📍 Executable location: build\windows\x64\runner\Release\super_locker.exe" -ForegroundColor Cyan
    
    # Show file size
    $exePath = "build\windows\x64\runner\Release\super_locker.exe"
    if (Test-Path $exePath) {
        $fileSize = (Get-Item $exePath).Length / 1MB
        Write-Host "📊 File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "🚀 Production build ready for deployment!" -ForegroundColor Green
} else {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
} 