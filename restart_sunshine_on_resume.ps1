# Define task properties
$TaskName = "RestartSunshineOnWake"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command ""Start-Sleep -s 5; Restart-Service sunshine -Force"""
$User = "SYSTEM"

# Create the trigger using EventTrigger class (works in older PowerShell versions)
$Trigger = New-ScheduledTaskTrigger -EventLogName "System" -EventSource "Microsoft-Windows-Power-Troubleshooter" -EventID 1

# Register the new scheduled task
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -User $User -Force
