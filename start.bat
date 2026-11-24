@echo off
cd /d "%~dp0"
start "" /min cmd /c "timeout /t 4 /nobreak >nul & start http://localhost:3000"
npm.cmd start
pause
