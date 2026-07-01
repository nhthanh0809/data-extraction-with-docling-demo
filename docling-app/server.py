"""
Dịch vụ trích xuất hồ sơ dùng DOCLING — chạy OCR/bóc tách OFFLINE tại máy.

Thay cho OCR trong trình duyệt (Tesseract.js), dịch vụ này dùng Docling để đọc
PDF/ảnh/Word/Excel ngay trên máy (air-gapped được), rồi trả JSON đúng cấu trúc
`model` mà app HTML đang dùng (camelCase) — kèm danh sách tệp lỗi/không có nội
dung để app bắn thông báo.

CHẠY:
    python -m venv venv && . venv/bin/activate    (Windows: venv\\Scripts\\activate)
    pip install -r requirements.txt
    # chọn bộ OCR tiếng Việt (xem README): DOCLING_OCR=tesseract | easyocr
    uvicorn docling_extract_service:app --host 127.0.0.1 --port 8000

OFFLINE: tải sẵn model (docling-tools models download) rồi đặt
    HF_HUB_OFFLINE=1  và/hoặc  DOCLING_ARTIFACTS_PATH=<thư mục model>
"""
from __future__ import annotations

import os
import re
import tempfile

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel


# ============================ SCHEMA (camelCase = khớp frontend) ============================
class Base(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class CaNhan(Base):
    ho_ten: str = ""; cif: str = ""; ngay_sinh: str = ""; cccd: str = ""
    cccd_cap: str = ""; dia_chi_tt: str = ""; noi_o: str = ""; hon_nhan: str = ""


class VoChong(Base):
    ho_ten: str = ""; cif: str = ""; ngay_sinh: str = ""; cccd: str = ""; cccd_cap: str = ""


class NgheNghiep(Base):
    type: str = "Công ty"; ten_cty: str = ""; dia_chi: str = ""; chuc_vu: str = ""; thong_tin: str = ""


class TaiSan(Base):
    loai: str = ""; chi_tiet: str = ""; gia_tri: str = ""


class CIC(Base):
    ho_ten: str = ""; tctd: str = ""; san_pham: str = ""; han_muc: str = ""; du_no: str = ""; tsbd: str = ""


class KhoanVay(Base):
    san_pham: str = ""; muc_dich: str = ""; gia_tri_pa: str = ""; so_tien: str = ""
    so_tien_ghi_chu: str = ""; von_tu_co: str = ""; thoi_han: str = ""


class TSBD(Base):
    loai: str = ""; giay_to: str = ""; gia_tri_hdmb: str = ""; mo_ta: str = ""; dt_dat: str = ""
    dt_san: str = ""; muc_dich_sd: str = ""; nguon_goc: str = ""; nam_ht: str = ""; ty_le_bao_dam: str = ""


class Khoan(Base):
    label: str = ""; value: str = ""


class DanhGia(Base):
    muc_dich: str = ""; thoi_gian: str = ""; so_tien_toi_da: str = ""; tscmnltc: str = ""
    he_so_tra_no: str = ""; von_tu_co: str = ""; ve_du_an: str = ""


class ReportModel(Base):
    kh: CaNhan = CaNhan()
    vc: VoChong = VoChong()
    so_con: str = ""
    nghe_nghiep: list[NgheNghiep] = [NgheNghiep()]
    tai_san: list[TaiSan] = [TaiSan()]
    tai_san_tong: str = ""
    cic: list[CIC] = [CIC()]
    cic_tong: str = ""
    cic_ghi_chu: str = ""
    khoan_vay: KhoanVay = KhoanVay()
    tsbd: TSBD = TSBD()
    thu_nhap_tong: str = ""
    thu_nhap_items: list[Khoan] = [Khoan()]
    chi_phi_tong: str = ""
    chi_phi_items: list[Khoan] = [Khoan()]
    thu_nhap_rong: str = ""
    dti: str = ""
    danh_gia: DanhGia = DanhGia()


# ============================ DOCLING (đọc tài liệu offline) ============================
_converter = None  # khởi tạo lười để báo lỗi rõ ràng nếu thiếu cài đặt


def get_converter():
    """Tạo DocumentConverter của Docling, cấu hình OCR tiếng Việt + offline."""
    global _converter
    if _converter is not None:
        return _converter

    from docling.document_converter import DocumentConverter, PdfFormatOption
    from docling.datamodel.base_models import InputFormat
    from docling.datamodel.pipeline_options import (
        PdfPipelineOptions, TesseractCliOcrOptions, EasyOcrOptions, RapidOcrOptions,
    )

    engine = os.environ.get("DOCLING_OCR", "tesseract").lower()
    if engine == "easyocr":
        ocr = EasyOcrOptions(lang=["vi", "en"])            # tải model EasyOCR (prefetch để offline)
    elif engine == "rapidocr":
        ocr = RapidOcrOptions()                            # ONNX; lưu ý hỗ trợ tiếng Việt hạn chế
    else:
        ocr = TesseractCliOcrOptions(lang=["vie", "eng"])  # cần cài tesseract + gói ngôn ngữ 'vie'

    opts = PdfPipelineOptions()
    opts.do_ocr = True
    opts.do_table_structure = True          # bật TableFormer để đọc bảng (tài sản, CIC...)
    opts.ocr_options = ocr

    artifacts = os.environ.get("DOCLING_ARTIFACTS_PATH")
    if artifacts:
        opts.artifacts_path = artifacts     # trỏ tới model đã tải sẵn -> chạy offline

    _converter = DocumentConverter(
        format_options={InputFormat.PDF: PdfFormatOption(pipeline_options=opts)}
    )
    return _converter


def read_document(filename: str, data: bytes) -> str:
    """Đọc 1 tệp bằng Docling, trả về văn bản (Markdown, giữ cả bảng)."""
    suffix = os.path.splitext(filename)[1] or ".bin"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(data)
        path = tmp.name
    try:
        result = get_converter().convert(path)
        return result.document.export_to_markdown()
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


# ============================ TỰ NHẬN DIỆN TRƯỜNG (quy tắc văn bản) ============================
def _after(t: str, labels: list[str]) -> str:
    for lb in labels:
        m = re.search(re.escape(lb) + r"\s*[:：.]?\s*([^\n|]+)", t, re.I)
        if m and m.group(1).strip():
            return re.sub(r"\s{2,}", " ", m.group(1).strip())[:200]
    return ""


def autofill(model: ReportModel, raw: str) -> list[str]:
    """Điền sẵn các trường cơ bản; trả về danh sách đường dẫn trường đã nhận diện."""
    t = raw.replace("\r", "")
    auto: list[str] = []

    def setf(obj, attr, path, val):
        if val:
            setattr(obj, attr, val)
            auto.append(path)

    setf(model.kh, "ho_ten", "kh.hoTen", _after(t, ["Họ và tên", "Họ tên", "Khách hàng"]))
    setf(model.kh, "ngay_sinh", "kh.ngaySinh", _after(t, ["Ngày, tháng, năm sinh", "Ngày sinh", "Sinh ngày"]))
    setf(model.kh, "dia_chi_tt", "kh.diaChiTT", _after(t, ["Địa chỉ nơi thường trú", "Địa chỉ thường trú", "Nơi thường trú", "Thường trú"]))
    setf(model.kh, "noi_o", "kh.noiO", _after(t, ["Nơi ở hiện tại", "Chỗ ở hiện tại", "Địa chỉ hiện tại"]))
    setf(model.kh, "hon_nhan", "kh.honNhan", _after(t, ["Tình trạng hôn nhân"]))

    m = re.search(r"CIF\s*[:：]?\s*(\d{6,})", t, re.I)
    if m:
        setf(model.kh, "cif", "kh.cif", m.group(1))
    m = re.search(r"\b\d{12}\b", t)
    if m:
        setf(model.kh, "cccd", "kh.cccd", m.group(0))

    setf(model.khoan_vay, "muc_dich", "khoanVay.mucDich", _after(t, ["Mục đích cấp tín dụng", "Mục đích vay vốn", "Mục đích vay"]))
    setf(model.khoan_vay, "thoi_han", "khoanVay.thoiHan", _after(t, ["Thời hạn cấp tín dụng", "Thời hạn cho vay", "Thời hạn vay"]))
    setf(model.khoan_vay, "so_tien", "khoanVay.soTien", _after(t, ["Số tiền cấp tín dụng", "Số tiền vay", "Số tiền đề nghị"]))

    cty = _after(t, ["Tên công ty/tổ chức", "Tên công ty", "Đơn vị công tác", "Nơi công tác"])
    if cty:
        model.nghe_nghiep[0].ten_cty = cty
        auto.append("ngheNghiep.0.tenCty")
    cv = _after(t, ["Chức vụ"])
    if cv:
        model.nghe_nghiep[0].chuc_vu = cv
        auto.append("ngheNghiep.0.chucVu")

    return auto


# ============================ API ============================
class ExtractResult(Base):
    model: ReportModel
    auto: list[str] = []
    text: str = ""
    per_file: list[dict] = []


app = FastAPI(title="Docling Extraction Service (offline)", version="0.1.0")
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"],
)

