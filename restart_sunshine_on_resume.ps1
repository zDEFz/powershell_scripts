$TaskName = "RestartSunshineOnWake"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command ""Start-Sleep -s 5; Restart-Service sunshine -Force"""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$User = "SYSTEM" # Runs with highest possible privileges

# This part specifically targets the "Wake from Sleep" Event ID 1
$XmlTrigger = @"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and (EventID=1)]]</Select>
  </Query>
</QueryList>
"@

Register-ScheduledTask -TaskName $TaskName -Action $Action -Xml (Get-ScheduledTask -TaskName "Adobe Flash Player Update" | Export-ScheduledTask | % { $_ -replace '(?s)<Triggers>.*</Triggers>', "<Triggers><EventTrigger>$XmlTrigger</EventTrigger></Triggers>" }) -User $User -Force
