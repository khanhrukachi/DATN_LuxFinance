# LuxFinance — Chat hỏi đáp tài chính theo danh mục cha/con

Đây là bộ cập nhật để tích hợp vào dự án Flutter/FastAPI hiện tại. Không phải một LLM trả lời mọi câu hỏi tự do. Các phép tổng hợp dùng giao dịch thực; model dùng các dịch vụ K-Means, Isolation Forest và LSTM của dự án. Thiếu dữ liệu thì hỏi lại hoặc giải thích giới hạn.

## Cài vào dự án

Bộ này gồm backend `main.py`, `config`, `security`, tất cả routers, schemas, services và 6 file Flutter chat. Schema được bổ sung vì các file bạn gửi chưa có `app/schemas/`. Nếu dự án có schema thêm trường riêng, hợp nhất các trường đó khi thay file.

1. Dùng thư mục `backend/` làm backend, hoặc chép các file vào đúng đường dẫn tương ứng trong backend hiện tại. `main.py` đã đăng ký router, không cần thêm router chat lần nữa. `app/api/chat_router.py` chỉ là import tương thích; router thật nằm ở `app/routers/chat.py`, prefix `/chat` và main gắn `/api/v1` một lần.
2. Chạy bằng Python 3.10–3.12:

```bash
cd backend
python -m venv .venv
# Windows PowerShell: .venv\Scripts\Activate.ps1
# Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
# Sao chép .env.example thành .env và điền project/đường dẫn khóa Firebase.
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Khóa Firebase không nằm trong ZIP. Đặt riêng trên máy chủ và khai báo `GOOGLE_APPLICATION_CREDENTIALS` trong `.env`. Security ưu tiên đường dẫn cấu hình, sau đó vị trí cũ `app/security/service-account.json`, cuối cùng Application Default Credentials. `FIREBASE_PROJECT_ID` phải trùng Firebase project của Flutter. Đường dẫn tương đối tính từ thư mục chạy backend; dùng đường dẫn tuyệt đối để tránh nhầm.

3. Chép các file trong `flutter/` vào `lib/features/financial_chat/`; có file mới `chat_evidence_card.dart`. Giữ `listType` và bản dịch danh mục của app. Tạo catalog từ dữ liệu gốc:

```dart
final catalog = buildChatCatalog(listType,
  (key) => AppLocalizations.of(context).translate(key));
Navigator.push(context, MaterialPageRoute(builder: (_) =>
  FinancialChatScreen(categoryCatalog: catalog)));
```

4. Android Emulator dùng `http://10.0.2.2:8000`. Thiết bị thật dùng IP LAN của máy backend qua `--dart-define=ML_BASE_URL=http://DIA_CHI_LAN:8000`. Hot Restart sau khi thay file. Health: `/health`; Swagger: `/docs`.

## Xác thực và tương thích API

Tất cả endpoint POST phân tích cá nhân (`chat`, `insights`, `predict`, `cluster`, `detect`) yêu cầu `Authorization: Bearer <Firebase ID token>`. UID ở body/query phải khớp token; các endpoint quick giữ nguyên hợp đồng query + JSON cũ. Thiếu token trả 401; sai UID trả 403. Chat Flutter đã gửi token và refresh khi 401. Các màn hình phân tích khác chưa được gửi kèm trong yêu cầu này: nếu còn gọi API không có token, cần thêm cùng header trước khi chạy bản backend mới.

`/health`, `/info`, `/chat/capabilities`, danh sách profiles/severity và Swagger là metadata công khai. Các đường dẫn dưới `/api/v1` lấy prefix từ config. Health báo dịch vụ được nạp; `baseline_only` khi không có TensorFlow, không xác nhận mô hình đã huấn luyện hoặc cấu hình Firebase đã kiểm tra thành công.

`/insights/ask` dùng cùng bộ hỏi đáp với `/chat/ask`, gồm history tối đa 6 tin nhắn. Backend kiểm tra người gửi nhưng không tự đọc Firestore để xác minh nội dung giao dịch client gửi; kết quả là phân tích dữ liệu đầu vào, không dùng làm số liệu quyết toán tin cậy. Không ghi hoặc sửa dữ liệu Firestore.

## Những câu đã hỗ trợ

- Ăn uống tháng này thế nào? Lương tháng này bao nhiêu?
- Chi tiêu sinh hoạt gồm những danh mục nào? Ăn uống thuộc nhóm nào?
- Tổng thu chi hôm nay / tuần này / tháng 8/2026 / năm 2026?
- Ăn uống từ 1/8/2026 đến 15/8/2026 bao nhiêu?
- Ăn uống tháng này bao nhiêu lần? Bình quân mỗi giao dịch / mỗi ngày?
- Ăn uống chiếm tỷ trọng bao nhiêu tháng này?
- Liệt kê 5 giao dịch ăn uống gần nhất tháng này.
- Giao dịch ăn uống lớn nhất tháng này?
- Chi tiêu theo từng danh mục cha / từng danh mục con tháng này.
- So sánh ăn uống và đi lại tháng này.
- So sánh ăn uống tháng 8/2026 với tháng 9/2026.
- So sánh chi tiêu tuần này / năm nay với kỳ trước.
- Ngân sách ăn uống tháng 8/2026 còn bao nhiêu? Danh mục cha có vượt không?
- Phân tích thói quen ăn uống tháng này; tháng này có giao dịch bất thường không?
- Dự báo ăn uống 7 / 14 / 30 ngày tới; dự báo chi tiêu tháng sau.
- Gợi ý tiết kiệm tháng này; phân tích sâu tài chính tháng này.
- Tôi có đủ tiền mua điện thoại 5tr không? (hỏi xác nhận số dư, có thể hỏi giá nếu thiếu)
- Hỏi tiếp “Còn tháng trước?” hoặc “Liệt kê chi tiết” sau câu có danh mục.
- Tìm theo ghi chú/địa điểm với cú pháp rõ ràng: `Chi tháng này ghi chú "phở bò" bao nhiêu?`

