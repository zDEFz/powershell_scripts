#Requires -RunAsAdministrator

$TaskName    = "RestartSunshineOnWake"
$TaskDesc    = "Restarts Sunshine service after PC resumes from sleep/hibernation"
$ServiceName = "sunshine"   # ← change if your service has a different name

$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
          -Argument "-NoProfile -WindowStyle Hidden -Command `"Start-Sleep -Seconds 5; Restart-Service -Name '$ServiceName' -Force -ErrorAction SilentlyContinue`""

$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" `
             -LogonType ServiceAccount -RunLevel Highest

# Event subscription XML for resume from sleep (most reliable for wake/resume)
$eventXml = @'
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">
      *[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and (EventID=1)]]
    </Select>
  </Query>
</QueryList>
'@

# Create the event trigger using CIM (this sets Subscription correctly)
$CimTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:Task
$EventTrigger = $CimTriggerClass | New-CimInstance -ClientOnly
$EventTrigger.Enabled = $true
$EventTrigger.Subscription = $eventXml
$EventTrigger.Delay = 'PT5S'   # Optional small delay after event

# Optional: Add unlock trigger (uncomment if wanted)
<#
$unlockXml = @'
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">
      *[System[(EventID=4801)]]
    </Select>
  </Query>
</QueryList>
'@
$UnlockTrigger = $CimTriggerClass | New-CimInstance -ClientOnly
$UnlockTrigger.Enabled = $true
$UnlockTrigger.Subscription = $unlockXml
$UnlockTrigger.Delay = 'PT3S'
#>

$Settings = New-ScheduledTaskSettingsSet -Compatibility Win8 `
            -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
            -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
            -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
            -StartWhenAvailable

# Build the full task object
$Task = New-ScheduledTask -Action $Action `
                          -Principal $Principal `
                          -Trigger $EventTrigger `# , $UnlockTrigger if uncommented
                          -Settings $Settings `
                          -Description $TaskDesc

# Register it (use -Force to overwrite if exists)
Register-ScheduledTask -TaskName $TaskName `
                       -InputObject $Task `
                       -Force | Out-Null

Write-Host "Scheduled task '$TaskName' created successfully." -ForegroundColor Green
Write-Host "Trigger: Resume from sleep (Power-Troubleshooter Event ID 1)"
# Write-Host "Additional trigger: Workstation unlock (Security Event ID 4801)"  # if added