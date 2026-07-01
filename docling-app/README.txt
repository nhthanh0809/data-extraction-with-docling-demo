APP TRÍCH XUẤT HỒ SƠ & LẬP BÁO CÁO — BẢN ĐỘC LẬP (DOCLING, CỤC BỘ)
===================================================================

App độc lập: một thư mục duy nhất gồm cả giao diện và dịch vụ đọc tài liệu
(Docling). Chạy chung trên một máy chủ cục bộ; mọi xử lý diễn ra trên máy bạn,
hồ sơ không gửi ra ngoài.

YÊU CẦU MỘT LẦN
---------------
- Python 3.10+ (Docling là thư viện Python).
- Tesseract OCR kèm gói tiếng Việt 'vie' (mặc định dùng Tesseract):
    Windows: cài bản UB Mannheim, tích chọn Vietnamese.
    Ubuntu : sudo apt-get install tesseract-ocr tesseract-ocr-vie
    macOS  : brew install tesseract tesseract-lang
  (Hoặc dùng EasyOCR: pip install "docling[easyocr]" rồi đặt DOCLING_OCR=easyocr)

CHẠY (một cú nhấp)
------------------
- Windows: nhấp đúp  Chay-app-Windows.bat
- macOS/Linux: chạy  ./run-mac-linux.sh

Lần đầu, trình khởi động tự tạo môi trường và cài thư viện (CẦN MẠNG, vài phút,
tải khá nặng do gồm cả Docling). Những lần sau khởi động nhanh. Trình duyệt tự
mở app tại http://127.0.0.1:8000. Đóng cửa sổ đen để dừng app.

CHẠY HOÀN TOÀN OFFLINE (air-gapped)
-----------------------------------
Docling cần model (bố cục + bảng) tải từ HuggingFace lần đầu. Để ngắt mạng:
  1. Trên máy CÓ mạng:  docling-tools models download -o ./docling-models
  2. Chép thư mục docling-models vào cùng thư mục app này.
     (Trình khởi động tự nhận và đặt DOCLING_ARTIFACTS_PATH.)
  3. Sau khi đã cài thư viện và có model, app chạy không cần mạng.

THÔNG BÁO LỖI ĐỌC
-----------------
Khi đọc, nếu tài liệu nào lỗi hoặc không có nội dung (sẽ KHÔNG xuất hiện trong
báo cáo), app bắn thông báo và hiện bảng cảnh báo ở đầu trang rà soát, liệt kê
đúng các tài liệu đó để bạn kiểm tra và nhập tay.

CẤU TRÚC
--------
  Chay-app-Windows.bat   nhấp đúp để chạy (Windows)
  run-mac-linux.sh       chạy trên macOS/Linux
  server.py              dịch vụ Docling + phục vụ giao diện (một tiến trình)
  requirements.txt       thư viện Python
  web/index.html         giao diện app
  docling-models/        (tùy chọn) model tải sẵn để chạy offline

GHI CHÚ
-------
- Đây là app "một thư mục, một cú nhấp", nhưng vẫn cần Python do Docling là thư
  viện Python — không thể đóng thành một file .exe nhẹ mà vẫn giữ chất lượng Docling.
- Đổi bộ OCR: sửa biến DOCLING_OCR trong file khởi động (tesseract | easyocr).
