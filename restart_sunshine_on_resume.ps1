#Requires -RunAsAdministrator

$TaskName    = "RestartSunshineOnWake"
$TaskDesc    = "Restarts Sunshine service after PC resumes from sleep/hibernation"
$Action      = New-ScheduledTaskAction -Execute "powershell.exe" `
               -Argument '-NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 5; Restart-Service -Name sunshine -Force -ErrorAction SilentlyContinue"'

$principal   = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# ──────────────────────────────────────────────────────────────
# Event subscription XML for: Resume from sleep (Power-Troubleshooter / Event ID 1)
# This is the standard event that fires after wake from S3/S0ix sleep
# ──────────────────────────────────────────────────────────────
$eventXml = @'
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]</Select>
  </Query>
</QueryList>
'@

$trigger = New-ScheduledTaskTrigger -AtStartup   # dummy trigger — we replace the subscription immediately
$trigger.Subscription = $eventXml
$trigger.Delay = 'PT5S'                          # optional: small delay after event

# Optional: also add workstation unlock (Event ID 4801 from Security-Auditing)
# Many people want both — uncomment if needed
<#
$unlockXml = @'
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">*[System[(EventID=4801)]] and *[EventData[Data[@Name='TargetUserName']!='']] </Select>
  </Query>
</QueryList>
'@
$trigger2 = New-ScheduledTaskTrigger -AtLogOn     # dummy
$trigger2.Subscription = $unlockXml
$trigger2.Delay = 'PT3S'
#>

# Create settings (optional but recommended)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
            -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

# Register (use -Force to overwrite if exists)
Register-ScheduledTask -TaskName $TaskName `
                       -Action $Action `
                       -Principal $principal `
                       -Trigger $trigger `# ,$trigger2 if you add unlock
                       -Description $TaskDesc `
                       -Settings $settings `
                       -Force | Out-Null

Write-Host "Scheduled task '$TaskName' created successfully." -ForegroundColor Green
Write-Host "Trigger: Resume from sleep (Power-Troubleshooter Event ID 1)"
# Write-Host "Additional trigger: Workstation unlock (Security Event ID 4801)"   # if added