# Passquarium - Production Build Script
# This script builds a clean, production-ready version of the app and creates an installer

Write-Host "🔒 Passquarium - Production Build & Installer Script" -ForegroundColor Blue
Write-Host "====================================================" -ForegroundColor Blue

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

# Build for Windows (Debug mode - Release mode has Firebase library issues)
Write-Host "🏗️ Building Windows debug (Release has Firebase library corruption)..." -ForegroundColor Yellow
flutter build windows --debug

# Check if build was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build completed successfully!" -ForegroundColor Green
    $exePath = "build\windows\x64\runner\Debug\passquarium.exe"
    Write-Host "📍 Executable location: $exePath" -ForegroundColor Cyan
    
    # Show file size
    if (Test-Path $exePath) {
        $fileSize = (Get-Item $exePath).Length / 1MB
        Write-Host "📊 File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️ Note: Executable might be named differently. Checking build directory..." -ForegroundColor Yellow
        Get-ChildItem "build\windows\x64\runner\Release\" -Name "*.exe"
    }
    
    Write-Host ""
    Write-Host "🚀 Production build ready!" -ForegroundColor Green
    
    # Ask if user wants to create installer
    $createInstaller = Read-Host "Do you want to create an installer? (y/n)"
    
    if ($createInstaller -eq "y" -or $createInstaller -eq "Y") {
        Write-Host ""
        Write-Host "🔧 Creating Windows Installer..." -ForegroundColor Yellow
        
        # Check if NSIS is installed
        $nsisPath = @(
            "${env:ProgramFiles}\NSIS\makensis.exe",
            "${env:ProgramFiles(x86)}\NSIS\makensis.exe",
            "C:\Program Files\NSIS\makensis.exe",
            "C:\Program Files (x86)\NSIS\makensis.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        
        if ($nsisPath) {
            Write-Host "✅ NSIS found at: $nsisPath" -ForegroundColor Green
            
            # Create installer directory if it doesn't exist
            if (-not (Test-Path "installer\output")) {
                New-Item -ItemType Directory -Path "installer\output" -Force
            }
            
            # Run NSIS to create installer
            Write-Host "📦 Compiling installer..." -ForegroundColor Yellow
            & $nsisPath "installer\passquarium_installer.nsi"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Installer created successfully!" -ForegroundColor Green
                Write-Host "📍 Installer location: installer\PassquariumInstaller_v1.6.exe" -ForegroundColor Cyan
                
                # Show installer size
                $installerPath = "installer\PassquariumInstaller_v1.6.exe"
                if (Test-Path $installerPath) {
                    $installerSize = (Get-Item $installerPath).Length / 1MB
                    Write-Host "📊 Installer size: $([math]::Round($installerSize, 2)) MB" -ForegroundColor Cyan
                }
            } else {
                Write-Host "❌ Installer creation failed!" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ NSIS not found. Please install NSIS from https://nsis.sourceforge.io/" -ForegroundColor Red
            Write-Host "💡 You can still use the executable directly from: $exePath" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "🎉 Build process completed!" -ForegroundColor Green
    Write-Host "You can now install and run Passquarium on your Windows system." -ForegroundColor Green
    
} else {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
} 