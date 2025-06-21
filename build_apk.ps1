# Super Locker APK Build Script
# This script builds the APK with proper memory management

Write-Host "Starting Super Locker APK Build..." -ForegroundColor Green

# Clean the project first
Write-Host "Cleaning Flutter project..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Set Java options for Gradle
$env:JAVA_OPTS = "-Xmx6144M -XX:MaxMetaspaceSize=2048M"
$env:GRADLE_OPTS = "-Xmx6144M -XX:MaxMetaspaceSize=2048M -Dfile.encoding=UTF-8"

# Try building APK with different approaches
Write-Host "Attempting to build APK..." -ForegroundColor Yellow

# Approach 1: Build arm64 only (most common Android architecture)
Write-Host "Building for arm64 architecture..." -ForegroundColor Cyan
flutter build apk --target-platform android-arm64 --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ APK built successfully!" -ForegroundColor Green
    Write-Host "APK location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
    exit 0
}

# Approach 2: Build debug APK if release fails
Write-Host "Release build failed, trying debug build..." -ForegroundColor Cyan
flutter build apk --target-platform android-arm64 --debug

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Debug APK built successfully!" -ForegroundColor Green
    Write-Host "APK location: build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Green
    exit 0
}

# Approach 3: Use split APKs for different architectures
Write-Host "Trying split APKs..." -ForegroundColor Cyan
flutter build apk --split-per-abi --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Split APKs built successfully!" -ForegroundColor Green
    Write-Host "APK location: build\app\outputs\flutter-apk\" -ForegroundColor Green
    Get-ChildItem -Path "build\app\outputs\flutter-apk\" -Filter "*.apk" | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor Green
    }
    exit 0
}

Write-Host "❌ All build approaches failed" -ForegroundColor Red
exit 1 