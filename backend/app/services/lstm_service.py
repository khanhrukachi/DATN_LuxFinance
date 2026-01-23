import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import List, Dict, Any, Tuple
from sklearn.preprocessing import MinMaxScaler

try:
    import tensorflow as tf
    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import LSTM, Dense, Dropout
    TF_AVAILABLE = True
except ImportError:
    TF_AVAILABLE = False

from app.schemas.spending import SpendingItem
from app.schemas.response import TrendPredictionResponse, PredictedValue
from app.config import settings


class LSTMService:

    INCOME_TYPES = [8, 9, 10]

    def __init__(self):
        self.sequence_length = settings.LSTM_SEQUENCE_LENGTH
        self.income_scaler = MinMaxScaler(feature_range=(0, 1))
        self.expense_scaler = MinMaxScaler(feature_range=(0, 1))

    def _prepare_daily_data(self, transactions: List[SpendingItem]) -> pd.DataFrame:
        data = []
        print(f"[LSTM] Processing {len(transactions)} transactions")

        for t in transactions:
            is_income = t.money > 0
            try:
                if hasattr(t.date_time, 'date'):
                    date_val = t.date_time.date()
                else:
                    date_val = t.date_time
                data.append({
                    'date': date_val,
                    'amount': abs(t.money),
                    'is_income': is_income
                })
            except Exception as e:
                print(f"[LSTM] Error processing transaction: {e}")
                continue

        df = pd.DataFrame(data)
        if df.empty:
            print("[LSTM] DataFrame is empty!")
            return pd.DataFrame(columns=['date', 'income', 'expense'])

        all_dates = df['date'].unique()
        print(f"[LSTM] Unique dates: {len(all_dates)} - {sorted(all_dates)[:5]}")

        daily_data = []
        for date in all_dates:
            day_df = df[df['date'] == date]
            income = day_df[day_df['is_income'] == True]['amount'].sum()
            expense = day_df[day_df['is_income'] == False]['amount'].sum()
            daily_data.append({
                'date': date,
                'income': income,
                'expense': expense
            })

        daily = pd.DataFrame(daily_data).sort_values('date').reset_index(drop=True)
        print(f"[LSTM] Daily data rows: {len(daily)}")

        if len(daily) > 1:
            date_range = pd.date_range(start=daily['date'].min(), end=daily['date'].max())
            daily = daily.set_index('date').reindex(date_range, fill_value=0).reset_index()
            daily.columns = ['date', 'income', 'expense']

        return daily

    def _create_sequences(self, data: np.ndarray, seq_length: int) -> Tuple[np.ndarray, np.ndarray]:
        X, y = [], []
        for i in range(len(data) - seq_length):
            X.append(data[i:(i + seq_length)])
            y.append(data[i + seq_length])
        return np.array(X), np.array(y)

    def _build_model(self, input_shape: Tuple[int, int]) -> Any:
        if not TF_AVAILABLE:
            return None

        model = Sequential([
            LSTM(50, return_sequences=True, input_shape=input_shape),
            Dropout(0.2),
            LSTM(50, return_sequences=False),
            Dropout(0.2),
            Dense(25),
            Dense(1)
        ])
        model.compile(optimizer='adam', loss='mse')
        return model

    def _train_and_predict(
        self,
        data: np.ndarray,
        scaler: MinMaxScaler,
        prediction_days: int
    ) -> Tuple[List[float], float]:
        if len(data) < self.sequence_length + 5:
            avg = np.mean(data[-7:]) if len(data) >= 7 else np.mean(data)
            std = np.std(data[-7:]) if len(data) >= 7 else np.std(data)
            std = max(std, avg * 0.1)
            predictions = []
            for i in range(prediction_days):
                variation = np.random.normal(0, std * 0.3)
                pred = max(0, avg + variation)
                predictions.append(float(pred))
            confidence = 0.3
            return predictions, confidence

        data_scaled = scaler.fit_transform(data.reshape(-1, 1))
        X, y = self._create_sequences(data_scaled, self.sequence_length)

        if len(X) < 5:
            avg = np.mean(data[-7:]) if len(data) >= 7 else np.mean(data)
            predictions = [float(avg)] * prediction_days
            return predictions, 0.3

        if TF_AVAILABLE:
            model = self._build_model((self.sequence_length, 1))
            X = X.reshape((X.shape[0], X.shape[1], 1))
            model.fit(X, y, epochs=50, batch_size=16, verbose=0, validation_split=0.1)

            last_sequence = data_scaled[-self.sequence_length:].reshape(1, self.sequence_length, 1)
            predictions = []

            for _ in range(prediction_days):
                pred = model.predict(last_sequence, verbose=0)[0, 0]
                predictions.append(pred)
                last_sequence = np.roll(last_sequence, -1, axis=1)
                last_sequence[0, -1, 0] = pred

            predictions = scaler.inverse_transform(np.array(predictions).reshape(-1, 1)).flatten()
            predictions = [max(0, float(p)) for p in predictions]
            confidence = min(0.9, 0.5 + len(data) / 200)
        else:
            alpha = 0.3
            predictions = []
            last_val = data[-1]
            for _ in range(prediction_days):
                pred = alpha * last_val + (1 - alpha) * np.mean(data[-7:])
                predictions.append(float(pred))
                last_val = pred
            confidence = 0.4

        return predictions, confidence

    def _simple_prediction(
        self,
        user_id: str,
        daily_df: pd.DataFrame,
        transactions: List[SpendingItem],
        prediction_days: int
    ) -> TrendPredictionResponse:
        total_income = daily_df['income'].sum()
        total_expense = daily_df['expense'].sum()
        num_days = max(1, len(daily_df))

        avg_daily_income = total_income / num_days
        avg_daily_expense = total_expense / num_days

        std_income = daily_df['income'].std() if len(daily_df) > 1 else avg_daily_income * 0.2
        std_expense = daily_df['expense'].std() if len(daily_df) > 1 else avg_daily_expense * 0.2
        std_income = max(std_income, avg_daily_income * 0.1) if avg_daily_income > 0 else 0
        std_expense = max(std_expense, avg_daily_expense * 0.1) if avg_daily_expense > 0 else 0

        last_date = daily_df['date'].iloc[-1]
        if hasattr(last_date, 'date'):
            last_date = last_date
        elif isinstance(last_date, str):
            last_date = datetime.strptime(last_date, '%Y-%m-%d').date()

        predictions = []
        for i in range(prediction_days):
            pred_date = last_date + timedelta(days=i + 1)
            pred_income = max(0, avg_daily_income + np.random.normal(0, std_income * 0.3))
            pred_expense = max(0, avg_daily_expense + np.random.normal(0, std_expense * 0.3))
            predictions.append(PredictedValue(
                date=pred_date.strftime('%Y-%m-%d'),
                predicted_income=round(pred_income, 0),
                predicted_expense=round(pred_expense, 0),
                confidence=0.3
            ))

        summary = {
            "predictionPeriod": f"{prediction_days} ngày",
            "totalPredictedIncome": round(avg_daily_income * prediction_days, 0),
            "totalPredictedExpense": round(avg_daily_expense * prediction_days, 0),
            "predictedBalance": round((avg_daily_income - avg_daily_expense) * prediction_days, 0),
            "averageDailyIncome": round(avg_daily_income, 0),
            "averageDailyExpense": round(avg_daily_expense, 0),
            "trend": {
                "incomeTrend": "chưa đủ dữ liệu",
                "expenseTrend": "chưa đủ dữ liệu",
                "recommendation": f"Cần thêm dữ liệu từ nhiều ngày khác nhau để dự báo chính xác hơn. Hiện có {num_days} ngày dữ liệu."
            },
            "dataPointsUsed": num_days,
            "modelConfidence": 0.3,
            "note": "Dự báo đơn giản dựa trên trung bình chi tiêu"
        }

        return TrendPredictionResponse(
            success=True,
            user_id=user_id,
            predictions=predictions,
            summary=summary,
            message="Dự báo đơn giản (cần thêm dữ liệu để dự báo LSTM)"
        )

    def predict_trend(
        self,
        user_id: str,
        transactions: List[SpendingItem],
        prediction_days: int = 7
    ) -> TrendPredictionResponse:
        daily_df = self._prepare_daily_data(transactions)

        print(f"[DEBUG] Transactions count: {len(transactions)}")
        print(f"[DEBUG] Daily data rows: {len(daily_df)}")

        if daily_df.empty:
            return TrendPredictionResponse(
                success=False,
                user_id=user_id,
                predictions=[],
                summary={
                    "message": "Không có dữ liệu giao dịch.",
                    "dataPoints": 0
                },
                message="No transaction data"
            )

        if len(daily_df) < 3:
            return self._simple_prediction(user_id, daily_df, transactions, prediction_days)

        income_data = daily_df['income'].values.astype(float)
        expense_data = daily_df['expense'].values.astype(float)

        income_predictions, income_confidence = self._train_and_predict(
            income_data, self.income_scaler, prediction_days
        )

        expense_predictions, expense_confidence = self._train_and_predict(
            expense_data, self.expense_scaler, prediction_days
        )

        last_date = daily_df['date'].iloc[-1]
        if isinstance(last_date, str):
            last_date = datetime.strptime(last_date, '%Y-%m-%d').date()

        predictions = []
        for i in range(prediction_days):
            pred_date = last_date + timedelta(days=i + 1)
            predictions.append(PredictedValue(
                date=pred_date.strftime('%Y-%m-%d'),
                predicted_income=round(income_predictions[i], 0),
                predicted_expense=round(expense_predictions[i], 0),
                confidence=round((income_confidence + expense_confidence) / 2, 2)
            ))

        total_predicted_income = sum(income_predictions)
        total_predicted_expense = sum(expense_predictions)
        avg_daily_income = np.mean(income_data[-30:]) if len(income_data) >= 30 else np.mean(income_data)
        avg_daily_expense = np.mean(expense_data[-30:]) if len(expense_data) >= 30 else np.mean(expense_data)

        summary = {
            "predictionPeriod": f"{prediction_days} ngày",
            "totalPredictedIncome": round(total_predicted_income, 0),
            "totalPredictedExpense": round(total_predicted_expense, 0),
            "predictedBalance": round(total_predicted_income - total_predicted_expense, 0),
            "averageDailyIncome": round(avg_daily_income, 0),
            "averageDailyExpense": round(avg_daily_expense, 0),
            "trend": self._analyze_trend(income_data, expense_data),
            "dataPointsUsed": len(daily_df),
            "modelConfidence": round((income_confidence + expense_confidence) / 2, 2)
        }

        return TrendPredictionResponse(
            success=True,
            user_id=user_id,
            predictions=predictions,
            summary=summary,
            message="Dự báo thành công"
        )

    def _analyze_trend(self, income: np.ndarray, expense: np.ndarray) -> Dict[str, Any]:
        recent_days = 7
        older_days = 14

        if len(income) >= older_days:
            recent_income = np.mean(income[-recent_days:])
            older_income = np.mean(income[-older_days:-recent_days])
            income_trend = "tăng" if recent_income > older_income * 1.1 else \
                          "giảm" if recent_income < older_income * 0.9 else "ổn định"
        else:
            income_trend = "chưa đủ dữ liệu"

        if len(expense) >= older_days:
            recent_expense = np.mean(expense[-recent_days:])
            older_expense = np.mean(expense[-older_days:-recent_days])
            expense_trend = "tăng" if recent_expense > older_expense * 1.1 else \
                           "giảm" if recent_expense < older_expense * 0.9 else "ổn định"
        else:
            expense_trend = "chưa đủ dữ liệu"

        return {
            "incomeTrend": income_trend,
            "expenseTrend": expense_trend,
            "recommendation": self._get_recommendation(income_trend, expense_trend)
        }

    def _get_recommendation(self, income_trend: str, expense_trend: str) -> str:
        if income_trend == "tăng" and expense_trend == "giảm":
            return "Xu hướng tài chính rất tốt! Tiếp tục duy trì."
        elif income_trend == "giảm" and expense_trend == "tăng":
            return "Cảnh báo: Thu nhập giảm trong khi chi tiêu tăng. Cần điều chỉnh ngân sách."
        elif income_trend == "giảm":
            return "Thu nhập có xu hướng giảm. Nên tìm cách tăng nguồn thu."
        elif expense_trend == "tăng":
            return "Chi tiêu có xu hướng tăng. Nên xem xét cắt giảm các khoản không cần thiết."
        else:
            return "Tài chính ổn định. Tiếp tục theo dõi và lập kế hoạch."


lstm_service = LSTMService()
