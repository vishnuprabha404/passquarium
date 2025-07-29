# Passquarium - Production Build Script
# This script builds a clean, production-ready version of the app and creates an installer

Write-Host "Passquarium - Production Build & Installer Script" -ForegroundColor Blue
Write-Host "====================================================" -ForegroundColor Blue

# Check if Flutter is installed
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

Write-Host "SUCCESS: Flutter found" -ForegroundColor Green

# Check if an existing build exists
$exePath = "build\windows\x64\runner\Debug\passquarium.exe"
$shouldBuild = $true

if (Test-Path $exePath) {
    $buildInfo = Get-Item $exePath
    $buildSize = [math]::Round($buildInfo.Length / 1MB, 2)
    $buildDate = $buildInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "EXISTING BUILD FOUND" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Location: $exePath" -ForegroundColor Yellow
    Write-Host "Size: $buildSize MB" -ForegroundColor Yellow
    Write-Host "Built: $buildDate" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Do you want to use the existing build or create a fresh one?" -ForegroundColor Yellow
    Write-Host "1) Use existing build (faster - skip to installer creation)" -ForegroundColor Green
    Write-Host "2) Create fresh build (clean + rebuild - takes ~10 minutes)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Enter your choice (1/2): " -NoNewline -ForegroundColor Yellow
    $buildChoice = [System.Console]::ReadLine()
    
    if ($buildChoice -eq "1") {
        Write-Host ""
        Write-Host "SUCCESS: Using existing build!" -ForegroundColor Green
        $shouldBuild = $false
    } elseif ($buildChoice -eq "2") {
        Write-Host ""
        Write-Host "Starting fresh build process..." -ForegroundColor Yellow
        $shouldBuild = $true
    } else {
        Write-Host ""
        Write-Host "Invalid choice. Defaulting to fresh build..." -ForegroundColor Yellow
        $shouldBuild = $true
    }
}

if ($shouldBuild) {
    # Clean previous builds
    Write-Host ""
    Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
    flutter clean

    # Get dependencies
    Write-Host "Getting dependencies..." -ForegroundColor Yellow
    flutter pub get

    # Analyze code for issues
    Write-Host "Analyzing code..." -ForegroundColor Yellow
    flutter analyze

    # Build for Windows (Debug mode - Release mode has Firebase library issues)
    Write-Host "Building Windows debug (Release has Firebase library corruption)..." -ForegroundColor Yellow
    flutter build windows --debug
} else {
    Write-Host ""
    Write-Host "Skipping build process - using existing build" -ForegroundColor Green
}

# Check if build was successful or if we're using existing build
$buildSuccessful = $false
if ($shouldBuild) {
    if ($LASTEXITCODE -eq 0) {
        $buildSuccessful = $true
        Write-Host "SUCCESS: Build completed successfully!" -ForegroundColor Green
    }
} else {
    # We're using existing build, so consider it successful
    $buildSuccessful = $true
    Write-Host "SUCCESS: Using existing build!" -ForegroundColor Green
}

