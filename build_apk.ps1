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
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    Write-Host "APK location: $apkPath" -ForegroundColor Green
    
    # Open APK location in Windows Explorer
    Write-Host "Opening APK location in Explorer..." -ForegroundColor Cyan
    $fullPath = Resolve-Path $apkPath
    explorer.exe /select,"$fullPath"
    
    exit 0
}

# Approach 2: Build debug APK if release fails
Write-Host "Release build failed, trying debug build..." -ForegroundColor Cyan
flutter build apk --target-platform android-arm64 --debug

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Debug APK built successfully!" -ForegroundColor Green
    $apkPath = "build\app\outputs\flutter-apk\app-debug.apk"
    Write-Host "APK location: $apkPath" -ForegroundColor Green
    
    # Open APK location in Windows Explorer
    Write-Host "Opening APK location in Explorer..." -ForegroundColor Cyan
    $fullPath = Resolve-Path $apkPath
    explorer.exe /select,"$fullPath"
    
    exit 0
}

# Approach 3: Use split APKs for different architectures
Write-Host "Trying split APKs..." -ForegroundColor Cyan
flutter build apk --split-per-abi --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Split APKs built successfully!" -ForegroundColor Green
    $apkDir = "build\app\outputs\flutter-apk\"
    Write-Host "APK location: $apkDir" -ForegroundColor Green
    Get-ChildItem -Path $apkDir -Filter "*.apk" | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor Green
    }
    
    # Open APK directory in Windows Explorer
    Write-Host "Opening APK directory in Explorer..." -ForegroundColor Cyan
    $fullDir = Resolve-Path $apkDir
    explorer.exe "$fullDir"
    
    exit 0
}

Write-Host "❌ All build approaches failed" -ForegroundColor Red
exit 1 