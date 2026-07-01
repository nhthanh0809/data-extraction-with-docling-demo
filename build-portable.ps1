# build-portable.ps1
# =========================================================================
# Build a fully offline, zero-install Windows bundle for the Docling
# loan-file extractor. Output: dist\docling-app-portable\
#
# Run this on a Windows x64 machine (the BUILD machine) with internet.
# The resulting folder can be zipped and copied to any Windows 10/11 x64
# laptop -- the customer just extracts and double-clicks Chay-app.bat.
# No Python, no Docker, no Tesseract, no admin rights required on the
# target machine.
#
# BUILD PREREQUISITES (on this machine only):
#   1) Windows 10/11 x64
#   2) Internet connection (to download Python embed + wheels + models)
#   3) Tesseract-OCR installed with Vietnamese language pack at:
#        C:\Program Files\Tesseract-OCR\
#      Download: https://github.com/UB-Mannheim/tesseract/wiki
#      During install, tick "Additional language data" -> "Vietnamese".
#
# USAGE:
#   Open PowerShell in this folder, then:
#     powershell -ExecutionPolicy Bypass -File build-portable.ps1
#
# OUTPUT:
#   dist\docling-app-portable\   (~2-3 GB)
#     Zip this folder and hand it to the customer.
# =========================================================================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$PY_VERSION      = "3.11.9"
$PY_EMBED_URL    = "https://www.python.org/ftp/python/$PY_VERSION/python-$PY_VERSION-embed-amd64.zip"
$GET_PIP_URL     = "https://bootstrap.pypa.io/get-pip.py"
$TESSERACT_SRC   = "C:\Program Files\Tesseract-OCR"

$Root = $PSScriptRoot
if (-not $Root) { $Root = (Get-Location).Path }
$Src  = Join-Path $Root "docling-app"
$Out  = Join-Path $Root "dist\docling-app-portable"
$Tmp  = Join-Path $Root "dist\_build_tmp"

Write-Host ""
Write-Host "== Building portable Windows bundle ==" -ForegroundColor Cyan
Write-Host "Source : $Src"
Write-Host "Output : $Out"
Write-Host ""

# ---- 0. Pre-flight checks --------------------------------------------------
if (-not (Test-Path (Join-Path $Src "server.py"))) {
    throw "server.py not found in $Src. Run this script from the repo root."
}
if (-not (Test-Path $TESSERACT_SRC)) {
    throw @"
Tesseract-OCR not found at $TESSERACT_SRC.
Install the UB Mannheim build with the Vietnamese language pack, then re-run:
    https://github.com/UB-Mannheim/tesseract/wiki
"@
}
if (-not (Test-Path (Join-Path $TESSERACT_SRC "tessdata\vie.traineddata"))) {
    throw "Vietnamese language pack missing: $TESSERACT_SRC\tessdata\vie.traineddata"
}

# Clean previous build
if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
if (Test-Path $Tmp) { Remove-Item -Recurse -Force $Tmp }
New-Item -ItemType Directory -Force -Path $Out | Out-Null
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

# ---- 1. Download embedded Python -------------------------------------------
Write-Host "[1/6] Downloading embedded Python $PY_VERSION..." -ForegroundColor Green
$pyZip = Join-Path $Tmp "python-embed.zip"
Invoke-WebRequest -Uri $PY_EMBED_URL -OutFile $pyZip -UseBasicParsing
$pyDir = Join-Path $Out "python"
Expand-Archive -Path $pyZip -DestinationPath $pyDir -Force

# Enable `import site` in the ._pth file so pip-installed packages are found
$pthFile = Get-ChildItem -Path $pyDir -Filter "python*._pth" | Select-Object -First 1
if (-not $pthFile) { throw "python*._pth not found in $pyDir" }
$pth = Get-Content $pthFile.FullName
$pth = $pth -replace "^#\s*import site", "import site"
if (-not ($pth -match "^import site")) { $pth += "`nimport site" }
Set-Content -Path $pthFile.FullName -Value $pth -Encoding ASCII

$pyExe = Join-Path $pyDir "python.exe"

# ---- 2. Bootstrap pip ------------------------------------------------------
Write-Host "[2/6] Bootstrapping pip..." -ForegroundColor Green
$getPip = Join-Path $Tmp "get-pip.py"
Invoke-WebRequest -Uri $GET_PIP_URL -OutFile $getPip -UseBasicParsing
& $pyExe $getPip --no-warn-script-location
if ($LASTEXITCODE -ne 0) { throw "get-pip.py failed" }

