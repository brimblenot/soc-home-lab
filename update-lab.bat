@echo off
REM ============================================================
REM  SOC Lab - push progress to GitHub
REM  Double-click it, type what you did, and it commits + pushes.
REM  (Uses your stored GitHub token - no login prompt.)
REM ============================================================

cd /d "%~dp0"

REM Use command-line text as the message, or prompt if double-clicked.
set "MSG=%*"
if "%MSG%"=="" set /p "MSG=Describe what you did (commit message): "
if "%MSG%"=="" set "MSG=Lab progress update"

echo.
echo Staging changes...
git add -A
git commit -m "%MSG%"
git push

echo.
echo Done.
pause
