# LuxFinance ML Backend

Backend API cho ứng dụng quản lý tài chính cá nhân với các tính năng Machine Learning.

## Tính năng

 Service  Thuật toán  Chức năng 

 Dự báo xu hướng:  LSTM -> Dự đoán thu nhập/chi tiêu trong tương lai 
 Phân cụm hành vi:  K-Means -> Phân tích và nhóm thói quen chi tiêu 
 Phát hiện bất thường:  Isolation Forest -> Cảnh báo giao dịch bất thường 

## Cài đặt

### 1. Tạo môi trường ảo

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# Linux/Mac
source venv/bin/activate
```

### 2. Cài đặt dependencies

```bash
pip install -r requirements.txt
```

### 3. Chạy server

```bash
# Development mode (auto-reload)
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Production mode
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

### 4. Truy cập API

- API Docs (Swagger): http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health Check: http://localhost:8000/health

## API Endpoints

### 1. Dự báo xu hướng (LSTM)

```
POST /api/v1/predict/trend
```

Request:
```json
{
  "userId": "user123",
  "transactions": [
    {
      "id": "tx1",
      "money": -50000,
      "type": 0,
      "typeName": "Ăn uống",
      "dateTime": "2024-01-15T12:00:00"
    }
  ],
  "predictionDays": 7
}
```

Response:
```json
{
  "success": true,
  "userId": "user123",
  "predictions": [
    {
      "date": "2024-01-16",
      "predictedIncome": 0,
      "predictedExpense": 45000,
      "confidence": 0.75
    }
  ],
  "summary": {
    "predictionPeriod": "7 ngày",
    "totalPredictedIncome": 500000,
    "totalPredictedExpense": 350000,
    "trend": {...}
  }
}
```

### 2. Phân cụm hành vi (K-Means)

```
POST /api/v1/cluster/behavior
```

Request:
```json
{
  "userId": "user123",
  "transactions": [...],
  "nClusters": 4
}
```

Response:
```json
{
  "success": true,
  "clusters": [
    {
      "clusterId": 0,
      "clusterName": "Chi tiêu thường xuyên",
      "description": "Nhiều giao dịch nhỏ, chi tiêu hàng ngày",
      "characteristics": {...},
      "transactionIds": ["tx1", "tx2"],
      "percentage": 45.5
    }
  ],
  "userProfile": {...},
  "recommendations": [...]
}
```

### 3. Phát hiện bất thường (Isolation Forest)

```
POST /api/v1/detect/anomaly
```

Request:
```json
{
  "userId": "user123",
  "transactions": [...],
  "sensitivity": 0.1
}
```

Response:
```json
{
  "success": true,
  "totalTransactions": 100,
  "anomaliesDetected": 5,
  "anomalies": [
    {
      "transactionId": "tx50",
      "money": -5000000,
      "typeName": "Mua sắm",
      "dateTime": "2024-01-10 15:30",
      "anomalyScore": 0.85,
      "anomalyReason": "Số tiền cao bất thường cho danh mục Mua sắm",
      "severity": "high"
    }
  ],
  "statistics": {...},
  "alerts": [...]
}
```
