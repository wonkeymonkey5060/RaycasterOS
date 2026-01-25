@echo off
:: This gets the current folder path
set ROOT=%~dp0
cd /d "%ROOT%"

echo Current Folder: %ROOT%

:: Try to create a dummy file to test permissions
echo test > permission_test.txt
if exist permission_test.txt (echo [OK] Write permissions confirmed) else (echo [FAIL] Cannot write to this folder!)

:: Run NASM with explicit paths
echo.
echo Running NASM...
nasm -f bin "%ROOT%boot.asm" -o "%ROOT%boot.bin"
nasm -f bin "%ROOT%main.asm" -o "%ROOT%main.bin"

copy /b "%ROOT%boot.bin" + "%ROOT%main.bin" RaycasterOS.bin
if %ERRORLEVEL% NEQ 0 (
    echo [FAIL] NASM crashed or couldn't find boot.asm
    pause
    exit /b
)

echo [OK] boot.bin created.
qemu-system-x86_64 -drive file=RaycasterOS.bin,format=raw,if=ide
pause