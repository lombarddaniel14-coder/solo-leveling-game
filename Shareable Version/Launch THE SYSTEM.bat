@echo off
rem Launches THE SYSTEM from whatever folder this file is sitting in.
rem Prefers Microsoft Edge app mode (clean, chromeless window); falls back to your default browser.

set "HERE=%~dp0"
set "HTMLFILE=%HERE%THE SYSTEM.html"
set "APPURL=file:///%HERE:\=/%THE SYSTEM.html"
set "EDGE86=C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
set "EDGE64=C:\Program Files\Microsoft\Edge\Application\msedge.exe"

if not exist "%HTMLFILE%" (
  echo Could not find "THE SYSTEM.html" next to this launcher.
  echo Keep both files in the same folder.
  pause
  exit /b
)

if exist "%EDGE86%" (
  start "" "%EDGE86%" --app="%APPURL%"
  exit /b
)
if exist "%EDGE64%" (
  start "" "%EDGE64%" --app="%APPURL%"
  exit /b
)
where msedge >nul 2>&1 && (
  start "" msedge --app="%APPURL%"
) || (
  start "" "%HTMLFILE%"
)
