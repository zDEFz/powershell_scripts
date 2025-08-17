
objShell.Run "powershell.exe -ExecutionPolicy Bypass -File ""C:\Users\blu\Documents\powershell_scripts\install_file_watcher_modules.ps1""", 1
Set objShell = CreateObject("Wscript.Shell")
objShell.Run "powershell.exe -ExecutionPolicy Bypass -File ""C:\Users\blu\Documents\powershell_scripts\auto_git_commit.ps1""", 1
Set objShell = Nothing
