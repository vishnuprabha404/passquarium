# Super Locker Desktop Shortcut Creator
# This script creates a desktop shortcut for the Super Locker application
# Called automatically after successful Windows build

param(
    [Parameter(Mandatory=$true)]
    [string]$ExePath
)

try {
    # Verify the executable exists
    if (!(Test-Path $ExePath)) {
        Write-Error "Executable not found at: $ExePath"
        exit 1
    }

    # Get desktop path
    $Desktop = [Environment]::GetFolderPath('Desktop')
    $ShortcutPath = Join-Path $Desktop 'Super Locker.lnk'
    
    # Remove existing shortcut if it exists
    if (Test-Path $ShortcutPath) {
        Remove-Item $ShortcutPath -Force
        Write-Host "Removed existing shortcut"
    }

    # Create new shortcut
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $ExePath
    $Shortcut.WorkingDirectory = (Split-Path $ExePath)
    $Shortcut.Description = 'Super Locker - Secure Password Manager'
    $Shortcut.IconLocation = "$ExePath,0"
    # Add arguments to show console for debugging (remove in production)
    $Shortcut.Arguments = ""
    $Shortcut.WindowStyle = 1  # Normal window
    $Shortcut.Save()
    
    # Also create a debug version that shows console output
    $DebugShortcutPath = Join-Path $Desktop 'Super Locker (Debug).lnk'
    $DebugShortcut = $WScriptShell.CreateShortcut($DebugShortcutPath)
    $DebugShortcut.TargetPath = "cmd.exe"
    $DebugShortcut.Arguments = "/k `"cd /d `"$(Split-Path $ExePath)`" && `"$ExePath`"`""
    $DebugShortcut.WorkingDirectory = (Split-Path $ExePath)
    $DebugShortcut.Description = 'Super Locker - Debug Mode (shows console output)'
    $DebugShortcut.IconLocation = "$ExePath,0"
    $DebugShortcut.Save()
    
    Write-Host "✅ Desktop shortcut created successfully: $ShortcutPath" -ForegroundColor Green
    Write-Host "✅ Debug shortcut created: $DebugShortcutPath" -ForegroundColor Yellow
    Write-Host "   Target: $ExePath" -ForegroundColor Gray
    Write-Host "   Working Directory: $(Split-Path $ExePath)" -ForegroundColor Gray
    Write-Host "   Use the Debug shortcut to see any error messages" -ForegroundColor Yellow
    
} catch {
    Write-Error "Failed to create desktop shortcut: $($_.Exception.Message)"
    exit 1
} 