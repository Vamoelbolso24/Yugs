@echo off
REM Double-click before pressing "Push origin" in GitHub Desktop.
REM It checks that nothing private (keys, emails, card pictures, the database) would be published.
cd /d "%~dp0"
node scripts\privacy-check.mjs
echo.
pause