## Quy tắc và giới hạn

- Mã ổn định `categoryId` được ưu tiên; chỉ dùng `type` numeric khi có catalog đúng thứ tự `listType`. Không tự đoán index cũ. Danh mục cha là hợp của giao dịch con, mỗi giao dịch chỉ được tính một lần trong tổng.
- Catalog động từ Flutter quyết định danh mục thực tế. Dataset JSON là ví dụ/parser fixture, không phải model đã huấn luyện; không thay giao dịch người dùng.
- So sánh kỳ đang diễn ra mặc định cùng số ngày; muốn cả kỳ đối chiếu thì nêu `cả tháng` / `cả tuần` / `cả năm`.
- Chi tiết trả tối đa 20 giao dịch một câu hỏi. Toàn bộ lịch sử gửi tối đa 10.000 bản ghi, không âm thầm cắt mất dữ liệu. Snapshot có cache 30 giây, Thử lại tải mới.
- Firestore nguồn giao dịch vẫn là `spending.where('userId', isEqualTo: uid)` như file bạn cung cấp. Nếu dữ liệu cũ chỉ lưu liên kết trong `data/<uid>` thì cần adapter riêng dựa trên schema thật; chưa đoán hoặc mở đọc toàn collection. Cần Firestore rules/index phù hợp với truy vấn hiện có.
- Ngân sách gửi tất cả tháng đang hoạt động, mỗi câu chỉ tính tháng được hỏi. Không cộng ngân sách cha và con thành một hạn mức chung.
- Số tiền thu vào có thể gồm vay và thu hồi nợ; đây là dòng tiền vào, không nhất thiết thu nhập kiếm được. Chênh lệch thu chi không phải số dư tài khoản. Số dư trong kiểm tra khả năng trả tiền do người dùng xác nhận trong phiên chat; không ghi ngược vào Firestore.
- LSTM/baseline: cửa sổ 1–30 ngày. Dự báo tháng cũng giới hạn 30 ngày và hiển thị các ngày cụ thể, chưa khẳng định dự báo toàn tháng 31 ngày. Phát hiện bất thường theo tháng; thói quen theo kỳ được hỏi. Gợi ý tích hợp hiện ưu tiên tháng hiện tại, không tự biến thành tư vấn đầu tư hay khẳng định lợi nhuận.
- Hỏi dự báo danh mục sẽ lọc lịch sử đúng danh mục trước khi gọi model; ít dữ liệu sẽ từ chối/baseline theo logic service gốc. Phát hiện bất thường giữ lịch sử để học baseline rồi lọc kết quả theo danh mục, không học chỉ trên giao dịch nghi ngờ.
- Câu ngoài phạm vi hoặc chưa nhận diện rõ sẽ yêu cầu làm rõ; không bảo đảm hiểu mọi cách diễn đạt tiếng Việt, mọi địa điểm/món ăn hoặc kiến thức tài chính ngoài dữ liệu.
- Server không ghi/xóa/sửa giao dịch qua endpoint hỏi đáp.

## HTTP 500 và log

`requestId` được trả khi lỗi và xuất hiện trong traceback Python; Flutter log HTTP status, `serverCode`, `requestId`, không log token hoặc toàn bộ dữ liệu tài chính. Lỗi dữ liệu/nhập ngày trả lời làm rõ; lỗi phụ thuộc trả 503; lỗi nội bộ vẫn trả 500 và ghi traceback thật. Chưa có traceback từ server của bạn nên chưa xác định được lỗi 500 ban đầu.

## Kiểm tra

```bash
# Từ thư mục gốc của gói:
python -m unittest discover -s tests -v
# Trong backend/:
python -m unittest tests_http -v
python -m compileall -q app main.py
# Trong dự án Flutter thật:
flutter analyze lib/features/financial_chat
```

Đã kiểm tra 31 bài hỏi đáp với schemas/config thật và 11 bài HTTP ASGI với routers/services thật, bao gồm tất cả endpoint POST, 401/403, JSON hỏng, câu hỏi tiếp nối, lỗi nội bộ có requestId, đường dẫn khóa từ cấu hình và lọc bất thường theo ID gốc. Firebase verification được mock trong kiểm thử; chưa đăng nhập Firebase/đọc Firestore thật. TensorFlow không có trong môi trường kiểm tra nên dự báo đã chạy baseline, chưa kiểm thử huấn luyện LSTM. Chưa có Flutter/Dart trong môi trường này để chạy biên dịch giao diện.

File JSON training là câu mẫu kiểm thử/parser, không phải LLM đã huấn luyện. Chat hỗ trợ các nhóm câu nêu trên; câu chưa hiểu sẽ hỏi làm rõ. Chưa có traceback Python của HTTP 500 ban đầu nên chưa thể khẳng định nguyên nhân riêng trên máy bạn đã được xác định.
