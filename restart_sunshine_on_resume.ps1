# Define task properties
$TaskName = "RestartSunshineOnWake"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command ""Start-Sleep -s 5; Restart-Service sunshine -Force"""
$User = "SYSTEM" # Runs with highest possible privileges

# XML Trigger for Wake From Sleep (Event ID 1)
$XmlTrigger = @"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and (EventID=1)]]</Select>
  </Query>
</QueryList>
"@

# Create Event Trigger
$Trigger = New-ScheduledTaskTrigger -Xml $XmlTrigger

# Register the new scheduled task
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -User $User -Force
