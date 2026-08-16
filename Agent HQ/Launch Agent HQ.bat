@echo off
rem Launch Agent HQ in an Edge app window (falls back to default browser).
rem Paths are relative to this file, so moving the folder never breaks it.
setlocal
set "HERE=%~dp0"
set "HQ=%HERE%index.html"
set "HQURL=file:///%HERE:\=/%index.html"

set "EDGE=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not exist "%EDGE%" set "EDGE=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if not exist "%EDGE%" set "EDGE=%LocalAppData%\Microsoft\Edge\Application\msedge.exe"

if exist "%EDGE%" (
  start "" "%EDGE%" --app="%HQURL%"
) else (
  start "" "%HQ%"
)
endlocal