ALLOWED = {".pdf", ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff",
           ".docx", ".pptx", ".xlsx", ".xls", ".csv", ".html", ".md"}


@app.post("/api/extract", response_model=ExtractResult)
def extract(files: list[UploadFile] = File(default=[])):
    """Đọc các tệp bằng Docling và trả model + danh sách tệp lỗi/không có nội dung."""
    if not files:
        raise HTTPException(400, "Chưa có tệp.")
    per_file: list[dict] = []
    texts: list[str] = []
    for f in files:
        name = f.filename or "file"
        ext = os.path.splitext(name)[1].lower()
        if ext not in ALLOWED:
            per_file.append({"name": name, "ok": False, "type": "error", "detail": "Định dạng không hỗ trợ"})
            continue
        data = f.file.read()
        try:
            text = read_document(name, data)
            clean = (text or "").strip()
            if len(clean) < 5:
                per_file.append({"name": name, "chars": len(clean), "ok": False, "type": "empty"})
            else:
                per_file.append({"name": name, "chars": len(clean), "ok": True})
                texts.append(text)
        except Exception as exc:  # noqa: BLE001
            per_file.append({"name": name, "ok": False, "type": "error", "detail": str(exc)})

    combined = "\n".join(texts)
    model = ReportModel()
    auto = autofill(model, combined)
    return ExtractResult(model=model, auto=auto, text=combined, per_file=per_file)


