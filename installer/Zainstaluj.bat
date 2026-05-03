@echo off
chcp 65001 >nul
title Cairn - instalator spolszczenia
echo.
echo ===========================================
echo  Cairn - Instalator spolszczenia
echo ===========================================
echo.

set "PAYLOAD=%~dp0payload\localizationen_assets_all.bundle"
if exist "%PAYLOAD%" (
    rem Mamy gotowy payload - instalujemy bezposrednio
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-CairnPL.ps1" %*
) else (
    rem Brak payloadu (typowo gdy uzytkownik pobral repo z GitHuba) - buduj z gry
    echo Payload nie znaleziony - uruchamiam tryb kompilacji z gry...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-And-Install.ps1" %*
)

exit /b %errorlevel%
