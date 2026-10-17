# LuxFinance — cập nhật server AI để kết nối server quản trị riêng

Bản cập nhật dựa trên các file bạn gửi lúc 16:42–16:43 ngày 17/10/2026. Đây là phần SERVER AI đang chạy tại https://datn-luxfinance.onrender.com. Server quản trị mới của bạn tiếp tục chạy riêng.

## Cách thay file

1. Giải nén rồi chép nội dung thư mục `ai-server-update` vào thư mục backend AI hiện có, đúng vị trí `main.py` và `app/`.
2. Giữ `app/config.py`, `app/schemas/` và các file khác của dự án hiện tại. Chúng chưa có trong lần gửi này nên ZIP không tạo lại hoặc thay chúng.
3. Giữ credential Firebase hiện tại ở máy/server. Không có private key trong ZIP.
4. Commit/push các file cập nhật vào repo AI, rồi deploy lại Render bằng quy trình hiện có. Phiên tạo file chưa push/deploy hoặc ghi vào Firebase thật.

Nếu chỉ tải `main.py`, vẫn phải có đầy đủ các module `admin_analysis.py`, `admin_evaluation_capture.py`, `admin_evaluation_jobs.py` trong ZIP này. Các module được cập nhật để dùng cơ chế khởi tạo Firebase hiện tại của bạn.

## main.py đã cập nhật đầy đủ

Giữ cấu hình FastAPI, CORS, requestId, xử lý lỗi, health, root, info và 6 router app hiện tại.

Bổ sung:

```python
from app.routers.admin_analysis import router as admin_analysis_router
app.include_router(admin_analysis_router)
```

Router mới được đăng ký riêng vì đã có prefix `/api/v1/admin/evaluations`; không gắn `settings.API_V1_PREFIX` lần hai.

## Các file AI mới hoặc được cập nhật

- `app/routers/admin_analysis.py`: hai endpoint quản trị AI; khởi tạo Firebase bằng `_firebase_app()` của `app/security/firebase_auth.py` bạn gửi. Kiểm tra ID token với `check_revoked=True` và quyền admin; lỗi cấu hình Firebase trả 503, không gán nhầm thành sai tài khoản.
- `app/services/admin_evaluation_capture.py`: lưu metadata sau phân tích vào `admin_ai_evaluations`; dùng lại cấu hình credential hiện có. Lỗi lưu không làm hỏng response phân tích cho app.
- `app/services/admin_evaluation_jobs.py`: tác vụ nền, chọn UID/tháng, giới hạn lịch sử, lease chống chạy nhiều job quản trị cùng lúc, ghi trạng thái tiến độ.
- Ba service `lstm_service.py`, `kmeans_service.py`, `isolation_forest_service.py`: lấy từ bản mới nhất bạn gửi; chỉ thêm decorator ghi metadata cho phương thức public, giữ nguyên thuật toán.
- Các file router/service/taxonomy/JSON/security khác bạn gửi được đặt lại tên chuẩn và giữ nguyên nội dung.

Hai endpoint mới trên SERVER AI:

```text
POST /api/v1/admin/evaluations/run
GET  /api/v1/admin/evaluations/jobs/{id}
```

Các endpoint đều yêu cầu Firebase ID token admin. Token phải thuộc cùng project Firebase với server AI; role tại `users/<uid>` phải là `admin` và `isActive: true`, hoặc custom claim `admin: true`. Document `isActive: false` luôn chặn quyền admin.

Không thay ownership check ở các endpoint dự báo/chat/phân cụm/phát hiện của ứng dụng.

## Server quản trị riêng

Tiếp tục dùng phần `ADMIN_SERVER` và `WEB_ADMIN` trong gói `LuxFinance_AI_Connection.zip` đã gửi trước. Gói hiện tại chỉ thay phần AI_SERVER bằng bản đã ghép đúng `main.py` và cơ chế Firebase mới nhất.

Trên SERVER QUẢN TRỊ, đặt:

```text
AI_ANALYSIS_API_BASE_URL=https://datn-luxfinance.onrender.com
```

Web admin giữ `apiBaseUrl` trỏ SERVER QUẢN TRỊ, không trỏ trực tiếp server AI. Server quản trị không cần TensorFlow.

## Kết quả thực tế hiển thị

- LSTM: MAE trên holdout của LSTM và baseline, số mẫu/horizon. Đây là holdout chọn mô hình, không phải test độc lập hay accuracy của ensemble. Khi thiếu lịch sử hoặc TensorFlow không khả dụng, lưu trạng thái chưa đủ điều kiện, không tạo MAE giả bằng 0.
- K-Means: Silhouette, số cụm K, số mẫu/đặc trưng khi score có ý nghĩa. Silhouette không phải accuracy.
- Isolation Forest: số giao dịch/số phát hiện IF và rule/tỷ lệ bất thường hybrid; chưa có nhãn kiểm chứng nên không ghi precision, recall, F1 hoặc accuracy.

Admin job lấy các ID từ `data/<uid>`, rồi đọc `spending/<id>`; tối đa 5.000 ID/lượt, không âm thầm cắt lịch sử. Giữ dấu tiền, loại các bản ghi có owner rõ ràng khác UID, ghi số document thiếu/xung đột. Không khẳng định chỉ mục bao phủ đầy đủ lịch sử. LSTM đánh giá lịch sử đến hết tháng đã chọn hoặc thời điểm hiện tại; K-Means/IF phân tích tháng đã chọn.

Đọc/ghi metadata có phát sinh lượt Firestore. Các ngày không ghi nhận trong chuỗi được engine gốc điền 0; số đo phản ánh giả định đó. Tác vụ chạy trong process AI; restart/deploy trong khi chạy có thể làm gián đoạn; lease hết sau 60 phút. Không phải hàng đợi bền vững.

## Chạy local server AI

Dùng môi trường hiện tại của backend AI và file config/schema đang có. Trong Git Bash, từ thư mục backend AI:

```bash
source .venv/Scripts/activate
python -m pip install -r requirements.txt
export GOOGLE_APPLICATION_CREDENTIALS="DUONG_DAN_THAT_TOI_KHOA_FIREBASE.json"
python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

Nếu chạy cùng máy với server quản trị đang dùng port 8000, đổi server AI sang port khác, ví dụ 8001; trỏ AI_ANALYSIS_API_BASE_URL của server quản trị đến http://127.0.0.1:8001 khi thử local.

Trên Render giữ cách khai báo secret/credential hiện tại của bạn. `_firebase_app()` ưu tiên biến môi trường, secret `/etc/secrets/service-account.json`, vị trí cũ `app/security/service-account.json`, hoặc Application Default Credentials theo mã security đã gửi.

## Kiểm tra

```bash
python -m compileall -q app main.py
python -m unittest discover -s tests -v
```

Đã kiểm tra cú pháp toàn bộ file trong ZIP và 6 kiểm thử khởi tạo/đăng ký router, đường dẫn cũ, health/root, thiếu token, khóa quyền admin và lỗi cấu hình Firebase. Các kiểm thử này dùng dependency giả lập, không khởi tạo khóa thật hoặc huấn luyện mô hình. Đối chiếu AST cho thấy main.py chỉ thêm một import và một include_router.

Chưa chạy toàn bộ ứng dụng với config/schema gốc trong phiên này vì các file đó chưa được cung cấp; chưa deploy lên Render, chưa ghi dữ liệu Firebase thật và chưa chạy huấn luyện TensorFlow thực tế. File `tests_http.py` bạn gửi được giữ lại; chạy bộ đó trong dự án đầy đủ của bạn.
