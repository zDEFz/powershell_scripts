# Load the FSWatcher module (install if not present)
if (-not (Get-Module -ListAvailable -Name FSWatcherEngineEvent)) {
    Install-Module -Name FSWatcherEngineEvent -Scope CurrentUser -Force
}
Import-Module FSWatcherEngineEvent

# Use an approved verb per PSScriptAnalyzer
function Start-AutoGitWatcher {
    param (
        [Parameter(Mandatory)]
        [string]$RepoPath
    )

    if (-not (Test-Path $RepoPath)) {
        Write-Warning "Path not found: $RepoPath"
        return
    }

    $cleanPathId = "AutoGit_$($RepoPath -replace '[:\\]', '_')"
    Write-Host "Watching: $RepoPath" -ForegroundColor Cyan

    # Set up the file system watcher
    New-FileSystemWatcher `
        -SourceIdentifier $cleanPathId `
        -Path $RepoPath `
        -IncludeSubdirectories `
        -Filter '*' `
        -NotifyFilter FileName, LastWrite |
    Register-EngineEvent -SourceIdentifier $cleanPathId -Action {
        try {
            Start-Sleep -Milliseconds 500  # debounce

            $repo = $Event.Sender.Path
            Set-Location -LiteralPath $repo

            # Only commit if there are changes
            if (-not (& git diff --quiet) -or -not (& git diff --cached --quiet)) {
                & git add -A
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                & git commit -m "Auto-commit on change at $timestamp" 2>$null
                & git push
                Write-Host "✅ Auto-committed: $repo @ $timestamp" -ForegroundColor Green
            }
        } catch {
            Write-Error "Git operation failed in ${repo}: $_"
        }
    } | Out-Null
}

# START WATCHING YOUR REPOS
Start-AutoGitWatcher -RepoPath "C:\Users\blu\Documents\digiface-usb-config"
Start-AutoGitWatcher -RepoPath "C:\Users\blu\Documents\ahk_scripts"
Start-AutoGitWatcher -RepoPath "C:\Users\blu\Documents\powershell_scripts"

Write-Host "`nWatching for changes... Press Ctrl+C to stop." -ForegroundColor Yellow
while ($true) {
    Wait-Event -Timeout 10 | Out-Null
}
