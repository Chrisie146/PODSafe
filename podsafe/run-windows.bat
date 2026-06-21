@echo off
REM Flutter Windows Build Helper Script
REM This script initializes the Visual Studio build environment before running Flutter

echo Initializing Visual Studio Build Environment...
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" x64

echo.
echo Running Flutter for Windows...
echo This may take several minutes on first build...
echo.

flutter run -d windows
