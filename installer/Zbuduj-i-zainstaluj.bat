@echo off
chcp 65001 >nul
title Cairn - kompilacja i instalacja spolszczenia
echo.
echo ===========================================
echo  Cairn - kompilacja i instalacja PL
echo ===========================================
echo.
echo Skrypt zbuduje paczke spolszczenia z Twojej kopii gry,
echo a nastepnie ja zainstaluje (z kopia zapasowa oryginalow).
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-And-Install.ps1" %*
exit /b %errorlevel%
