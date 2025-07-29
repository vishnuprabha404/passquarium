# Passquarium - Windows Installer Creation Script
# This script creates a Windows installer from an existing build

Write-Host "📦 Passquarium - Installer Creation Script" -ForegroundColor Blue
Write-Host "==========================================" -ForegroundColor Blue

# Check if Flutter build exists
$exePath = "build\windows\x64\runner\Debug\passquarium.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "❌ No Flutter build found!" -ForegroundColor Red
    Write-Host "💡 Please run 'flutter build windows --debug' first" -ForegroundColor Yellow
    Write-Host "💡 Or use '.\build_production.ps1' for a complete build + installer" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Flutter build found: $exePath" -ForegroundColor Green

# Check if NSIS is installed
Write-Host "🔍 Looking for NSIS..." -ForegroundColor Yellow
$nsisPath = @(
    "${env:ProgramFiles}\NSIS\makensis.exe",
    "${env:ProgramFiles(x86)}\NSIS\makensis.exe",
    "C:\Program Files\NSIS\makensis.exe",
    "C:\Program Files (x86)\NSIS\makensis.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $nsisPath) {
    Write-Host "❌ NSIS not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "To install NSIS:" -ForegroundColor Yellow
    Write-Host "1. Download from: https://nsis.sourceforge.io/Download" -ForegroundColor Cyan
    Write-Host "2. Install with default settings" -ForegroundColor Cyan
    Write-Host "3. Restart PowerShell and try again" -ForegroundColor Cyan
    exit 1
}

Write-Host "✅ NSIS found: $nsisPath" -ForegroundColor Green

# Create installer output directory
if (-not (Test-Path "installer\output")) {
    Write-Host "📁 Creating installer output directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "installer\output" -Force | Out-Null
}

# Check if installer script exists
if (-not (Test-Path "installer\passquarium_installer.nsi")) {
    Write-Host "❌ Installer script not found: installer\passquarium_installer.nsi" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Installer script found" -ForegroundColor Green

# Create the installer
Write-Host ""
Write-Host "🔧 Creating Windows Installer..." -ForegroundColor Yellow
Write-Host "This may take a few moments..." -ForegroundColor Gray

try {
    # Run NSIS compiler
    & $nsisPath "installer\passquarium_installer.nsi"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Installer created successfully!" -ForegroundColor Green
        
        # Find the created installer
        $installerPath = "PassquariumInstaller_v1.6.exe"
        if (Test-Path $installerPath) {
            $installerSize = (Get-Item $installerPath).Length / 1MB
            Write-Host "📍 Installer location: $installerPath" -ForegroundColor Cyan
            Write-Host "📊 Installer size: $([math]::Round($installerSize, 2)) MB" -ForegroundColor Cyan
            
            Write-Host ""
            Write-Host "🎉 Installation Instructions:" -ForegroundColor Green
            Write-Host "1. Run '$installerPath' as Administrator" -ForegroundColor Cyan
            Write-Host "2. Follow the installation wizard" -ForegroundColor Cyan
            Write-Host "3. Launch Passquarium from Start Menu or Desktop" -ForegroundColor Cyan
            
            # Ask if user wants to run the installer
            Write-Host ""
            $runInstaller = Read-Host "Do you want to run the installer now? (y/n)"
            if ($runInstaller -eq "y" -or $runInstaller -eq "Y") {
                Write-Host "🚀 Launching installer..." -ForegroundColor Yellow
                Start-Process -FilePath $installerPath -Verb RunAs
            }
        } else {
            Write-Host "⚠️ Installer created but location unknown. Check current directory." -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Installer creation failed!" -ForegroundColor Red
        Write-Host "Check the NSIS output above for errors." -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ Error creating installer: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✨ Installer creation completed!" -ForegroundColor Green 