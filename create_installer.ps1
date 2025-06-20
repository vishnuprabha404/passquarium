# Super Locker - Windows Installer Creation Script
# This script builds the Flutter app and creates a Windows installer using NSIS

Write-Host "🔒 Super Locker - Windows Installer Creator" -ForegroundColor Blue
Write-Host "=============================================" -ForegroundColor Blue

# Configuration
$AppName = "Super Locker"
$AppVersion = "1.6"
$BuildType = "Release"
$NSISPath = ""

# Function to find NSIS installation
function Find-NSIS {
    $possiblePaths = @(
        "${env:ProgramFiles}\NSIS\makensis.exe",
        "${env:ProgramFiles(x86)}\NSIS\makensis.exe",
        "C:\Program Files\NSIS\makensis.exe",
        "C:\Program Files (x86)\NSIS\makensis.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

# Check if NSIS is installed
$NSISPath = Find-NSIS
if (-not $NSISPath) {
    Write-Host "❌ NSIS not found!" -ForegroundColor Red
    Write-Host "Please install NSIS from: https://nsis.sourceforge.io/Download" -ForegroundColor Yellow
    Write-Host "Or install via Chocolatey: choco install nsis" -ForegroundColor Yellow
    
    $install = Read-Host "Would you like to install NSIS via Chocolatey? (y/n)"
    if ($install -eq 'y' -or $install -eq 'Y') {
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Host "Installing NSIS via Chocolatey..." -ForegroundColor Yellow
            choco install nsis -y
            $NSISPath = Find-NSIS
            if (-not $NSISPath) {
                Write-Host "❌ NSIS installation failed!" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "❌ Chocolatey not found! Please install NSIS manually." -ForegroundColor Red
            exit 1
        }
    } else {
        exit 1
    }
}

Write-Host "✅ NSIS found at: $NSISPath" -ForegroundColor Green

# Check if Flutter is available
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Flutter found" -ForegroundColor Green

# Create installer directory if it doesn't exist
if (-not (Test-Path "installer")) {
    New-Item -ItemType Directory -Path "installer" | Out-Null
    Write-Host "📁 Created installer directory" -ForegroundColor Yellow
}

# Create LICENSE.txt if it doesn't exist
$licensePath = "installer\LICENSE.txt"
if (-not (Test-Path $licensePath)) {
    $licenseContent = @"
MIT License

Copyright (c) 2025 Super Locker Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@
    Set-Content -Path $licensePath -Value $licenseContent
    Write-Host "📄 Created LICENSE.txt" -ForegroundColor Yellow
}

# Step 1: Clean and build Flutter app
Write-Host "🧹 Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

Write-Host "📦 Getting dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "🔍 Analyzing code..." -ForegroundColor Yellow
flutter analyze --no-fatal-warnings

# Step 2: Build Windows release
Write-Host "🏗️ Building Windows release..." -ForegroundColor Yellow
flutter build windows --release

# Check if build was successful
$exePath = "build\windows\x64\runner\Release\super_locker.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "❌ Flutter build failed! Executable not found at: $exePath" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Flutter build completed successfully!" -ForegroundColor Green

# Get file size
$fileSize = (Get-Item $exePath).Length / 1MB
Write-Host "📊 Executable size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan

# Step 3: Create installer using NSIS
Write-Host "📦 Creating Windows installer with NSIS..." -ForegroundColor Yellow

# Change to installer directory
Push-Location installer

try {
    # Run NSIS to create installer
    $nsisArgs = @("super_locker_installer.nsi")
    $process = Start-Process -FilePath $NSISPath -ArgumentList $nsisArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Host "✅ Installer created successfully!" -ForegroundColor Green
        
        # Check if installer was created
        $installerPath = "SuperLockerInstaller_v$AppVersion.exe"
        if (Test-Path $installerPath) {
            $installerSize = (Get-Item $installerPath).Length / 1MB
            Write-Host "📦 Installer: $installerPath" -ForegroundColor Cyan
            Write-Host "📊 Installer size: $([math]::Round($installerSize, 2)) MB" -ForegroundColor Cyan
            Write-Host "📍 Location: $(Resolve-Path $installerPath)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "❌ NSIS compilation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Error running NSIS: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}

# Step 4: Summary
Write-Host ""
Write-Host "🎉 Windows Installer Creation Complete!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "📦 Files created:" -ForegroundColor Cyan
Write-Host "   • Application: $exePath" -ForegroundColor White
Write-Host "   • Installer: installer\SuperLockerInstaller_v$AppVersion.exe" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Test the installer on a clean Windows machine" -ForegroundColor White
Write-Host "   2. Verify all features work correctly after installation" -ForegroundColor White
Write-Host "   3. Consider code signing for production distribution" -ForegroundColor White
Write-Host ""

# Optional: Ask to run installer
$runInstaller = Read-Host "Would you like to test the installer now? (y/n)"
if ($runInstaller -eq 'y' -or $runInstaller -eq 'Y') {
    Write-Host "🚀 Running installer..." -ForegroundColor Yellow
    Start-Process -FilePath "installer\SuperLockerInstaller_v$AppVersion.exe" -Wait
} 