if ($buildSuccessful) {
    Write-Host "Executable location: $exePath" -ForegroundColor Cyan
    
    # Show file size
    if (Test-Path $exePath) {
        $fileSize = (Get-Item $exePath).Length / 1MB
        Write-Host "File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan
    } else {
        Write-Host "WARNING: Executable might be named differently. Checking build directory..." -ForegroundColor Yellow
        Get-ChildItem "build\windows\x64\runner\Debug\" -Name "*.exe"
    }
    
    Write-Host ""
    Write-Host "Production build ready!" -ForegroundColor Green
    
    # Ask if user wants to create installer
    Write-Host "Do you want to create an installer? (y/n): " -NoNewline -ForegroundColor Yellow
    $createInstaller = [System.Console]::ReadLine()
    
    if ($createInstaller -eq "y" -or $createInstaller -eq "Y") {
        Write-Host ""
        Write-Host "Creating Windows Installer..." -ForegroundColor Yellow
        
        # Check if NSIS is installed
        $nsisPath = @(
            "${env:ProgramFiles}\NSIS\makensis.exe",
            "${env:ProgramFiles(x86)}\NSIS\makensis.exe",
            "C:\Program Files\NSIS\makensis.exe",
            "C:\Program Files (x86)\NSIS\makensis.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        
        if ($nsisPath) {
            Write-Host "SUCCESS: NSIS found at: $nsisPath" -ForegroundColor Green
            
            # Create installer directory if it doesn't exist
            if (-not (Test-Path "installer\output")) {
                New-Item -ItemType Directory -Path "installer\output" -Force | Out-Null
            }
            
            # Run NSIS to create installer
            Write-Host "Compiling installer..." -ForegroundColor Yellow
            & $nsisPath "installer\passquarium_installer.nsi"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "SUCCESS: Installer created successfully!" -ForegroundColor Green
                Write-Host "Installer location: $installerPath" -ForegroundColor Cyan
                
                # Show installer size - check for both v1.6 and v2.0
                $installerPath = "installer\PassquariumInstaller_v2.0.exe"
                $installerPathV16 = "installer\PassquariumInstaller_v1.6.exe"
                
                if (Test-Path $installerPath) {
                    $installerSize = (Get-Item $installerPath).Length / 1MB
                    Write-Host "Installer size: $([math]::Round($installerSize, 2)) MB" -ForegroundColor Cyan
                } elseif (Test-Path $installerPathV16) {
                    $installerPath = $installerPathV16
                    $installerSize = (Get-Item $installerPath).Length / 1MB
                    Write-Host "Installer size: $([math]::Round($installerSize, 2)) MB (v1.6)" -ForegroundColor Cyan
                    Write-Host "Note: Using v1.6 installer (v2.0 not found)" -ForegroundColor Yellow
                } else {
                    Write-Host "ERROR: Installer not found!" -ForegroundColor Red
                    Write-Host "Expected: $installerPath or $installerPathV16" -ForegroundColor Red
                    exit 1
                }
                
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Green
                Write-Host "INSTALLER READY - MANUAL INSTALLATION" -ForegroundColor Green
                Write-Host "========================================" -ForegroundColor Green
                Write-Host ""
                Write-Host "NEXT STEPS:" -ForegroundColor Yellow
                Write-Host "1. Right-click '$($installerPath.Split('\')[-1])' -> 'Run as Administrator'" -ForegroundColor Cyan
                Write-Host "2. Follow the installation wizard" -ForegroundColor Cyan
                Write-Host "3. Software will install to: C:\Program Files\Passquarium\" -ForegroundColor Cyan
                Write-Host "4. Will appear in Control Panel > Add/Remove Programs" -ForegroundColor Cyan
                Write-Host "5. Will create Start Menu shortcut" -ForegroundColor Cyan
                Write-Host ""
               
                
                # Show the exact path of the installer
                Write-Host ""
                $installerFullPath = (Get-Location).Path + "\" + $installerPath
                Write-Host "Installer location: $installerFullPath" -ForegroundColor Cyan
                
                # Ask if user wants to run the installer now
                Write-Host ""
                Write-Host "Do you want to run the installer now? (y/n): " -NoNewline -ForegroundColor Yellow
                $runNow = [System.Console]::ReadLine()
                if ($runNow -eq "y" -or $runNow -eq "Y") {
                    Write-Host "Launching installer..." -ForegroundColor Yellow
                    Start-Process -FilePath $installerPath -Verb RunAs
                }
            } else {
                Write-Host "ERROR: Installer creation failed!" -ForegroundColor Red
            }
        } else {
            Write-Host "ERROR: NSIS not found. Please install NSIS from https://nsis.sourceforge.io/" -ForegroundColor Red
            Write-Host "NOTE: You can still use the executable directly from: $exePath" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "Build process completed!" -ForegroundColor Green
    
} else {
    if ($shouldBuild) {
        Write-Host "ERROR: Build failed!" -ForegroundColor Red
    } else {
        Write-Host "ERROR: Existing build not found or invalid!" -ForegroundColor Red
    }
    exit 1
} 