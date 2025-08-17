Set objShell = CreateObject("Wscript.Shell")

objShell.Run "powershell.exe -ExecutionPolicy Bypass -File ""C:\Users\blu\Documents\powershell_scripts\auto_git_commit.ps1""", 0
Set objShell = Nothing
