# Backend hỏi đáp LuxFinance

Chạy trong thư mục backend với Python 3.10–3.12:

```bash
python -m venv .venv
# Windows PowerShell: .venv\Scripts\Activate.ps1
# Git Bash: source .venv/Scripts/activate
# Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
```

Sao chép `.env.example` thành `.env`, điền đúng Firebase project đang dùng trong Flutter và đường dẫn tuyệt đối đến service-account JSON. Khóa này chỉ đặt trên máy chủ. Firebase Admin dùng Application Default Credentials để kiểm tra token và trạng thái thu hồi.

```bash
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
python -m unittest discover -s tests -v
```

Swagger: http://localhost:8000/docs. Health: http://localhost:8000/health.

`POST /api/v1/chat/ask`: header `Authorization: Bearer <Firebase ID token>`; body:

```json
{
  "question": "Tháng này tôi chi bao nhiêu cho ăn uống?",
  "user_id": "uid-dang-dang-nhap",
  "transactions": [{"id":"a", "money":-50000, "dateTime":"2026-10-02T10:00:00+07:00", "categoryId":"eating"}],
  "category_catalog": [{"id":"eating","index":1,"display_name":"Ăn uống","parent":"expense_living"}],
  "advisor_context": {"budgets":[], "history_complete":false}
}
```

Response có `answer`, `intent`, `evidence`, `warnings`, đôi khi có `needsInput`. Câu ngoài phạm vi trả `intent=out_of_scope`, không phát sinh phân tích ML. Câu rỗng/quá dài trả 422, không đăng nhập trả 401, uid không khớp trả 403.

Chat là bộ nhận diện ý định và các thuật toán tài chính hiện có, chưa phải LLM hiểu mọi câu. Mỗi câu hỏi độc lập; câu tiếp nối như “còn tháng trước?” cần ghi lại nội dung đầy đủ. Dữ liệu gửi lên được dùng để phân tích, không lưu hay sửa giao dịch. Token xác thực người gửi; backend này chưa tự đọc Firestore để xác minh từng giao dịch. Firestore rules trên ứng dụng phải bảo vệ chỉ mục và quyền đọc giao dịch.

Giữ các router phân tích cũ để tương thích. Chỉ `/chat/ask` có lớp xác thực Firebase trong gói này; cần bổ sung phân quyền cho các endpoint cũ trước khi công khai chúng. Health chỉ báo service được nạp, không khẳng định mô hình đã huấn luyện cho từng tài khoản.

Ngân sách chat hỗ trợ tháng hiện tại, bất thường theo tháng, dự báo 1–30 ngày tới. Khi thiếu TensorFlow hoặc dữ liệu, dự báo dùng baseline có cảnh báo. K-Means/Isolation Forest phải có đủ dữ liệu mới kết luận theo mô hình.

`financial_qa_training_data.json` được thay bằng tập câu mẫu gọn, dùng ID cha/con chuẩn; bỏ câu đệm, biến thể lặp và câu khả năng thanh toán tự sinh cho mọi danh mục. File này không phải mô hình đã train. Tái tạo:

```bash
python -m app.services.generate_financial_qa_dataset
```
