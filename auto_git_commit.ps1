# WIP

# Parameters
$scanPath = "C:\Users\blu\Documents"
$debounceDelaySeconds = 5

# Function to check if a path is inside a .git folder
function IsInGitFolder {
    param([string]$path)

    if ([string]::IsNullOrEmpty($path)) { return $false }

    $fullPath = [System.IO.Path]::GetFullPath($path).TrimEnd('\','/')
    $parts = $fullPath -split '[\\/]+'
    return $parts -contains '.git'
}

# Function to run git commit & push for a repo folder
function CommitAndPushRepo {
    param([string]$repoPath)

    if (-not (Test-Path $repoPath)) {
        Write-Host "[ERROR] Repo path does not exist: $repoPath"
        return
    }

    Write-Host "[INFO] Committing changes in repo: $repoPath"

    Push-Location $repoPath

    git add -A | Out-Null
    $status = git status --porcelain

    if (-not [string]::IsNullOrEmpty($status)) {
        $message = "Auto-commit: Changes detected on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host "[DEBUG] Committing with message: $message"
        git commit -m $message | Out-Null
        Write-Host "[DEBUG] Pushing changes..."
        git push | Out-Null
        Write-Host "[INFO] Changes committed and pushed."
    }
    else {
        Write-Host "[INFO] No changes to commit."
    }

    Pop-Location
}

# Scan for Git repos
function Get-GitRepos {
    param([string]$rootPath)

    $repos = @()
    $folders = Get-ChildItem -Path $rootPath -Directory -Recurse -ErrorAction SilentlyContinue

    foreach ($folder in $folders) {
        if (Test-Path (Join-Path $folder.FullName ".git")) {
            $repos += $folder.FullName
        }
    }

    return $repos
}

# Debounce state: hash table repo path => timer
$debounceTimers = @{}

# Called when a file changes in a repo
function OnFileChanged {
    param([string]$filePath)

    $normalizedFilePath = [System.IO.Path]::GetFullPath($filePath).ToLowerInvariant()

    foreach ($repoPath in $gitRepos) {
        $normalizedRepoPath = [System.IO.Path]::GetFullPath($repoPath).ToLowerInvariant()

        if ($normalizedFilePath.StartsWith($normalizedRepoPath)) {
            if ($debounceTimers.ContainsKey($repoPath)) {
                $debounceTimers[$repoPath].Stop()
                $debounceTimers[$repoPath].Start()
            }
            else {
                $timer = New-Object System.Timers.Timer
                $timer.Interval = $debounceDelaySeconds * 1000
                $timer.AutoReset = $false
                $timer.Enabled = $true

                Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
                    $path = $Event.MessageData
                    CommitAndPushRepo $path
                    $debounceTimers.Remove($path) | Out-Null
                } -MessageData $repoPath | Out-Null

                $debounceTimers[$repoPath] = $timer
            }

            break
        }
    }
}

# --- Main Execution ---

Write-Host "[INFO] Scanning for Git repos in $scanPath"
$gitRepos = Get-GitRepos -rootPath $scanPath

Write-Host "[INFO] Found $($gitRepos.Count) Git repos:"
foreach ($repo in $gitRepos) {
    Write-Host " - $repo"
}

# Set up watchers for each repo
$watchers = @()

foreach ($repoPath in $gitRepos) {
    Write-Host "[INFO] Starting watcher on $repoPath"

    $fsw = New-Object System.IO.FileSystemWatcher
    $fsw.Path = $repoPath
    $fsw.IncludeSubdirectories = $true
    $fsw.NotifyFilter = [IO.NotifyFilters]'FileName, DirectoryName, LastWrite'

    # Event handler function
    $handleChange = {
        $eventArgsLocal = $Event.SourceEventArgs

        if ($null -eq $eventArgsLocal.FullPath -or [string]::IsNullOrEmpty($eventArgsLocal.FullPath)) {
            return
        }

        if (IsInGitFolder $eventArgsLocal.FullPath) {
            return
        }

        $eventType = $Event.EventIdentifier -replace '.*_', ''
        Write-Host "[EVENT] Change detected at $($eventArgsLocal.FullPath) ($eventType)"
        OnFileChanged $eventArgsLocal.FullPath
    }

    # Register all event types
    Register-ObjectEvent $fsw Changed -SourceIdentifier "Changed_$repoPath" -Action $handleChange | Out-Null
    Register-ObjectEvent $fsw Created -SourceIdentifier "Created_$repoPath" -Action $handleChange | Out-Null
    Register-ObjectEvent $fsw Deleted -SourceIdentifier "Deleted_$repoPath" -Action $handleChange | Out-Null
    Register-ObjectEvent $fsw Renamed -SourceIdentifier "Renamed_$repoPath" -Action {
        $eventArgsLocal = $Event.SourceEventArgs
        if ($null -eq $eventArgsLocal.FullPath -or [string]::IsNullOrEmpty($eventArgsLocal.FullPath) -or
            $null -eq $eventArgsLocal.OldFullPath -or [string]::IsNullOrEmpty($eventArgsLocal.OldFullPath)) {
            return
        }

        if (IsInGitFolder $eventArgsLocal.FullPath -or IsInGitFolder $eventArgsLocal.OldFullPath) {
            return
        }

        Write-Host "[EVENT] File renamed from $($eventArgsLocal.OldFullPath) to $($eventArgsLocal.FullPath)"
        OnFileChanged $eventArgsLocal.FullPath
    } | Out-Null

    $fsw.EnableRaisingEvents = $true
    $watchers += $fsw
}

Write-Host "[INFO] Watching for changes... Press Ctrl+C to stop."

# Keep script running until Ctrl+C
try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
}
finally {
    # Cleanup: unregister event handlers and dispose watchers
    Get-EventSubscriber | Unregister-Event
    foreach ($w in $watchers) {
        $w.Dispose()
    }
}