# ---- 3. Install requirements (this is the slow part) ----------------------
Write-Host "[3/6] Installing Python packages -- this can take 5-15 minutes..." -ForegroundColor Green
$reqs = Join-Path $Src "requirements.txt"
& $pyExe -m pip install --no-warn-script-location --no-cache-dir -r $reqs
if ($LASTEXITCODE -ne 0) { throw "pip install failed" }

# ---- 4. Copy app source ---------------------------------------------------
Write-Host "[4/6] Copying app source..." -ForegroundColor Green
Copy-Item (Join-Path $Src "server.py") $Out
Copy-Item (Join-Path $Src "web")       $Out -Recurse

# ---- 5. Download Docling models (~500 MB) ---------------------------------
Write-Host "[5/6] Downloading Docling models (~500MB, one-time)..." -ForegroundColor Green
$modelsDir = Join-Path $Out "docling-models"
$doclingTools = Join-Path $pyDir "Scripts\docling-tools.exe"
if (Test-Path $doclingTools) {
    & $doclingTools models download -o $modelsDir
} else {
    # Fallback: invoke via python -m
    & $pyExe -m docling.cli.tools models download -o $modelsDir
}
if ($LASTEXITCODE -ne 0) { throw "docling-tools models download failed" }

# ---- 6. Copy Tesseract ----------------------------------------------------
Write-Host "[6/6] Copying Tesseract-OCR..." -ForegroundColor Green
Copy-Item $TESSERACT_SRC (Join-Path $Out "tesseract") -Recurse

# ---- Write portable launcher ---------------------------------------------
$launcher = @'
@echo off
title App trich xuat ho so (portable, offline)
cd /d "%~dp0"

REM Su dung Python + Tesseract da dong goi trong folder nay, khong dung he thong
set "PATH=%~dp0tesseract;%~dp0python;%PATH%"
set "TESSDATA_PREFIX=%~dp0tesseract\tessdata"
set "DOCLING_OCR=tesseract"
set "DOCLING_ARTIFACTS_PATH=%~dp0docling-models"
set "HF_HUB_OFFLINE=1"
set "TRANSFORMERS_OFFLINE=1"

echo.
echo   Dang khoi dong app (portable, hoan toan offline)...
echo   Neu Windows Firewall hoi lan dau: chon "Allow access" tren mang Private/Work.
echo.

REM Mo trinh duyet local sau 6 giay
start "" /min cmd /c "timeout /t 6 >nul & start http://127.0.0.1:8000"

"%~dp0python\python.exe" server.py
echo.
echo App da dung. Nhan phim bat ky de dong cua so.
pause >nul
'@
Set-Content -Path (Join-Path $Out "Chay-app.bat") -Value $launcher -Encoding ASCII

# ---- Write end-user README ------------------------------------------------
$readme = @'
APP TRICH XUAT HO SO -- BAN PORTABLE (khong can cai dat)
=========================================================

CACH DUNG
---------
1. Giai nen toan bo folder nay ra o cung (vi du: D:\docling-app-portable\).
2. Nhap dup vao Chay-app.bat.
3. Lan dau chay, Windows Firewall se hoi -> chon "Allow access".
4. Trinh duyet tu mo tai  http://127.0.0.1:8000
5. Upload ho so, cho vai giay, xem ket qua, xuat bao cao Word.

DEMO CHIA SE QUA WI-FI (may khac cung mang truy cap)
----------------------------------------------------
Cua so den se hien 2 URL, vi du:
    Tren may nay:    http://127.0.0.1:8000
    Qua LAN/Wi-Fi:   http://192.168.1.42:8000

Tren may thu 2 cung mang Wi-Fi, mo trinh duyet vao URL LAN o tren.

OFFLINE
-------
App khong goi ra internet. Toan bo Python, thu vien, model Docling,
va Tesseract deu da dong goi san trong folder nay.

DUNG APP
--------
Dong cua so den (cmd) hoac bam Ctrl+C trong cua so do.
'@
Set-Content -Path (Join-Path $Out "README.txt") -Value $readme -Encoding UTF8

# ---- Cleanup --------------------------------------------------------------
Remove-Item -Recurse -Force $Tmp

# ---- Summary --------------------------------------------------------------
Write-Host ""
Write-Host "== BUILD DONE ==" -ForegroundColor Cyan
$sizeGB = [math]::Round(((Get-ChildItem -Recurse $Out | Measure-Object -Sum Length).Sum / 1GB), 2)
Write-Host "Bundle : $Out"
Write-Host "Size   : ~$sizeGB GB"
Write-Host ""
Write-Host "Test locally:"
Write-Host "    cd '$Out'"
Write-Host "    .\Chay-app.bat"
Write-Host ""
Write-Host "Deliver to customer:"
Write-Host "    Compress '$Out' to a ZIP, send it, they extract and double-click Chay-app.bat."
Write-Host ""
