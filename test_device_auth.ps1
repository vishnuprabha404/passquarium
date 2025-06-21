# Device Authentication Test Script
# This script builds and tests the app with enhanced debugging for device authentication

Write-Host "Testing Device Authentication on Emulator..." -ForegroundColor Green

# Check if emulator is running
$devices = flutter devices --machine | ConvertFrom-Json
$emulator = $devices | Where-Object { $_.id -like "emulator-*" }

if (-not $emulator) {
    Write-Host "No emulator detected. Please start an emulator first:" -ForegroundColor Red
    Write-Host "1. Run: flutter emulators" -ForegroundColor Yellow
    Write-Host "2. Run: flutter emulators --launch <emulator_id>" -ForegroundColor Yellow
    Write-Host "3. Or use: .\create_s24_emulator.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found emulator: $($emulator.name) ($($emulator.id))" -ForegroundColor Green

# Build debug APK with enhanced logging
Write-Host "Building debug APK with enhanced logging..." -ForegroundColor Cyan
$env:JAVA_OPTS = "-Xmx6144M -XX:MaxMetaspaceSize=2048M"
$env:GRADLE_OPTS = "-Xmx6144M -XX:MaxMetaspaceSize=2048M"

flutter build apk --debug --target-platform android-x64

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Debug build failed. Trying release build..." -ForegroundColor Yellow
    flutter build apk --release --target-platform android-x64
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ APK built successfully!" -ForegroundColor Green
    
    # Install and run on emulator
    Write-Host "Installing APK on emulator..." -ForegroundColor Cyan
    flutter install -d $emulator.id
    
    Write-Host "🎯 App installed! Check emulator for device authentication testing." -ForegroundColor Green
    Write-Host "Look for DEBUG messages in the console output." -ForegroundColor Yellow
    
    # Run with logging
    Write-Host "Running app with logging..." -ForegroundColor Cyan
    flutter run -d $emulator.id --debug
} else {
    Write-Host "❌ Build failed" -ForegroundColor Red
} 