@echo off
REM ============================================================
REM  CHAN DOAN loi bundle Docling (portable).
REM  DAT FILE NAY VAO TRONG FOLDER BUNDLE (canh Chay-app.bat),
REM  roi nhap dup de chay. Ket qua ghi ra chan-doan-log.txt.
REM ============================================================
title CHAN DOAN - Docling app
cd /d "%~dp0"
set "PATH=%~dp0tesseract;%~dp0python;%PATH%"
set "LOG=%~dp0chan-doan-log.txt"

if not exist "%~dp0python\python.exe" (
  echo [LOI] Khong tim thay python\python.exe.
  echo Ban co dat file nay DUNG trong folder bundle khong?
  echo Folder phai co: python\  tesseract\  server.py  Chay-app.bat
  pause
  exit /b
)

echo ==== 0. Folder ==== > "%LOG%" 2>&1
echo %~dp0 >> "%LOG%" 2>&1

echo. >> "%LOG%" 2>&1
echo ==== 1. Python version ==== >> "%LOG%" 2>&1
"%~dp0python\python.exe" --version >> "%LOG%" 2>&1

echo. >> "%LOG%" 2>&1
echo ==== 2. import torch ==== >> "%LOG%" 2>&1
"%~dp0python\python.exe" -c "import torch; print('torch OK', torch.__version__)" >> "%LOG%" 2>&1

echo. >> "%LOG%" 2>&1
echo ==== 3. import docling ==== >> "%LOG%" 2>&1
"%~dp0python\python.exe" -c "import docling; print('docling OK')" >> "%LOG%" 2>&1

echo. >> "%LOG%" 2>&1
echo ==== 4. import fastapi/uvicorn ==== >> "%LOG%" 2>&1
"%~dp0python\python.exe" -c "import fastapi, uvicorn; print('fastapi/uvicorn OK')" >> "%LOG%" 2>&1

echo. >> "%LOG%" 2>&1
echo ==== 5. import server.py ==== >> "%LOG%" 2>&1
"%~dp0python\python.exe" -c "import server; print('server import OK')" >> "%LOG%" 2>&1

type "%LOG%"
echo.
echo =====================================================
echo  Da ghi log vao:  chan-doan-log.txt  (cung folder)
echo  Hay gui file do cho dev de kiem tra.
echo =====================================================
pause
