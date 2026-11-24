@echo off
cd /d "%~dp0"
echo Make a Yugs account an admin
echo.
set /p NAME=Type the username and press Enter: 
node scripts\admin.ts make-admin "%NAME%"
echo.
pause
