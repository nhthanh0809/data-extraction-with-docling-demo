@echo off
title App trich xuat ho so (Docling)
cd /d "%~dp0"
where python >nul 2>nul || (echo [Loi] Can cai Python 3.10+ truoc khi chay. & pause & exit /b)
if not exist venv (
  echo Lan dau chay: dang tao moi truong va cai thu vien (can mang, co the mat vai phut)...
  python -m venv venv
  call venv\Scripts\activate.bat
  python -m pip install --upgrade pip
  pip install -r requirements.txt
) else (
  call venv\Scripts\activate.bat
)
set DOCLING_OCR=tesseract
if exist "%~dp0docling-models" set DOCLING_ARTIFACTS_PATH=%~dp0docling-models
start "" /min cmd /c "timeout /t 6 >nul & start http://127.0.0.1:8000"
echo.
echo   Dang khoi dong. URL truy cap (ca LAN qua Wi-Fi) se hien ben duoi.
echo   Neu Windows Firewall hoi, chon "Allow access" tren mang private/work.
echo.
python server.py
pause
