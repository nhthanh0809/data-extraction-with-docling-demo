#!/bin/sh
cd "$(dirname "$0")"
command -v python3 >/dev/null || { echo "Can cai Python 3.10+"; exit 1; }
if [ ! -d venv ]; then
  echo "Lan dau chay: tao moi truong va cai thu vien (can mang)..."
  python3 -m venv venv
  . venv/bin/activate
  pip install --upgrade pip
  pip install -r requirements.txt
else
  . venv/bin/activate
fi
export DOCLING_OCR=tesseract
[ -d "./docling-models" ] && export DOCLING_ARTIFACTS_PATH="$(pwd)/docling-models"
URL="http://127.0.0.1:8000"
( sleep 6; (command -v open >/dev/null && open "$URL") || (command -v xdg-open >/dev/null && xdg-open "$URL") || true ) &
echo "Dang khoi dong. URL LAN se hien ben duoi (Ctrl+C de dung)."
python server.py
