# Passquarium Android APK Build Script
# This script automates the process of building an Android APK for distribution

Write-Host "========================================" -ForegroundColor Blue
Write-Host "PASSQUARIUM ANDROID APK BUILD SCRIPT" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Check if Flutter is installed
Write-Host "Checking Flutter installation..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS: Flutter is installed" -ForegroundColor Green
    } else {
        throw "Flutter not found"
    }
} catch {
    Write-Host "ERROR: Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter and add it to your PATH" -ForegroundColor Red
    exit 1
}

# Clean previous builds
Write-Host ""
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Flutter clean had issues, continuing..." -ForegroundColor Yellow
}

# Get dependencies
Write-Host ""
Write-Host "Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get Flutter dependencies" -ForegroundColor Red
    exit 1
}

# Analyze code
Write-Host ""
Write-Host "Analyzing code for issues..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Code analysis found issues, continuing with build..." -ForegroundColor Yellow
}

# Build Android APK
Write-Host ""
Write-Host "Building Android APK (Release)..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to build Android APK" -ForegroundColor Red
    Write-Host ""
    Write-Host "TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "1. Make sure Android SDK is properly installed" -ForegroundColor Cyan
    Write-Host "2. Run 'flutter doctor' to check for issues" -ForegroundColor Cyan
    Write-Host "3. Ensure Firebase is properly configured" -ForegroundColor Cyan
    Write-Host "4. Try 'flutter clean && flutter pub get' and retry" -ForegroundColor Cyan
    exit 1
}

# Check if APK was created
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    $apkSize = [math]::Round((Get-Item $apkPath).Length / 1MB, 2)
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "ANDROID APK BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "APK DETAILS:" -ForegroundColor Yellow
    Write-Host "Location: $apkPath" -ForegroundColor Cyan
    Write-Host "Size: $apkSize MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "INSTALLATION INSTRUCTIONS:" -ForegroundColor Yellow
    Write-Host "1. Copy the APK to your Android device" -ForegroundColor Cyan
    Write-Host "2. Enable 'Install unknown apps' in device settings" -ForegroundColor Cyan
    Write-Host "3. Tap the APK file to install" -ForegroundColor Cyan
    Write-Host "4. Launch Passquarium from your app drawer" -ForegroundColor Cyan
    Write-Host ""
    
    # Open the folder containing the APK
    Write-Host "Opening folder containing the APK..." -ForegroundColor Green
    $apkFolder = Split-Path $apkPath -Parent
    Start-Process explorer.exe -ArgumentList (Resolve-Path $apkFolder).Path
    
    # Ask if user wants to copy APK to a specific location
    Write-Host ""
    $copyApk = Read-Host "Do you want to copy the APK to a specific location? (y/n)"
    if ($copyApk -eq "y" -or $copyApk -eq "Y") {
        Add-Type -AssemblyName System.Windows.Forms
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select destination folder for APK"
        $folderBrowser.ShowNewFolderButton = $true
        
        if ($folderBrowser.ShowDialog() -eq "OK") {
            $destinationPath = Join-Path $folderBrowser.SelectedPath "PassquariumApp_v2.0.apk"
            Copy-Item $apkPath $destinationPath
            Write-Host "APK copied to: $destinationPath" -ForegroundColor Green
        }
    }
} else {
    Write-Host "ERROR: APK file was not created at expected location" -ForegroundColor Red
    Write-Host "Expected: $apkPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "BUILD PROCESS COMPLETE!" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue 