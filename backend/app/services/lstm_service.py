import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import List, Dict, Any, Tuple, Optional
from sklearn.preprocessing import MinMaxScaler

# ==============================================================================
# 1. CẤU HÌNH IMPORT & MÔI TRƯỜNG
# ==============================================================================
try:
    from app.schemas.spending import SpendingItem
    from app.schemas.response import TrendPredictionResponse, PredictedValue
    from app.config import settings
    SEQ_LENGTH = getattr(settings, 'LSTM_SEQUENCE_LENGTH', 14)
except ImportError:
    # Fallback dự phòng
    class SpendingItem:
        def __init__(self, money, date_time):
            self.money = money
            self.date_time = date_time
    class PredictedValue:
        def __init__(self, **kwargs):
            self.__dict__ = kwargs
    class TrendPredictionResponse:
        def __init__(self, **kwargs):
            self.__dict__ = kwargs
    SEQ_LENGTH = 14

# Cấu hình TensorFlow
try:
    import tensorflow as tf
    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import LSTM, Dense, Dropout, Input
    from tensorflow.keras.callbacks import EarlyStopping
    from tensorflow.keras.optimizers import Adam
    import os
    os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
    TF_AVAILABLE = True
except ImportError:
    TF_AVAILABLE = False

# ==============================================================================
# 2. CLASS LOGIC CHÍNH: LSTMService
# ==============================================================================

