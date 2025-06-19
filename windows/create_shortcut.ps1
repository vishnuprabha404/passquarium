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
    $Shortcut.Arguments = ""
    $Shortcut.WindowStyle = 1  # Normal window
    $Shortcut.Save()
    
    Write-Host "✅ Desktop shortcut created successfully: $ShortcutPath" -ForegroundColor Green
    Write-Host "   Target: $ExePath" -ForegroundColor Gray
    Write-Host "   Working Directory: $(Split-Path $ExePath)" -ForegroundColor Gray
    
} catch {
    Write-Error "Failed to create desktop shortcut: $($_.Exception.Message)"
    exit 1
} 