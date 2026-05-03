@echo off
chcp 65001 >nul
title Cairn - odinstalowanie spolszczenia
echo.
echo ===========================================
echo  Cairn - Odinstalowanie spolszczenia
echo ===========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-CairnPL.ps1" -Uninstall
exit /b %errorlevel%