@app.get("/health")
def health():
    ok = True
    detail = "Docling sẵn sàng (converter khởi tạo khi gọi /api/extract lần đầu)."
    try:
        import docling  # noqa: F401
    except Exception as exc:  # noqa: BLE001
        ok = False
        detail = f"Chưa cài được Docling: {exc}"
    return {"ok": ok, "detail": detail, "ocrEngine": os.environ.get("DOCLING_OCR", "tesseract")}


# ============================ PHỤC VỤ GIAO DIỆN (app độc lập) ============================
# Mount sau cùng để /api/* và /health vẫn được ưu tiên.
from fastapi.staticfiles import StaticFiles  # noqa: E402
_web = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web")
app.mount("/", StaticFiles(directory=_web, html=True), name="web")

if __name__ == "__main__":
    import socket
    import uvicorn

    def _lan_ip() -> str:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.settimeout(0.5)
            s.connect(("10.255.255.255", 1))
            return s.getsockname()[0]
        except OSError:
            return "127.0.0.1"
        finally:
            s.close()

    ip = _lan_ip()
    print()
    print("  App dang chay:")
    print("    Tren may nay:   http://127.0.0.1:8000")
    if ip != "127.0.0.1":
        print(f"    Qua LAN/Wi-Fi:  http://{ip}:8000  <-- may khac cung mang vao URL nay")
    print()
    print("  Dong cua so nay de dung app.")
    print()
    uvicorn.run(app, host="0.0.0.0", port=8000)