class LSTMService:
    def __init__(self):
        self.sequence_length = SEQ_LENGTH
        self.min_samples_for_dl = 40 
        self.income_scaler = MinMaxScaler(feature_range=(0, 1))
        self.expense_scaler = MinMaxScaler(feature_range=(0, 1))

    # --------------------------------------------------------------------------
    # BƯỚC 1: CHUẨN BỊ DỮ LIỆU
    # --------------------------------------------------------------------------
    def _prepare_daily_data(self, transactions: List[Any]) -> pd.DataFrame:
        if not transactions:
            return pd.DataFrame()

        data = []
        for t in transactions:
            try:
                raw_amount = float(t.money)
                is_income = raw_amount > 0
                abs_amount = abs(raw_amount)

                dt = t.date_time
                if hasattr(dt, 'date'): date_val = dt.date()
                elif isinstance(dt, str): date_val = datetime.strptime(dt, "%Y-%m-%d").date()
                else: date_val = dt

                data.append({
                    'date': pd.to_datetime(date_val),
                    'amount': abs_amount,
                    'is_income': is_income
                })
            except Exception:
                continue

        df = pd.DataFrame(data)
        if df.empty: return pd.DataFrame()

        daily = df.groupby(['date', 'is_income'])['amount'].sum().unstack(fill_value=0.0).reset_index()
        daily.columns.name = None
        
        if False not in daily.columns: daily[False] = 0.0
        if True not in daily.columns: daily[True] = 0.0
        
        daily = daily.rename(columns={True: 'income', False: 'expense'})
        
        if len(daily) > 0:
            full_idx = pd.date_range(start=daily['date'].min(), end=daily['date'].max())
            daily = daily.set_index('date').reindex(full_idx, fill_value=0.0).reset_index()
            daily.rename(columns={'index': 'date'}, inplace=True)

        return daily

    # --------------------------------------------------------------------------
    # BƯỚC 2: CÁC ENGINE DỰ BÁO
    # --------------------------------------------------------------------------
    
    def _predict_lstm(self, values: np.ndarray, scaler, days: int) -> Tuple[List[float], float]:
        try:
            scaled_data = scaler.fit_transform(values.reshape(-1, 1))
            X, y = [], []
            for i in range(len(scaled_data) - self.sequence_length):
                X.append(scaled_data[i:(i + self.sequence_length)])
                y.append(scaled_data[i + self.sequence_length])
            X, y = np.array(X), np.array(y)
            
            if len(X) < 5: return [], 0.0

            model = Sequential([
                Input(shape=(self.sequence_length, 1)),
                LSTM(64, return_sequences=False),
                Dense(32, activation='relu'),
                Dense(1)
            ])
            model.compile(optimizer=Adam(learning_rate=0.001), loss='huber')
            early_stop = EarlyStopping(monitor='loss', patience=3, restore_best_weights=True)
            model.fit(X, y, epochs=30, batch_size=16, verbose=0, callbacks=[early_stop])

            predictions = []
            curr_seq = scaled_data[-self.sequence_length:].reshape(1, self.sequence_length, 1)
            for _ in range(days):
                pred = model.predict(curr_seq, verbose=0)[0, 0]
                predictions.append(pred)
                curr_seq = np.roll(curr_seq, -1, axis=1)
                curr_seq[0, -1, 0] = pred

            pred_inv = scaler.inverse_transform(np.array(predictions).reshape(-1, 1)).flatten()
            return [max(0.0, float(p)) for p in pred_inv], 0.8
        except Exception:
            return [], 0.0

    def _predict_statistical(self, values: np.ndarray, days: int) -> Tuple[List[float], float]:
        n = len(values)
        if n < 1: return [0.0] * days, 0.0
        
        alpha, beta = 0.3, 0.1
        level = values[0]
        trend = values[1] - values[0] if n > 1 else 0
        
        for i in range(1, n):
            prev_level = level
            level = alpha * values[i] + (1 - alpha) * (prev_level + trend)
            trend = beta * (level - prev_level) + (1 - beta) * trend
            
        preds = []
        damped_trend = trend * 0.8
        for h in range(1, days + 1):
            val = level + h * damped_trend
            preds.append(max(0.0, float(val)))

        total_hist = np.sum(values)
        if sum(preds) < 1000 and total_hist > 0:
            daily_avg = total_hist / max(1, n)
            return [float(daily_avg)] * days, 0.4 

        return preds, 0.5

    def _execute_prediction_strategy(self, values: np.ndarray, scaler, days: int) -> Tuple[List[float], float]:
        if TF_AVAILABLE and len(values) >= self.min_samples_for_dl and np.std(values) > 5000:
            p, c = self._predict_lstm(values, scaler, days)
            if p: return p, c
        return self._predict_statistical(values, days)

    # --------------------------------------------------------------------------
    # BƯỚC 3: PHÂN TÍCH XU HƯỚNG (NÂNG CẤP LOGIC)
    # --------------------------------------------------------------------------
    
    def _analyze_trend_text(
        self,
        history: np.ndarray,
        forecast: List[float],
        is_income: bool
    ) -> str:
        """
        Phân tích xu hướng CHỈ DỰA TRÊN LỊCH SỬ.
        Forecast chỉ dùng để xác nhận xu hướng.
        """

        if len(history) < 28:
            return "Chưa đủ dữ liệu (cần ít nhất 28 ngày) để phân tích xu hướng."

        # =========================
        # 1. CHIA LỊCH SỬ CÙNG THANG
        # =========================
        prev_period = history[-28:-14]   # 14 ngày trước
        recent_period = history[-14:]    # 14 ngày gần nhất

        avg_prev = np.mean(prev_period)
        avg_recent = np.mean(recent_period)

        # Bỏ nhiễu cực nhỏ
        if avg_prev < 10000 and avg_recent < 10000:
            return "Không phát sinh đáng kể."

        # % thay đổi lịch sử
        change_rate = (avg_recent - avg_prev) / (avg_prev + 1e-6)

        # =========================
        # 2. XÁC ĐỊNH TREND LỊCH SỬ
        # =========================
        threshold = 0.15  # 15%

        if abs(change_rate) < threshold:
            trend = "stable"
        elif change_rate > 0:
            trend = "up"
        else:
            trend = "down"

        # =========================
        # 3. FORECAST CHỈ ĐỂ XÁC NHẬN
        # =========================
        avg_forecast = np.mean(forecast[:7]) if forecast else avg_recent
        confirm_up = avg_forecast > avg_recent * 1.05
        confirm_down = avg_forecast < avg_recent * 0.95

        # =========================
        # 4. SINH TEXT
        # =========================
        if is_income:
            if trend == "up":
                text = "Thu nhập có xu hướng TĂNG trong thời gian gần đây."
                if confirm_up:
                    text += " Dự báo cho thấy xu hướng này có thể tiếp diễn."
                return text

            if trend == "down":
                text = "Thu nhập đang GIẢM so với giai đoạn trước."
                if confirm_down:
                    text += " Dự báo tiếp tục cho thấy xu hướng giảm."
                return text

            return "Thu nhập duy trì ỔN ĐỊNH."

        # =========================
        # EXPENSE
        # =========================
        if trend == "up":
            text = "Chi tiêu đang TĂNG trong 2 tuần gần đây."
            if confirm_up:
                text += " Dự báo cho thấy chi tiêu vẫn có xu hướng cao."
            return text

        if trend == "down":
            text = "Chi tiêu có xu hướng GIẢM – tín hiệu quản lý tài chính tích cực."
            if confirm_down:
                text += " Dự báo xác nhận xu hướng này."
            return text

        return "Mức chi tiêu đang ỔN ĐỊNH."


    def _generate_smart_recommendation(self, total_inc, total_exp):
        """Đưa ra lời khuyên tài chính"""
        balance = total_inc - total_exp
        
        if total_inc < 1000 and total_exp > 0:
            return "CẢNH BÁO: Bạn đang tiêu dùng mà không có nguồn thu dự kiến. Hãy kiểm soát ngay!"
        
        if balance < 0:
            ratio = abs(balance) / (total_inc if total_inc > 0 else 1)
            if ratio > 0.5:
                return f"BÁO ĐỘNG: Thâm hụt lớn ({abs(balance):,.0f}đ). Cần cắt giảm ngay các khoản không thiết yếu."
            return f"Dự kiến thâm hụt nhẹ {abs(balance):,.0f}đ. Hạn chế mua sắm tuần này."
            
        if balance > 0:
            save_ratio = balance / total_inc if total_inc > 0 else 0
            if save_ratio > 0.3:
                return f"Tài chính rất tốt! Bạn có thể tiết kiệm {balance:,.0f}đ ({(save_ratio*100):.0f}% thu nhập)."
            return f"Tài chính an toàn. Dự kiến dư {balance:,.0f}đ."
            
        return "Tài chính cân bằng."

    # --------------------------------------------------------------------------
    # BƯỚC 4: MAIN FUNCTION
    # --------------------------------------------------------------------------
    def predict_trend(self, user_id: str, transactions: List[Any], prediction_days: int = 7) -> TrendPredictionResponse:
        daily_df = self._prepare_daily_data(transactions)
        
        if daily_df.empty:
            return TrendPredictionResponse(
                success=False, user_id=user_id, predictions=[], 
                summary={}, message="Chưa có dữ liệu giao dịch"
            )

        inc_vals = daily_df['income'].values
        exp_vals = daily_df['expense'].values
        last_date = daily_df['date'].iloc[-1]

        # Chạy dự báo (Forecast)
        inc_preds, inc_conf = self._execute_prediction_strategy(inc_vals, self.income_scaler, prediction_days)
        exp_preds, exp_conf = self._execute_prediction_strategy(exp_vals, self.expense_scaler, prediction_days)

        predictions_obj = []
        for i in range(prediction_days):
            curr_date = last_date + timedelta(days=i+1)
            p_inc = round(inc_preds[i])
            p_exp = round(exp_preds[i])
            
            desc_parts = []
            if p_inc > 0: desc_parts.append(f"Thu {p_inc:,.0f}")
            if p_exp > 0: desc_parts.append(f"Chi {p_exp:,.0f}")
            if not desc_parts: desc_parts.append("Ít biến động")
            
            predictions_obj.append(PredictedValue(
                date=curr_date.strftime('%Y-%m-%d'),
                predicted_income=p_inc,
                predicted_expense=p_exp,
                confidence=round((inc_conf + exp_conf)/2, 2),
                description=", ".join(desc_parts)
            ))

        total_inc = sum(inc_preds)
        total_exp = sum(exp_preds)
        balance = total_inc - total_exp
        
        summary = {
            "predictionPeriod": f"{prediction_days} ngày tới",
            "totalPredictedIncome": round(total_inc),
            "totalPredictedExpense": round(total_exp),
            "predictedBalance": round(balance),
            "trend": {
                # Gọi hàm phân tích mới với đầy đủ lịch sử
                "incomeTrend": self._analyze_trend_text(inc_vals, inc_preds, is_income=True),
                "expenseTrend": self._analyze_trend_text(exp_vals, exp_preds, is_income=False),
                "recommendation": self._generate_smart_recommendation(total_inc, total_exp)
            },
            "modelConfidence": round((inc_conf + exp_conf)/2, 2)
        }

        return TrendPredictionResponse(
            success=True, user_id=user_id, predictions=predictions_obj,
            summary=summary, message="Dự báo thành công"
        )

# Khởi tạo instance
lstm_service = LSTMService()