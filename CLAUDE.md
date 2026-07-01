# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **single-folder, single-click, fully offline** desktop-style app for Vietnamese loan-file (hồ sơ tín dụng) extraction and Word report generation. The whole app is one FastAPI process that both runs the Docling document-reading pipeline *and* serves the static HTML UI — there is no separate frontend build, no bundler, no framework.

Everything user-facing lives under `docling-app/`. The top-level repo directory is otherwise empty by design (the app is meant to be handed off as that one folder).

## Running the app

The app is launched via the OS-specific launcher scripts, which create a `venv/`, `pip install -r requirements.txt` on first run, then start uvicorn on `127.0.0.1:8000`:

- Windows: double-click `docling-app/Chay-app-Windows.bat`
- macOS/Linux: `./docling-app/run-mac-linux.sh`

Direct dev command (once venv is active):
```
cd docling-app && python -m uvicorn server:app --host 127.0.0.1 --port 8000 --reload
```

Health check: `GET /health` — returns `{ok, detail, ocrEngine}` and confirms Docling is importable.

There are no tests, no linter config, and no build step. Do not invent them.

## OCR / offline knobs (environment variables)

The launchers set these; when changing OCR behavior, prefer editing the launcher scripts so both platforms stay in sync.

- `DOCLING_OCR` — `tesseract` (default; requires system `tesseract` + `vie` language pack), `easyocr`, or `rapidocr`. See `get_converter()` in `server.py`.
- `DOCLING_ARTIFACTS_PATH` — if set, Docling loads layout/table models from this local folder instead of HuggingFace. The launchers auto-set this to `./docling-models` if that folder exists next to `server.py`. To go air-gapped: run `docling-tools models download -o ./docling-models` on a networked machine, then copy the folder in.
- `HF_HUB_OFFLINE=1` — combined with `DOCLING_ARTIFACTS_PATH` to prevent any network calls at runtime.

## Architecture — the pieces that only make sense together

**`docling-app/server.py` is the entire backend.** It defines three concerns in one file, and they are tightly coupled:

1. **Pydantic schema (`ReportModel` and its child classes)** — Uses `alias_generator=to_camel` with `populate_by_name=True`. This is load-bearing: the schema is defined in Python `snake_case` but serialized as `camelCase` so it drops directly into the frontend's JavaScript state object. **Do not rename fields on one side without updating the other**; the frontend reads keys like `kh.hoTen`, `khoanVay.mucDich`, `ngheNghiep[0].tenCty`, etc. The `autofill()` function's `auto` list uses the camelCase dotted path form (e.g. `"kh.hoTen"`) — the UI uses these paths to highlight auto-filled fields.

2. **Docling converter (lazy singleton via `get_converter()`)** — Constructed on first request, not at import, so `/health` succeeds and startup errors surface as clear API errors instead of import crashes. `read_document()` writes each upload to a tempfile because Docling's converter takes paths, not bytes, and exports as Markdown (which preserves tables — important for CIC and asset tables).

3. **`autofill()` regex heuristics** — Vietnamese-label-based extraction (Họ và tên, CIF, CCCD 12-digit, Mục đích cấp tín dụng, …). This is intentionally simple string matching over the concatenated Markdown of all uploaded files, not per-file. New extractable fields go here; the pattern is `setf(target, attr, camelCasePath, _after(text, [labels...]))`.

**The static frontend (`docling-app/web/index.html`)** is a single self-contained HTML file — inline CSS, inline vanilla JS, no build step, no dependencies. It POSTs multipart uploads to `/api/extract`, receives `{model, auto, text, perFile}`, renders the form pre-filled, highlights fields whose paths appear in `auto`, and shows a warning bar listing entries from `perFile` where `ok:false`. Word export ("Xuất báo cáo Word") is done client-side — search for `exportDoc()` around line 464.

**Static mount ordering matters.** `app.mount("/", StaticFiles(...))` is deliberately the last line of route setup in `server.py` so `/api/*` and `/health` are matched before the catch-all static handler. Adding new API routes below the mount will make them unreachable.

## Error-reporting contract

Per the README: any file that fails to parse or yields <5 chars must be reported in `per_file` with `ok:false` and either `type:"error"` (with `detail`) or `type:"empty"`. It must NOT be included in the combined text passed to `autofill()`. The frontend's warning bar depends on this — do not silently swallow failures.

## Notes / constraints

- Python 3.10+ (uses `list[X]` generics and PEP 604 in schema defaults).
- The app is meant to be distributed as the `docling-app/` folder alone. Do not add files that are only meaningful in a git checkout (CI configs, etc.) without confirming with the user.
- The README (`docling-app/README.txt`) is user-facing Vietnamese documentation for end users, not developer docs — keep it in sync when changing OCR engine flags or the offline-model workflow.
