@echo off
REM Abre o servidor multiplayer do Kaido Bakuso neste PC (porta UDP 24600).
REM Uso: duplo clique, ou  tools\run_server.bat 24700   (porta diferente)
set PORT=%1
if "%PORT%"=="" set PORT=24600
cd /d "%~dp0.."
"D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path game -- --server --port=%PORT%
pause
