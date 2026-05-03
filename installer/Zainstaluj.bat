@echo off
chcp 65001 >nul
title Cairn - instalator spolszczenia
echo.
echo ===========================================
echo  Cairn - Instalator spolszczenia
echo ===========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-CairnPL.ps1" %*
exit /b %errorlevel%
