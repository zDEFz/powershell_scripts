@echo off
taskkill /f /im sunshine.exe
timeout /t 2 /nobreak
start "" "C:\Program Files\Sunshine\sunshine.exe"