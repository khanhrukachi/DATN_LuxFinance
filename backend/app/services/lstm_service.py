import os
import calendar
import warnings
from datetime import datetime, timedelta
from typing import List, Dict, Any, Tuple, Optional

import numpy as np
import pandas as pd
from sklearn.preprocessing import RobustScaler
from sklearn.metrics import mean_absolute_error

try:
    from app.schemas.spending import SpendingItem
    from app.schemas.response import TrendPredictionResponse, PredictedValue
    from app.config import settings
    SEQ_LENGTH = int(getattr(settings, "LSTM_SEQUENCE_LENGTH", 28))
    MIN_LSTM_DAYS = int(getattr(settings, "LSTM_MIN_TRAIN_DAYS", 90))
    MAX_HISTORY_DAYS = int(getattr(settings, "LSTM_MAX_HISTORY_DAYS", 365))
except ImportError:
    class SpendingItem:
        def __init__(self, money, date_time, **kwargs):
            self.money = money
            self.date_time = date_time
            for k, v in kwargs.items():
                setattr(self, k, v)

    class PredictedValue:
        def __init__(self, **kwargs): self.__dict__.update(kwargs)

    class TrendPredictionResponse:
        def __init__(self, **kwargs): self.__dict__.update(kwargs)

    SEQ_LENGTH = 28
    MIN_LSTM_DAYS = 90
    MAX_HISTORY_DAYS = 365

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
try:
    import tensorflow as tf
    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import LSTM, Dense, Dropout, Input
    from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
    from tensorflow.keras.optimizers import Adam
    TF_AVAILABLE = True
except ImportError:
    TF_AVAILABLE = False

warnings.filterwarnings("ignore", category=FutureWarning)


class LSTMService:
    """
    Dự báo tài chính cá nhân theo tháng.

    Mục tiêu UX:
    - Người dùng chọn một tháng -> hệ thống dự báo PHẦN CÒN LẠI của tháng đó.
    - Nếu chọn tháng tương lai -> dự báo toàn tháng.
    - Không giả vờ LSTM tốt khi dữ liệu ít: tự fallback sang baseline theo ngày trong tuần.
    - Dùng lịch sử của chính người dùng; không trộn dữ liệu người khác.
    - Income và expense dự báo độc lập.
    - Confidence dựa trên backtest, không phải số cố định.
    """

    def __init__(self):
        self.sequence_length = max(14, SEQ_LENGTH)
        self.min_lstm_days = max(self.sequence_length * 2 + 14, MIN_LSTM_DAYS)
        self.max_history_days = max(self.min_lstm_days, MAX_HISTORY_DAYS)

    # ------------------------------------------------------------------
    # DATA
    # ------------------------------------------------------------------
    @staticmethod
    def _parse_datetime(value: Any) -> Optional[pd.Timestamp]:
        if value is None:
            return None
        try:
            ts = pd.to_datetime(value, errors="coerce")
            if pd.isna(ts):
                return None
            if getattr(ts, "tzinfo", None) is not None:
                ts = ts.tz_localize(None)
            return ts.normalize()
        except Exception:
            return None

    def _prepare_daily_data(self, transactions: List[Any]) -> pd.DataFrame:
        rows = []
        for t in transactions or []:
            try:
                money = float(getattr(t, "money", 0) or 0)
                if money == 0:
                    continue
                dt = self._parse_datetime(getattr(t, "date_time", None))
                if dt is None:
                    continue
                # Ưu tiên cờ nghiệp vụ của app. Chỉ fallback theo dấu money
                # khi transaction cũ không có isExpense/isIncome.
                is_expense = getattr(t, "is_expense", getattr(t, "isExpense", None))
                is_income = getattr(t, "is_income", getattr(t, "isIncome", None))

                if is_expense is True:
                    income_value, expense_value = 0.0, abs(money)
                elif is_income is True:
                    income_value, expense_value = abs(money), 0.0
                elif money < 0:
                    income_value, expense_value = 0.0, abs(money)
                else:
                    income_value, expense_value = abs(money), 0.0

                rows.append({
                    "date": dt,
                    "income": income_value,
                    "expense": expense_value,
                })
            except (TypeError, ValueError, OverflowError):
                continue

        if not rows:
            return pd.DataFrame(columns=["date", "income", "expense", "observed"])

        df = pd.DataFrame(rows)
        daily = df.groupby("date", as_index=False)[["income", "expense"]].sum()
        full_idx = pd.date_range(daily["date"].min(), daily["date"].max(), freq="D")
        daily = (
            daily.set_index("date")
            .reindex(full_idx, fill_value=0.0)
            .rename_axis("date")
            .reset_index()
        )
        # observed=True chỉ cho ngày thực sự có giao dịch.
        # Các ngày được reindex để tạo chuỗi thời gian có observed=False.
        observed_dates = set(df["date"].tolist())
        daily["observed"] = daily["date"].isin(observed_dates)
        return daily.sort_values("date").reset_index(drop=True)

    @staticmethod
    def _month_bounds(year: int, month: int) -> Tuple[pd.Timestamp, pd.Timestamp]:
        last_day = calendar.monthrange(year, month)[1]
        return pd.Timestamp(year, month, 1), pd.Timestamp(year, month, last_day)

    def _resolve_target_month(
        self, daily: pd.DataFrame, year: Optional[int], month: Optional[int]
    ) -> Tuple[int, int]:
        # Chỉ dùng tháng do client yêu cầu khi CẢ year và month đều được truyền.
        # Nếu thiếu một trong hai -> tuyệt đối không suy ra từ transaction.
        if year is not None or month is not None:
            if year is None or month is None:
                raise ValueError("Phải truyền đồng thời year và month, hoặc bỏ cả hai để dùng tháng hiện tại.")
            if not 1 <= int(month) <= 12:
                raise ValueError("month phải nằm trong khoảng 1..12")
            return int(year), int(month)

        # Mặc định luôn là tháng hiện tại của server.
        # Transaction cũ chỉ là HISTORY để học, không quyết định tháng đang phân tích.
        now = pd.Timestamp.now().normalize()
        return int(now.year), int(now.month)

    # ------------------------------------------------------------------
    # FORECAST ENGINE
    # ------------------------------------------------------------------
    @staticmethod
    def _weighted_mean(values: List[float]) -> float:
        """Trung bình có trọng số, ưu tiên tháng gần hiện tại."""
        if not values:
            return 0.0
        arr = np.asarray(values, dtype=float)
        weights = np.arange(1, len(arr) + 1, dtype=float)
        return float(np.average(arr, weights=weights))

    def _monthly_totals(self, history: pd.DataFrame, column: str) -> pd.DataFrame:
        if history.empty:
            return pd.DataFrame(columns=["period", "value", "days_observed"])
        h = history.copy()
        h["period"] = h["date"].dt.to_period("M")
        result = h.groupby("period").agg(
            value=(column, "sum"),
            days_observed=("observed", "sum") if "observed" in h.columns else ("date", "nunique")
        ).reset_index()
        return result

    def _monthly_level_forecast(
        self, history: pd.DataFrame, column: str, months: int = 6
    ) -> Tuple[float, Dict[str, Any]]:
        """
        Dự báo tổng theo tháng cho horizon dài.
        Chỉ dùng các tháng lịch sử đã hoàn tất để tránh coi tháng đang dở là tháng thấp.
        Robust: winsorize + weighted recent mean + trend bị giới hạn.
        """
        if history.empty:
            return 0.0, {"model": "monthly_no_data", "monthsUsed": 0}

        # history đã được cắt theo vùng dự báo ở predict_trend().
        # Không dùng "tháng hiện tại của hệ thống" để lọc ở đây vì sẽ sai khi
        # người dùng yêu cầu dự báo một tháng tương lai.
        monthly = self._monthly_totals(history, column)
        if monthly.empty:
            return 0.0, {"model": "monthly_no_complete_month", "monthsUsed": 0}

        # Tháng cuối của history có thể là tháng đang dở. Chỉ giữ tháng hoàn chỉnh:
        history_last_date = pd.Timestamp(history["date"].max()).normalize()
        last_period = history_last_date.to_period("M")
        last_period_end = last_period.end_time.normalize()
        if history_last_date < last_period_end:
            monthly = monthly[monthly["period"] < last_period]
        monthly = monthly.tail(months).copy()
        if monthly.empty:
            return 0.0, {"model": "monthly_no_complete_month", "monthsUsed": 0}

        vals = monthly["value"].astype(float).to_numpy()
        if len(vals) >= 4:
            lo, hi = np.quantile(vals, [0.10, 0.90])
            vals = np.clip(vals, lo, hi)

        level = self._weighted_mean(vals.tolist())

        # Trend nhẹ, không extrapolate mạnh.
        trend_pct = 0.0
        if len(vals) >= 3:
            x = np.arange(len(vals), dtype=float)
            slope = float(np.polyfit(x, vals, 1)[0])
            trend_pct = slope / max(level, 1.0)
            trend_pct = float(np.clip(trend_pct, -0.10, 0.10))

        forecast = max(0.0, level * (1.0 + trend_pct))

        # Đây là mức forecast cơ sở 1 bước. Khi predict_trend() dự báo tháng
        # tương lai xa hơn, hệ thống sẽ điều chỉnh theo monthsAhead có giới hạn,
        # tránh nhân recursive LSTM qua nhiều tháng.

        # Khoảng dự báo từ độ biến động cấp tháng.
        if len(vals) >= 2:
            mad = float(np.median(np.abs(vals - np.median(vals))))
            margin = max(mad * 1.4826, float(np.std(vals)) * 0.50)
        else:
            margin = forecast * 0.20

        return forecast, {
            "model": "robust_weighted_monthly",
            "monthsUsed": int(len(vals)),
            "monthlyValues": [round(float(v)) for v in vals],
            "weightedLevel": round(level),
            "trendPercent": round(trend_pct * 100, 1),
            "forecastLow": round(max(0.0, forecast - margin)),
            "forecastHigh": round(forecast + margin),
        }

    @staticmethod
    def _months_between(start: pd.Timestamp, end: pd.Timestamp) -> int:
        start = pd.Timestamp(start).to_period("M")
        end = pd.Timestamp(end).to_period("M")
        return max(0, (end.year - start.year) * 12 + (end.month - start.month))

    def _adjust_monthly_forecast_for_horizon(
        self,
        total: float,
        meta: Dict[str, Any],
        target_year: int,
        target_month: int,
        history: pd.DataFrame,
    ) -> Tuple[float, Dict[str, Any]]:
        """
        Điều chỉnh forecast cho tháng tương lai.
        Không recursive LSTM. Dùng trend tháng đã học nhưng giới hạn tác động:
        - trend mỗi tháng đã cap ±10%
        - tổng horizon adjustment cap ±35%
        - uncertainty tăng dần theo khoảng cách tương lai
        """
        if total <= 0 or history.empty:
            return total, meta

        last_date = pd.Timestamp(history["date"].max()).normalize()
        target_start = pd.Timestamp(target_year, target_month, 1)
        months_ahead = self._months_between(last_date, target_start)

        # _monthly_level_forecast đã áp dụng 1 bước trend.
        # Chỉ cộng thêm ảnh hưởng cho các bước xa hơn.
        trend_pct = float(meta.get("trendPercent", 0.0)) / 100.0
        extra_steps = max(months_ahead - 1, 0)
        horizon_effect = float(np.clip(trend_pct * extra_steps, -0.35, 0.35))
        adjusted = max(0.0, total * (1.0 + horizon_effect))

        base_low = float(meta.get("forecastLow", total))
        base_high = float(meta.get("forecastHigh", total))
        base_margin = max(total - base_low, base_high - total, total * 0.10)

        # Tương lai càng xa -> range rộng hơn, tối đa cộng thêm 60%.
        uncertainty_multiplier = 1.0 + min(months_ahead, 12) * 0.05
        margin = base_margin * uncertainty_multiplier

        meta = dict(meta)
        meta.update({
            "monthsAhead": months_ahead,
            "horizonTrendAdjustmentPercent": round(horizon_effect * 100.0, 1),
            "forecastLow": round(max(0.0, adjusted - margin)),
            "forecastHigh": round(adjusted + margin),
            "futureUncertaintyMultiplier": round(uncertainty_multiplier, 2),
        })
        return adjusted, meta

    def _income_monthly_forecast(
        self,
        history: pd.DataFrame,
        actual_income: float,
        target_year: int,
        target_month: int,
        target_dates: List[pd.Timestamp],
    ) -> Tuple[List[float], Dict[str, Any]]:
        """
        Thu nhập được dự báo THEO THÁNG, không theo weekday.
        Tổng thu nhập tháng = mức thu nhập tháng lịch sử gần đây.
        Phần còn lại = max(tổng tháng dự kiến - thu đã nhận, 0).
        Các prediction theo ngày chỉ là phân bổ trung bình để UI/API cũ vẫn dùng được.
        """
        monthly_total, meta = self._monthly_level_forecast(history, "income", months=6)
        monthly_total, meta = self._adjust_monthly_forecast_for_horizon(
            monthly_total, meta, target_year, target_month, history
        )
        days_in_month = calendar.monthrange(target_year, target_month)[1]

        # Nếu không có tháng hoàn chỉnh, dùng mức trung bình ngày lịch sử x số ngày tháng.
        if monthly_total <= 0 and not history.empty:
            observed_days = max(int(history["date"].nunique()), 1)
            daily_avg = float(history["income"].sum()) / observed_days
            monthly_total = max(0.0, daily_avg * days_in_month)
            meta.update({
                "model": "income_daily_average_fallback",
                "averagePerDay": round(daily_avg),
                "forecastLow": round(monthly_total * 0.75),
                "forecastHigh": round(monthly_total * 1.25),
            })

        remaining = max(0.0, monthly_total - actual_income)
        per_day = remaining / len(target_dates) if target_dates else 0.0
        preds = [per_day] * len(target_dates)

        low_total = float(meta.get("forecastLow", monthly_total))
        high_total = float(meta.get("forecastHigh", monthly_total))
        months_used = int(meta.get("monthsUsed", 0))
        meta.update({
            "confidence": round(min(0.80, 0.30 + months_used * 0.08), 2),
            "forecastType": "monthly_income",
            "expectedMonthlyIncome": round(max(actual_income, monthly_total)),
            "actualIncomeSoFar": round(actual_income),
            "remainingIncomeForecast": round(remaining),
            "averageRemainingPerDay": round(per_day),
            "forecastLow": round(max(actual_income, low_total)),
            "forecastHigh": round(max(actual_income, high_total)),
            "note": "Thu nhập được ước tính theo tổng tháng; giá trị theo ngày chỉ là mức trung bình phân bổ để tương thích giao diện.",
        })
        return preds, meta

    @staticmethod
    def _weekday_baseline(history: pd.DataFrame, target_dates: List[pd.Timestamp], column: str) -> List[float]:
        if history.empty:
            return [0.0] * len(target_dates)
        h = history.tail(84).copy()
        h["weekday"] = h["date"].dt.weekday
        positive = h[h[column] > 0][column].astype(float)
        cap = float(positive.quantile(0.90)) if len(positive) >= 5 else (
            float(positive.max()) if not positive.empty else 0.0
        )
        h["_value"] = np.minimum(h[column].astype(float), cap) if cap > 0 else h[column].astype(float)
        recent28 = h.tail(28)
        recent56 = h.tail(56)
        m28 = recent28.groupby("weekday")["_value"].mean().to_dict()
        m56 = recent56.groupby("weekday")["_value"].mean().to_dict()
        g28 = float(recent28["_value"].mean()) if not recent28.empty else 0.0
        g56 = float(recent56["_value"].mean()) if not recent56.empty else 0.0
        return [
            max(0.0, 0.70 * float(m28.get(d.weekday(), g28)) +
                       0.30 * float(m56.get(d.weekday(), g56)))
            for d in target_dates
        ]

    def _build_sequences(self, scaled: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        X, y = [], []
        for i in range(self.sequence_length, len(scaled)):
            X.append(scaled[i - self.sequence_length:i])
            y.append(scaled[i])
        return np.asarray(X), np.asarray(y)

    def _fit_lstm_and_forecast(
        self, values: np.ndarray, days: int
    ) -> Tuple[List[float], Dict[str, Any]]:
        if not TF_AVAILABLE or len(values) < self.min_lstm_days or days <= 0:
            return [], {"model": "unavailable", "mae": None, "confidence": 0.0}
        values = np.asarray(values, dtype=np.float32)
        scaler = RobustScaler(quantile_range=(10.0, 90.0))
        scaled = scaler.fit_transform(values.reshape(-1, 1)).astype(np.float32)
        X, y = self._build_sequences(scaled)
        if len(X) < 30:
            return [], {"model": "insufficient_sequences", "mae": None, "confidence": 0.0}

        val_size = max(7, int(len(X) * 0.2))
        if len(X) - val_size < 20:
            return [], {"model": "insufficient_train", "mae": None, "confidence": 0.0}
        X_train, X_val = X[:-val_size], X[-val_size:]
        y_train, y_val = y[:-val_size], y[-val_size:]

        tf.keras.backend.clear_session()
        tf.random.set_seed(42)
        np.random.seed(42)
        model = Sequential([
            Input(shape=(self.sequence_length, 1)),
            LSTM(48, return_sequences=True),
            Dropout(0.15),
            LSTM(24),
            Dense(16, activation="relu"),
            Dense(1),
        ])
        model.compile(optimizer=Adam(learning_rate=8e-4), loss=tf.keras.losses.Huber())
        model.fit(
            X_train, y_train,
            validation_data=(X_val, y_val),
            epochs=60,
            batch_size=min(32, max(8, len(X_train) // 4)),
            shuffle=False, verbose=0,
            callbacks=[
                EarlyStopping(monitor="val_loss", patience=7, restore_best_weights=True, min_delta=1e-4),
                ReduceLROnPlateau(monitor="val_loss", patience=3, factor=0.5, min_lr=1e-5),
            ],
        )

        vp = model.predict(X_val, verbose=0)
        val_pred = np.maximum(scaler.inverse_transform(vp).reshape(-1), 0.0)
        val_true = scaler.inverse_transform(y_val.reshape(-1, 1)).reshape(-1)
        mae = float(mean_absolute_error(val_true, val_pred))
        denom = max(float(np.mean(np.abs(val_true))), 1.0)
        confidence = float(np.clip(1.0 / (1.0 + mae / denom), 0.15, 0.85))

        # Chỉ forecast ngắn hạn bằng recursive LSTM. Không dùng cho cả tháng xa.
        seq = scaled[-self.sequence_length:].reshape(1, self.sequence_length, 1)
        out = []
        for _ in range(days):
            p = float(model.predict(seq, verbose=0)[0, 0])
            out.append(p)
            seq = np.concatenate(
                [seq[:, 1:, :], np.array([[[p]]], dtype=np.float32)], axis=1
            )
        preds = scaler.inverse_transform(np.asarray(out).reshape(-1, 1)).reshape(-1)
        return [max(0.0, float(x)) for x in preds], {
            "model": "lstm", "mae": round(mae, 2), "confidence": round(confidence, 3)
        }

    def _expense_backtest(self, hist: pd.DataFrame) -> Dict[str, Any]:
        if len(hist) < 35:
            return {"mae": None, "samples": 0, "errors": []}
        n = min(28, max(7, len(hist) // 5))
        errors = []
        for i in range(len(hist) - n, len(hist)):
            train = hist.iloc[:i]
            if len(train) < 21:
                continue
            pred = self._weekday_baseline(train, [hist.iloc[i]["date"]], "expense")[0]
            actual = float(hist.iloc[i]["expense"])
            errors.append(abs(actual - pred))
        return {
            "mae": round(float(np.mean(errors)), 2) if errors else None,
            "samples": len(errors),
            "errors": errors,
        }

    def _expense_occurrence_probability(
        self,
        history: pd.DataFrame,
        target_dates: List[pd.Timestamp],
    ) -> List[float]:
        """
        Xác suất phát sinh chi theo ngày.
        Tách riêng "có chi hay không" khỏi "nếu chi thì bao nhiêu".
        Ưu tiên 28 ngày gần nhất, bổ sung 56/84 ngày để tránh quá nhạy.
        """
        if history.empty:
            return [0.0] * len(target_dates)

        h = history.tail(84).copy()
        h["weekday"] = h["date"].dt.weekday
        h["spent"] = (h["expense"].astype(float) > 0).astype(float)

        r28 = h.tail(28)
        r56 = h.tail(56)

        global28 = float(r28["spent"].mean()) if not r28.empty else 0.0
        global56 = float(r56["spent"].mean()) if not r56.empty else global28

        p28 = r28.groupby("weekday")["spent"].mean().to_dict()
        p56 = r56.groupby("weekday")["spent"].mean().to_dict()

        result = []
        for d in target_dates:
            wd = int(d.weekday())
            a = float(p28.get(wd, global28))
            b = float(p56.get(wd, global56))
            p = 0.70 * a + 0.30 * b

            # Bayesian-style shrinkage nhẹ để weekday ít mẫu không thành 0/1 tuyệt đối.
            p = 0.85 * p + 0.15 * global56
            result.append(float(np.clip(p, 0.05, 0.95)))
        return result

    def _expense_amount_when_spending(
        self,
        history: pd.DataFrame,
        target_dates: List[pd.Timestamp],
    ) -> Tuple[List[float], Dict[str, Any]]:
        """
        Ước lượng số tiền KHI CÓ CHI.
        Dùng median/trimmed recent behavior thay vì mean thuần để khoản chi lớn
        bất thường không kéo toàn bộ 7 ngày lên.
        """
        if history.empty:
            return [0.0] * len(target_dates), {"cap": 0.0, "median": 0.0}

        h = history.tail(84).copy()
        h["weekday"] = h["date"].dt.weekday
        positive = h[h["expense"] > 0].copy()

        if positive.empty:
            return [0.0] * len(target_dates), {"cap": 0.0, "median": 0.0}

        vals = positive["expense"].astype(float)
        median = float(vals.median())

        if len(vals) >= 8:
            q10, q85 = vals.quantile([0.10, 0.85])
            cap = float(max(q85, median))
            floor = float(max(0.0, q10))
        else:
            cap = float(max(vals.max(), median))
            floor = 0.0

        positive["_robust"] = positive["expense"].astype(float).clip(
            lower=floor, upper=cap
        )

        recent28 = positive[positive["date"] >= h["date"].max() - timedelta(days=27)]
        recent56 = positive[positive["date"] >= h["date"].max() - timedelta(days=55)]

        global28 = float(recent28["_robust"].median()) if not recent28.empty else median
        global56 = float(recent56["_robust"].median()) if not recent56.empty else median

        wd28 = recent28.groupby("weekday")["_robust"].median().to_dict()
        wd56 = recent56.groupby("weekday")["_robust"].median().to_dict()

        amounts = []
        for d in target_dates:
            wd = int(d.weekday())
            a = float(wd28.get(wd, global28))
            b = float(wd56.get(wd, global56))
            amount = 0.70 * a + 0.30 * b
            amounts.append(max(0.0, min(amount, cap * 1.15 if cap > 0 else amount)))

        return amounts, {
            "median": round(median),
            "cap": round(cap),
            "positiveSamples": int(len(positive)),
            "method": "weekday_conditional_robust_median",
        }

    def _expense_short_backtest(self, hist: pd.DataFrame) -> Dict[str, Any]:
        """
        Walk-forward backtest cho chính logic 2 tầng:
        P(có chi) * amount-if-spending.
        """
        if len(hist) < 42:
            return {"mae": None, "samples": 0, "errors": [], "wmape": None}

        n = min(28, max(7, len(hist) // 5))
        errors = []
        actual_sum = 0.0

        for i in range(len(hist) - n, len(hist)):
            train = hist.iloc[:i].copy()
            if len(train) < 28:
                continue

            d = pd.Timestamp(hist.iloc[i]["date"])
            p = self._expense_occurrence_probability(train, [d])[0]
            amount = self._expense_amount_when_spending(train, [d])[0][0]
            pred = p * amount
            actual = float(hist.iloc[i]["expense"])

            errors.append(abs(actual - pred))
            actual_sum += abs(actual)

        mae = float(np.mean(errors)) if errors else None
        wmape = (
            float(sum(errors) / actual_sum)
            if errors and actual_sum > 0 else None
        )

        return {
            "mae": round(mae, 2) if mae is not None else None,
            "samples": len(errors),
            "errors": errors,
            "wmape": round(wmape, 3) if wmape is not None else None,
        }

    def _expense_short_forecast(
        self, history: pd.DataFrame, target_dates: List[pd.Timestamp]
    ) -> Tuple[List[float], Dict[str, Any]]:
        """
        Forecast 1-7 ngày thực tế hơn:

        Expected expense =
            P(có chi trong ngày) * số tiền ước lượng khi có chi

        Sau đó LSTM chỉ được dùng như correction nhỏ nếu validation thực sự tốt.
        Không để một khoản chi lớn bất thường làm 7 ngày sau đều cao.
        """
        if not target_dates:
            return [], {
                "model": "none",
                "forecastType": "short_daily_expense",
                "mae": None,
                "confidence": 1.0,
            }

        hist = history.tail(self.max_history_days).copy()
        if hist.empty:
            return [0.0] * len(target_dates), {
                "model": "short_no_data",
                "forecastType": "short_daily_expense",
                "mae": None,
                "confidence": 0.0,
            }

        # 1) Probability of spending.
        probs = self._expense_occurrence_probability(hist, target_dates)

        # 2) Amount conditional on spending.
        amounts, amount_meta = self._expense_amount_when_spending(
            hist, target_dates
        )

        # Expected-value baseline. Ngày ít khả năng chi sẽ tự nhiên gần 0.
        baseline = [
            max(0.0, float(p) * float(a))
            for p, a in zip(probs, amounts)
        ]

        # 3) Backtest đúng baseline mới.
        bt = self._expense_short_backtest(hist)

        # 4) LSTM chỉ correction, không làm model chính.
        lstm_preds, lm = self._fit_lstm_and_forecast(
            hist["expense"].to_numpy(dtype=float),
            len(target_dates),
        )

        lstm_weight = 0.0
        if lstm_preds and lm.get("mae") is not None and bt.get("mae") is not None:
            lmae = float(lm["mae"])
            bmae = float(bt["mae"])

            # Chỉ cho LSTM trọng số đáng kể khi thắng baseline rõ ràng.
            if lmae <= bmae * 0.80:
                lstm_weight = 0.25
            elif lmae < bmae:
                lstm_weight = 0.12

        preds = []
        for i, base in enumerate(baseline):
            value = base
            if lstm_preds and i < len(lstm_preds) and lstm_weight > 0:
                value = (
                    (1.0 - lstm_weight) * base
                    + lstm_weight * float(lstm_preds[i])
                )

            # Guardrail chống spike: expected daily expense không vượt quá
            # conditional amount quá nhiều.
            day_cap = amounts[i] * 1.15 if i < len(amounts) else value
            if day_cap > 0:
                value = min(value, day_cap)

            # Nếu probability rất thấp, cho phép prediction = 0 để UX thực tế hơn.
            if probs[i] < 0.18:
                value = 0.0

            preds.append(max(0.0, float(value)))

        errors = bt.get("errors") or []
        if errors:
            daily_margin = float(np.quantile(errors, 0.80))
        else:
            positive_pred = [x for x in preds if x > 0]
            daily_margin = (
                float(np.median(positive_pred)) * 0.60
                if positive_pred else 0.0
            )

        total = float(sum(preds))
        total_margin = daily_margin * np.sqrt(max(len(preds), 1))

        recent28 = hist.tail(28)
        recent_mean = float(recent28["expense"].mean()) if not recent28.empty else 0.0
        mae = bt.get("mae")

        if mae is None:
            confidence = 0.30
        else:
            confidence = float(np.clip(
                1.0 / (1.0 + float(mae) / max(recent_mean, 1.0)),
                0.15,
                0.82,
            ))

        daily_detail = []
        for d, p, amount, pred in zip(target_dates, probs, amounts, preds):
            daily_detail.append({
                "date": d.strftime("%Y-%m-%d"),
                "spendingProbability": round(float(p), 3),
                "spendingProbabilityPercent": round(float(p) * 100.0, 1),
                "estimatedAmountIfSpending": round(float(amount)),
                "expectedExpense": round(float(pred)),
            })

        return preds, {
            "model": "two_stage_spending_probability_amount_ensemble",
            "forecastType": "short_daily_expense",
            "mae": mae,
            "wmape": bt.get("wmape"),
            "confidence": round(confidence, 3),
            "lstmWeight": round(lstm_weight, 2),
            "baselineWeight": round(1.0 - lstm_weight, 2),
            "forecastLow": round(max(0.0, total - total_margin)),
            "forecastHigh": round(total + total_margin),
            "backtestSamples": bt.get("samples", 0),
            "amountModel": amount_meta,
            "dailyBehavior": daily_detail,
            "note": (
                "Dự báo 7 ngày tách xác suất có chi và số tiền khi có chi. "
                "LSTM chỉ hiệu chỉnh khi backtest tốt hơn baseline; outlier được giới hạn."
            ),
        }

    def _expense_monthly_forecast(
        self,
        history: pd.DataFrame,
        actual_expense: float,
        target_year: int,
        target_month: int,
        target_dates: List[pd.Timestamp],
    ) -> Tuple[List[float], Dict[str, Any]]:
        """
        Horizon > 7 ngày / tháng tương lai:
        dự báo tổng CHI THEO THÁNG, không recursive LSTM tới 30/60/90 ngày.
        """
        monthly_total, meta = self._monthly_level_forecast(history, "expense", months=6)
        monthly_total, meta = self._adjust_monthly_forecast_for_horizon(
            monthly_total, meta, target_year, target_month, history
        )
        days_in_month = calendar.monthrange(target_year, target_month)[1]

        if monthly_total <= 0 and not history.empty:
            recent = history.tail(56)
            daily_avg = float(recent["expense"].mean()) if not recent.empty else 0.0
            monthly_total = daily_avg * days_in_month
            meta.update({
                "model": "expense_recent_daily_average_fallback",
                "forecastLow": round(monthly_total * 0.70),
                "forecastHigh": round(monthly_total * 1.30),
            })

        remaining = max(0.0, monthly_total - actual_expense)
        if not target_dates:
            preds = []
        else:
            # Phân bổ tổng phần còn lại theo weekday weights để UI có daily points,
            # nhưng tổng tháng vẫn do monthly model quyết định.
            raw = self._weekday_baseline(history, target_dates, "expense")
            s = float(sum(raw))
            if s <= 0:
                preds = [remaining / len(target_dates)] * len(target_dates)
            else:
                preds = [remaining * x / s for x in raw]

        low_total = max(actual_expense, float(meta.get("forecastLow", monthly_total)))
        high_total = max(actual_expense, float(meta.get("forecastHigh", monthly_total)))
        meta.update({
            "forecastType": "monthly_expense",
            "expectedMonthlyExpense": round(max(actual_expense, monthly_total)),
            "actualExpenseSoFar": round(actual_expense),
            "remainingExpenseForecast": round(remaining),
            "forecastLow": round(low_total),
            "forecastHigh": round(high_total),
            "confidence": round(0.35 + min(meta.get("monthsUsed", 0), 6) * 0.07, 2),
            "note": "Dự báo dài hạn theo tổng tháng; daily points chỉ là phân bổ của tổng tháng, không phải recursive LSTM.",
        })
        return preds, meta

    # ------------------------------------------------------------------
    # INSIGHT
    # ------------------------------------------------------------------
    @staticmethod
    def _week_bounds(reference_date: pd.Timestamp) -> Tuple[pd.Timestamp, pd.Timestamp]:
        """Tuần chuẩn: Thứ 2 -> Chủ nhật."""
        ref = pd.Timestamp(reference_date).normalize()
        monday = ref - timedelta(days=int(ref.weekday()))
        sunday = monday + timedelta(days=6)
        return monday, sunday

    def _weekly_comparison(
        self,
        history: pd.DataFrame,
        column: str,
        label: str,
        reference_date: pd.Timestamp,
    ) -> Dict[str, Any]:
        """
        Tuần này = Thứ 2 -> ngày hiện tại.
        Tuần trước = toàn bộ Thứ 2 -> Chủ nhật.

        Nếu tuần này chưa kết thúc, phần trăm chỉ mô tả tiến độ hiện tại
        so với TỔNG tuần trước, không kết luận "tăng/giảm cả tuần".
        """
        if history.empty:
            return {
                "direction": "insufficient_data",
                "changePercent": None,
                "text": f"Chưa đủ dữ liệu để phân tích {label.lower()} theo tuần.",
            }

        ref = pd.Timestamp(reference_date).normalize()
        this_start, this_sunday = self._week_bounds(ref)
        this_end = min(ref, this_sunday)
        prev_start = this_start - timedelta(days=7)
        prev_end = this_start - timedelta(days=1)

        h = history.copy()
        h["date"] = pd.to_datetime(h["date"]).dt.normalize()

        this_rows = h[(h["date"] >= this_start) & (h["date"] <= this_end)]
        prev_rows = h[(h["date"] >= prev_start) & (h["date"] <= prev_end)]

        this_total = float(this_rows[column].sum()) if not this_rows.empty else 0.0
        prev_total = float(prev_rows[column].sum()) if not prev_rows.empty else 0.0

        elapsed_days = max((this_end - this_start).days + 1, 1)
        this_avg = this_total / elapsed_days
        prev_avg = prev_total / 7.0

        this_tx_days = int(this_rows["observed"].sum()) if (
            not this_rows.empty and "observed" in this_rows.columns
        ) else int((this_rows[column] > 0).sum()) if not this_rows.empty else 0

        prev_tx_days = int(prev_rows["observed"].sum()) if (
            not prev_rows.empty and "observed" in prev_rows.columns
        ) else int((prev_rows[column] > 0).sum()) if not prev_rows.empty else 0

        week_complete = this_end >= this_sunday

        if prev_total <= 0:
            change = None
            direction = "up" if this_total > 0 else "stable"
            text = (
                f"{label} tuần này hiện là {this_total:,.0f}đ; "
                "tuần trước chưa ghi nhận giá trị để tính tỷ lệ so sánh."
            )
        else:
            change = (this_total - prev_total) / prev_total * 100.0
            if week_complete:
                if abs(change) < 5:
                    direction = "stable"
                    text = (
                        f"{label} tuần này gần tương đương tuần trước "
                        f"({this_total:,.0f}đ so với {prev_total:,.0f}đ)."
                    )
                elif change > 0:
                    direction = "up"
                    text = (
                        f"{label} tuần này tăng {abs(change):.1f}% so với tuần trước "
                        f"({this_total:,.0f}đ so với {prev_total:,.0f}đ)."
                    )
                else:
                    direction = "down"
                    text = (
                        f"{label} tuần này giảm {abs(change):.1f}% so với tuần trước "
                        f"({this_total:,.0f}đ so với {prev_total:,.0f}đ)."
                    )
            else:
                direction = "above_previous_total" if this_total > prev_total else "below_previous_total"
                relation = "cao hơn" if this_total > prev_total else "thấp hơn"
                text = (
                    f"Tính đến {this_end.strftime('%d/%m')}, {label.lower()} tuần này "
                    f"{relation} {abs(change):.1f}% so với TỔNG tuần trước "
                    f"({this_total:,.0f}đ so với {prev_total:,.0f}đ). "
                    f"Tuần này mới đi qua {elapsed_days}/7 ngày nên đây chưa phải kết luận cuối tuần."
                )

        pace_ratio = (this_avg / prev_avg) if prev_avg > 0 else None
        projected_by_pace = this_avg * 7.0

        return {
            "direction": direction,
            "changePercent": round(change, 1) if change is not None else None,
            "text": text,
            "comparisonType": "current_week_to_date_vs_full_previous_week",
            "weekComplete": week_complete,
            "elapsedDays": elapsed_days,
            "thisWeek": {
                "start": this_start.strftime("%Y-%m-%d"),
                "end": this_end.strftime("%Y-%m-%d"),
                "total": round(this_total),
                "averagePerDay": round(this_avg),
                "transactionDays": this_tx_days,
                "projectedAtCurrentPace": round(projected_by_pace),
            },
            "lastWeek": {
                "start": prev_start.strftime("%Y-%m-%d"),
                "end": prev_end.strftime("%Y-%m-%d"),
                "total": round(prev_total),
                "averagePerDay": round(prev_avg),
                "transactionDays": prev_tx_days,
            },
            "paceRatio": round(pace_ratio, 3) if pace_ratio is not None else None,
        }

    @staticmethod
    def _safe_pct(numerator: float, denominator: float) -> Optional[float]:
        if denominator <= 0:
            return None
        return float(numerator / denominator * 100.0)

    def _build_financial_analysis(
        self,
        actual_income: float,
        actual_expense: float,
        expected_income: float,
        expected_expense: float,
        income_meta: Dict[str, Any],
        expense_meta: Dict[str, Any],
        income_week: Dict[str, Any],
        expense_week: Dict[str, Any],
        target_dates: List[pd.Timestamp],
        month_start: pd.Timestamp,
        month_end: pd.Timestamp,
        reference_date: pd.Timestamp,
        observed_transaction_days: int,
        history: pd.DataFrame,
    ) -> Dict[str, Any]:
        """
        Phân tích có logic nghiệp vụ:
        1) trạng thái hiện tại,
        2) nhịp chi,
        3) dự báo cuối tháng,
        4) rủi ro,
        5) chất lượng dữ liệu,
        6) hành động đề xuất.
        """
        expected_balance = expected_income - expected_expense
        actual_balance = actual_income - actual_expense
        expected_expense_ratio = self._safe_pct(expected_expense, expected_income)
        savings_rate = self._safe_pct(expected_balance, expected_income)

        ref = pd.Timestamp(reference_date).normalize()
        total_days = int((month_end - month_start).days + 1)
        elapsed_days = int(np.clip((ref - month_start).days + 1, 0, total_days))
        remaining_days = max(total_days - elapsed_days, 0)

        actual_daily_expense = actual_expense / max(elapsed_days, 1)
        remaining_expense = max(expected_expense - actual_expense, 0.0)
        allowed_daily_expense = remaining_expense / max(remaining_days, 1) if remaining_days > 0 else 0.0

        # So sánh pace tuần này với tuần trước.
        weekly_pace = expense_week.get("paceRatio")
        if weekly_pace is None:
            pace_status = "unknown"
            pace_text = "Chưa đủ dữ liệu tuần trước để đánh giá nhịp chi tuần này."
        elif weekly_pace >= 1.20:
            pace_status = "high"
            pace_text = f"Nhịp chi trung bình/ngày tuần này cao hơn khoảng {(weekly_pace - 1) * 100:.1f}% so với tuần trước."
        elif weekly_pace <= 0.80:
            pace_status = "low"
            pace_text = f"Nhịp chi trung bình/ngày tuần này thấp hơn khoảng {(1 - weekly_pace) * 100:.1f}% so với tuần trước."
        else:
            pace_status = "normal"
            pace_text = "Nhịp chi trung bình/ngày tuần này khá gần tuần trước."

        # Risk dựa trên dòng tiền dự kiến, không dựa trên một threshold đơn lẻ.
        if expected_income <= 0 and expected_expense > 0:
            risk_level = "high"
            risk_reason = "Chưa có mức thu nhập dự kiến đáng tin cậy trong khi vẫn có chi tiêu."
        elif expected_balance < 0:
            risk_level = "high"
            risk_reason = f"Dự kiến cuối tháng âm khoảng {abs(expected_balance):,.0f}đ."
        elif expected_expense_ratio is not None and expected_expense_ratio >= 90:
            risk_level = "high"
            risk_reason = f"Chi tiêu dự kiến chiếm khoảng {expected_expense_ratio:.1f}% thu nhập."
        elif expected_expense_ratio is not None and expected_expense_ratio >= 75:
            risk_level = "medium"
            risk_reason = f"Chi tiêu dự kiến chiếm khoảng {expected_expense_ratio:.1f}% thu nhập; biên an toàn không lớn."
        else:
            risk_level = "low"
            risk_reason = "Dòng tiền dự kiến vẫn còn biên an toàn theo dữ liệu hiện có."

        # Chất lượng dữ liệu: số tháng + ngày giao dịch + confidence model.
        income_months = int(income_meta.get("monthsUsed", 0))
        expense_months = int(expense_meta.get("monthsUsed", 0))
        model_conf = float(
            (float(income_meta.get("confidence", 0.0)) +
             float(expense_meta.get("confidence", 0.0))) / 2.0
        )
        history_span = int(history["date"].nunique()) if not history.empty else 0

        quality_score = 0
        quality_score += min(max(income_months, expense_months), 6) * 7
        quality_score += min(observed_transaction_days, 15) * 2
        quality_score += int(model_conf * 25)
        quality_score = int(np.clip(quality_score, 0, 100))

        if quality_score >= 70:
            quality_level = "good"
        elif quality_score >= 45:
            quality_level = "medium"
        else:
            quality_level = "limited"

        # Action ưu tiên, tránh câu khuyên chung chung.
        actions = []
        if expected_balance < 0:
            actions.append({
                "priority": 1,
                "type": "reduce_expense",
                "text": f"Cần giảm tối thiểu khoảng {abs(expected_balance):,.0f}đ chi tiêu dự kiến để tránh âm cuối tháng."
            })
        elif remaining_days > 0 and allowed_daily_expense > 0 and actual_daily_expense > allowed_daily_expense * 1.15:
            actions.append({
                "priority": 1,
                "type": "slow_spending",
                "text": (
                    f"Nhịp chi hiện tại khoảng {actual_daily_expense:,.0f}đ/ngày, "
                    f"cao hơn mức còn lại khoảng {allowed_daily_expense:,.0f}đ/ngày. "
                    "Nên giảm nhịp chi trong các ngày còn lại."
                )
            })

        if weekly_pace is not None and weekly_pace >= 1.20:
            actions.append({
                "priority": 2,
                "type": "weekly_pace",
                "text": "Tuần này đang chi nhanh hơn tuần trước; nên kiểm tra các khoản lớn hoặc không thường xuyên trước khi tiếp tục chi."
            })

        if expected_balance > 0 and savings_rate is not None and savings_rate >= 10:
            actions.append({
                "priority": 3,
                "type": "saving",
                "text": f"Nếu dự báo giữ nguyên, có thể còn khoảng {expected_balance:,.0f}đ cuối tháng; cân nhắc dành một phần cho tiết kiệm/mục tiêu tài chính."
            })

        if not actions:
            actions.append({
                "priority": 3,
                "type": "monitor",
                "text": "Dòng tiền hiện chưa có dấu hiệu bất thường rõ rệt; tiếp tục theo dõi nhịp chi và cập nhật giao dịch đầy đủ."
            })

        return {
            "cashFlow": {
                "actualIncome": round(actual_income),
                "actualExpense": round(actual_expense),
                "actualBalance": round(actual_balance),
                "expectedIncome": round(expected_income),
                "expectedExpense": round(expected_expense),
                "expectedBalance": round(expected_balance),
                "expectedExpenseToIncomePercent": round(expected_expense_ratio, 1) if expected_expense_ratio is not None else None,
                "expectedSavingsRatePercent": round(savings_rate, 1) if savings_rate is not None else None,
            },
            "spendingPace": {
                "status": pace_status,
                "text": pace_text,
                "actualAveragePerElapsedDay": round(actual_daily_expense),
                "suggestedAverageForRemainingDays": round(allowed_daily_expense),
                "elapsedDaysInMonth": elapsed_days,
                "remainingDaysInMonth": remaining_days,
            },
            "risk": {
                "level": risk_level,
                "reason": risk_reason,
            },
            "dataQuality": {
                "level": quality_level,
                "score": quality_score,
                "historyCalendarDays": history_span,
                "observedTransactionDaysInTargetMonth": observed_transaction_days,
                "incomeHistoryMonths": income_months,
                "expenseHistoryMonths": expense_months,
                "modelConfidence": round(model_conf, 2),
                "warning": (
                    None if quality_level == "good"
                    else "Dữ liệu còn hạn chế; nên xem dự báo như một khoảng ước tính thay vì số tiền chắc chắn."
                ),
            },
            "actions": sorted(actions, key=lambda x: x["priority"]),
        }

    def _build_daily_forecast_detail(
        self,
        target_dates: List[pd.Timestamp],
        inc_preds: List[float],
        exp_preds: List[float],
        inc_meta: Dict[str, Any],
        exp_meta: Dict[str, Any],
    ) -> List[Dict[str, Any]]:
        """
        Trả chi tiết CHO TỪNG NGÀY dự báo, không chỉ ngày đầu/ngày cuối.
        Có running total để Flutter hiển thị danh sách/biểu đồ rõ ràng.
        """
        details: List[Dict[str, Any]] = []
        cumulative_income = 0.0
        cumulative_expense = 0.0

        inc_conf = float(inc_meta.get("confidence", 0.0))
        exp_conf = float(exp_meta.get("confidence", 0.0))
        confidence = round((inc_conf + exp_conf) / 2.0, 2)

        weekday_vi = [
            "Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5",
            "Thứ 6", "Thứ 7", "Chủ nhật"
        ]

        short_behavior = exp_meta.get("dailyBehavior") or []
        behavior_by_date = {
            str(x.get("date")): x for x in short_behavior if x.get("date")
        }

        for i, d in enumerate(target_dates):
            inc = float(inc_preds[i]) if i < len(inc_preds) else 0.0
            exp = float(exp_preds[i]) if i < len(exp_preds) else 0.0
            behavior = behavior_by_date.get(d.strftime("%Y-%m-%d"), {})

            cumulative_income += inc
            cumulative_expense += exp
            balance = inc - exp

            if inc >= 1000 and exp >= 1000:
                description = (
                    f"Dự kiến thu {inc:,.0f}đ và chi {exp:,.0f}đ; "
                    f"dòng tiền ngày {'dương' if balance >= 0 else 'âm'} "
                    f"{abs(balance):,.0f}đ."
                )
            elif exp >= 1000:
                description = f"Dự kiến chi khoảng {exp:,.0f}đ."
            elif inc >= 1000:
                description = f"Dự kiến thu khoảng {inc:,.0f}đ."
            else:
                description = "Dự kiến ít phát sinh."

            details.append({
                "index": i + 1,
                "date": d.strftime("%Y-%m-%d"),
                "displayDate": d.strftime("%d/%m/%Y"),
                "weekday": weekday_vi[int(d.weekday())],
                "predictedIncome": round(inc),
                "predictedExpense": round(exp),
                "predictedBalance": round(balance),
                "cumulativeIncome": round(cumulative_income),
                "cumulativeExpense": round(cumulative_expense),
                "cumulativeBalance": round(cumulative_income - cumulative_expense),
                "confidence": confidence,
                "description": description,
                "spendingProbability": behavior.get("spendingProbability"),
                "spendingProbabilityPercent": behavior.get("spendingProbabilityPercent"),
                "estimatedAmountIfSpending": behavior.get("estimatedAmountIfSpending"),
                "incomeIsAllocation": inc_meta.get("forecastType") == "monthly_income",
                "expenseIsAllocation": exp_meta.get("forecastType") == "monthly_expense",
            })

        return details

    def _build_forecast_explanation(
        self,
        actual_income: float,
        actual_expense: float,
        forecast_income: float,
        forecast_expense: float,
        expected_income: float,
        expected_expense: float,
        inc_meta: Dict[str, Any],
        exp_meta: Dict[str, Any],
        target_dates: List[pd.Timestamp],
    ) -> Dict[str, Any]:
        """Giải thích forecast theo ngôn ngữ có thể đưa thẳng lên Flutter."""
        expected_balance = expected_income - expected_expense
        income_remaining = max(expected_income - actual_income, 0.0)
        expense_remaining = max(expected_expense - actual_expense, 0.0)

        income_text = (
            f"Đã ghi nhận {actual_income:,.0f}đ thu nhập. "
            f"Hệ thống ước tính tổng thu tháng khoảng {expected_income:,.0f}đ "
            f"dựa trên {int(inc_meta.get('monthsUsed', 0))} tháng lịch sử gần nhất"
        )
        if income_remaining > 0:
            income_text += f", tức còn khoảng {income_remaining:,.0f}đ có thể phát sinh."
        else:
            income_text += "; mức thu hiện tại đã đạt hoặc vượt mức tháng ước tính."

        expense_text = (
            f"Đã chi {actual_expense:,.0f}đ. "
            f"Chi cuối tháng ước tính khoảng {expected_expense:,.0f}đ"
        )
        if expense_remaining > 0:
            expense_text += f", tức còn khoảng {expense_remaining:,.0f}đ có thể phát sinh."
        else:
            expense_text += " và hiện không cộng thêm phần chi đáng kể ngoài dữ liệu đã ghi nhận."

        return {
            "income": income_text,
            "expense": expense_text,
            "balance": (
                f"Số dư dòng tiền cuối tháng dự kiến "
                f"{'dương' if expected_balance >= 0 else 'âm'} khoảng {abs(expected_balance):,.0f}đ."
            ),
            "method": {
                "income": "Thu nhập dự báo theo tổng tháng từ lịch sử gần đây; daily income chỉ là phân bổ hiển thị.",
                "expense": (
                    "Chi tiêu 1-7 ngày dùng mô hình 2 tầng: xác suất phát sinh chi × số tiền khi có chi; LSTM chỉ hiệu chỉnh khi backtest tốt hơn baseline."
                    if exp_meta.get("forecastType") == "short_daily_expense"
                    else "Chi tiêu dài hạn dự báo theo tổng tháng để tránh sai số recursive LSTM."
                ),
            },
            "forecastDays": len(target_dates),
            "dailyDetailAvailable": True,
            "dailyDetailKey": "summary.dailyForecastDetail",
            "uncertainty": "Ưu tiên sử dụng forecast range và dataQuality thay vì coi một giá trị dự báo là tuyệt đối.",
        }

    @staticmethod
    def _recommendation(
        actual_income: float,
        actual_expense: float,
        expected_income: float,
        expected_expense: float,
        remaining_days: int,
    ) -> str:
        balance = expected_income - expected_expense
        if expected_income <= 0:
            if expected_expense > 0:
                return "Chưa có cơ sở đủ tốt để ước tính thu nhập; ưu tiên kiểm soát các khoản chi đã và sắp phát sinh."
            return "Chưa đủ dữ liệu dòng tiền để tạo khuyến nghị đáng tin cậy."

        ratio = expected_expense / expected_income
        if balance < 0:
            return (
                f"Nếu dự báo giữ nguyên, cuối tháng có thể thiếu khoảng {abs(balance):,.0f}đ. "
                "Ưu tiên giảm các khoản chi linh hoạt trước."
            )
        if ratio >= 0.90:
            return (
                f"Khoảng {ratio * 100:.1f}% thu nhập dự kiến có thể được dùng cho chi tiêu. "
                f"Biên còn lại khoảng {balance:,.0f}đ là khá thấp."
            )
        if remaining_days > 0:
            return (
                f"Dòng tiền dự kiến cuối tháng còn khoảng {balance:,.0f}đ sau chi tiêu. "
                f"Còn {remaining_days} ngày, nên theo dõi nhịp chi thực tế so với mức dự báo thay vì chỉ nhìn tổng tháng."
            )
        return f"Tháng đã kết thúc với chênh lệch thu - chi khoảng {balance:,.0f}đ."

    # ------------------------------------------------------------------
    # MAIN - API cũ vẫn dùng được, thêm year/month để phân tích đúng tháng
    # ------------------------------------------------------------------
    def predict_trend(
        self,
        user_id: str,
        transactions: List[Any],
        prediction_days: Optional[int] = None,
        year: Optional[int] = None,
        month: Optional[int] = None,
    ) -> TrendPredictionResponse:
        daily = self._prepare_daily_data(transactions)
        if daily.empty:
            return TrendPredictionResponse(
                success=False, user_id=user_id, predictions=[], summary={},
                message="Chưa có dữ liệu giao dịch để dự báo."
            )

        try:
            target_year, target_month = self._resolve_target_month(daily, year, month)
        except ValueError as exc:
            return TrendPredictionResponse(
                success=False, user_id=user_id, predictions=[], summary={}, message=str(exc)
            )

        month_start, month_end = self._month_bounds(target_year, target_month)
        today = pd.Timestamp.now().normalize()

        # Diagnostic rõ ràng: transaction cũ là HISTORY, không phải TARGET MONTH.
        observed = daily[daily.get("observed", True) == True] if "observed" in daily.columns else daily
        first_tx = observed["date"].min() if not observed.empty else None
        last_tx = observed["date"].max() if not observed.empty else None
        print("\n" + "=" * 58)
        print(f"[FORECAST] User: {user_id}")
        print(f"[FORECAST] TODAY       : {today.strftime('%Y-%m-%d')}")
        print(f"[FORECAST] TARGET MONTH: {target_month:02d}/{target_year}")
        print(f"[FORECAST] REQUEST     : year={year}, month={month}, prediction_days={prediction_days}")
        print(f"[FORECAST] TX RANGE    : {first_tx.strftime('%Y-%m-%d') if first_tx is not None else 'N/A'} -> {last_tx.strftime('%Y-%m-%d') if last_tx is not None else 'N/A'}")
        print(f"[FORECAST] NOTE        : TX cũ chỉ dùng làm HISTORY; không đổi TARGET MONTH.")
        print("=" * 58)

        # Phân biệt rõ:
        # - tháng quá khứ: chỉ tổng hợp thực tế, không forecast
        # - tháng hiện tại: actual từ đầu tháng đến hôm nay, forecast từ ngày mai
        # - tháng tương lai: forecast toàn tháng
        if month_end < today:
            cutoff = month_end
            forecast_start = None
        elif month_start <= today <= month_end:
            cutoff = today
            forecast_start = today + timedelta(days=1)
        else:
            cutoff = month_start - timedelta(days=1)
            forecast_start = month_start

        # Actual chỉ thuộc đúng tháng đang phân tích. Nếu tháng hiện tại chưa có
        # giao dịch thì tổng actual = 0, tuyệt đối không lấy số tháng cũ thay thế.
        actual_end = min(cutoff, month_end)
        actual_month = daily[(daily["date"] >= month_start) & (daily["date"] <= actual_end)]

        # HISTORY:
        # - current month: dữ liệu tới hôm nay, bao gồm actual tháng hiện tại nếu có.
        # - future month: chỉ dữ liệu TRƯỚC ngày đầu tháng mục tiêu.
        # - past month: chỉ dữ liệu tới cuối tháng đó.
        history = daily[daily["date"] <= cutoff].copy()

        print(f"[FORECAST] HISTORY     : {history['date'].min().strftime('%Y-%m-%d') if not history.empty else 'N/A'} -> {history['date'].max().strftime('%Y-%m-%d') if not history.empty else 'N/A'}")
        print(f"[FORECAST] ACTUAL TARGET TX DAYS: {int(actual_month['observed'].sum()) if (not actual_month.empty and 'observed' in actual_month.columns) else 0}")


        # QUAN TRỌNG:
        # Không padding từ giao dịch cuối cùng tới hôm nay bằng số 0.
        # "Không có transaction được gửi lên" != "người dùng chắc chắn không chi".
        # Padding kiểu cũ làm tháng 01 kéo một chuỗi 0 tới tháng 09 và khiến forecast sai.
        history = history.sort_values("date").reset_index(drop=True)

        if forecast_start is None or forecast_start > month_end:
            target_dates: List[pd.Timestamp] = []
        else:
            natural_days = (month_end - forecast_start).days + 1
            if prediction_days is None:
                horizon = natural_days
            else:
                horizon = min(max(int(prediction_days), 1), natural_days)
            target_dates = [forecast_start + timedelta(days=i) for i in range(horizon)]

        actual_income = float(actual_month["income"].sum()) if not actual_month.empty else 0.0
        actual_expense = float(actual_month["expense"].sum()) if not actual_month.empty else 0.0

        # THU: luôn forecast theo mức tổng tháng, sau đó phân bổ trung bình/ngày.
        inc_preds, inc_meta = self._income_monthly_forecast(
            history, actual_income, target_year, target_month, target_dates
        )

        # CHI: ngắn hạn <=7 ngày dùng daily adaptive model; dài hơn dùng monthly model.
        # Tháng tương lai tuyệt đối không recursive LSTM cho cả tháng.
        is_current_month = month_start <= today <= month_end
        if is_current_month and len(target_dates) <= 7:
            exp_preds, exp_meta = self._expense_short_forecast(history, target_dates)
            # short model trả phần còn lại; range cũng là phần còn lại.
            exp_meta["forecastType"] = "short_daily_expense"
        else:
            exp_preds, exp_meta = self._expense_monthly_forecast(
                history, actual_expense, target_year, target_month, target_dates
            )

        print(f"[FORECAST] INCOME MODEL : {inc_meta.get('model')} / {inc_meta.get('forecastType')}")
        print(f"[FORECAST] EXPENSE MODEL: {exp_meta.get('model')} / {exp_meta.get('forecastType')}")
        print(f"[FORECAST] FORECAST DAYS: {len(target_dates)}")
        print("=" * 58 + "\n")

        predictions = []
        for d, inc, exp in zip(target_dates, inc_preds, exp_preds):
            confidence = round((inc_meta["confidence"] + exp_meta["confidence"]) / 2, 2)
            parts = []
            if inc >= 1000: parts.append(f"Thu dự kiến {inc:,.0f}đ")
            if exp >= 1000: parts.append(f"Chi dự kiến {exp:,.0f}đ")
            if not parts: parts.append("Dự kiến ít phát sinh")
            predictions.append(PredictedValue(
                date=d.strftime("%Y-%m-%d"),
                predicted_income=round(inc),
                predicted_expense=round(exp),
                confidence=confidence,
                description=" • ".join(parts),
            ))

        # Chi tiết đầy đủ cho MỌI ngày trong horizon dự báo.
        # `predictions` cũ vẫn giữ để không làm vỡ API/Flutter hiện tại.
        daily_forecast_detail = self._build_daily_forecast_detail(
            target_dates=target_dates,
            inc_preds=inc_preds,
            exp_preds=exp_preds,
            inc_meta=inc_meta,
            exp_meta=exp_meta,
        )

        forecast_income = float(sum(inc_preds))
        forecast_expense = float(sum(exp_preds))
        expected_income = max(
            actual_income + forecast_income,
            float(inc_meta.get("expectedMonthlyIncome", actual_income + forecast_income))
        )
        expected_expense = max(
            actual_expense + forecast_expense,
            float(exp_meta.get("expectedMonthlyExpense", actual_expense + forecast_expense))
        )
        expected_balance = expected_income - expected_expense

        # So sánh tuần lịch thực tế (Thứ 2 -> hôm nay) với đúng cùng số ngày tuần trước.
        # Không còn dùng 14 ngày gần nhất vs 14 ngày trước.
        trend_reference = min(today, cutoff)
        income_trend = self._weekly_comparison(
            history, "income", "Thu nhập", trend_reference
        )
        expense_trend = self._weekly_comparison(
            history, "expense", "Chi tiêu", trend_reference
        )

        observed_target_days = int(actual_month["observed"].sum()) if (
            not actual_month.empty and "observed" in actual_month.columns
        ) else 0

        financial_analysis = self._build_financial_analysis(
            actual_income=actual_income,
            actual_expense=actual_expense,
            expected_income=expected_income,
            expected_expense=expected_expense,
            income_meta=inc_meta,
            expense_meta=exp_meta,
            income_week=income_trend,
            expense_week=expense_trend,
            target_dates=target_dates,
            month_start=month_start,
            month_end=month_end,
            reference_date=trend_reference,
            observed_transaction_days=observed_target_days,
            history=history,
        )

        forecast_explanation = self._build_forecast_explanation(
            actual_income=actual_income,
            actual_expense=actual_expense,
            forecast_income=forecast_income,
            forecast_expense=forecast_expense,
            expected_income=expected_income,
            expected_expense=expected_expense,
            inc_meta=inc_meta,
            exp_meta=exp_meta,
            target_dates=target_dates,
        )

        if target_dates:
            period_text = f"{target_dates[0].strftime('%d/%m')} - {target_dates[-1].strftime('%d/%m/%Y')}"
        else:
            period_text = "Tháng đã có đủ dữ liệu, không cần dự báo phần còn lại"

        summary: Dict[str, Any] = {
            # Các key cũ để hạn chế làm hỏng Flutter hiện tại
            "predictionPeriod": period_text,
            "totalPredictedIncome": round(forecast_income),
            "totalPredictedExpense": round(forecast_expense),
            "predictedBalance": round(forecast_income - forecast_expense),
            "modelConfidence": round((inc_meta["confidence"] + exp_meta["confidence"]) / 2, 2),
            "trend": {
                "incomeTrend": income_trend["text"],
                "expenseTrend": expense_trend["text"],
                "recommendation": self._recommendation(
                    actual_income,
                    actual_expense,
                    expected_income,
                    expected_expense,
                    len(target_dates),
                ),
            },

            # Key mới: đúng nhu cầu xem tài chính THEO THÁNG
            "analysisMonth": f"{target_month:02d}/{target_year}",
            "analysisType": (
                "past" if month_end < today else
                "current" if month_start <= today <= month_end else
                "future"
            ),
            "currentDate": today.strftime("%Y-%m-%d"),
            "dataUntil": cutoff.strftime("%Y-%m-%d"),
            "dataSource": {
                "role": "historical_transactions",
                "targetMonth": f"{target_month:02d}/{target_year}",
                "firstTransactionDate": first_tx.strftime("%Y-%m-%d") if first_tx is not None else None,
                "lastTransactionDate": last_tx.strftime("%Y-%m-%d") if last_tx is not None else None,
                "transactionDaysInTargetMonth": int(actual_month["observed"].sum()) if (not actual_month.empty and "observed" in actual_month.columns) else 0,
                "explanation": "Giao dịch các tháng cũ chỉ là dữ liệu lịch sử để học. analysisMonth mới là tháng được dự báo.",
            },
            "historyDaysUsed": int(min(len(history), self.max_history_days)),
            "actualSoFar": {
                "income": round(actual_income),
                "expense": round(actual_expense),
                "balance": round(actual_income - actual_expense),
            },
            "forecastRemaining": {
                "days": len(target_dates),
                "income": round(forecast_income),
                "expense": round(forecast_expense),
                "balance": round(forecast_income - forecast_expense),
            },

            # Flutter nên dùng key này cho màn "Chi tiết dự báo".
            # Mỗi ngày trong khoảng dự báo đều có một record riêng.
            "dailyForecastDetail": daily_forecast_detail,
            "dailyForecastCount": len(daily_forecast_detail),
            "dailyForecastPeriod": {
                "start": target_dates[0].strftime("%Y-%m-%d") if target_dates else None,
                "end": target_dates[-1].strftime("%Y-%m-%d") if target_dates else None,
                "days": len(target_dates),
                "completeDailySeries": True,
                "isFutureMonth": bool(month_start > today),
                "monthsAhead": self._months_between(today, month_start) if month_start > today else 0,
            },
            "expectedMonthEnd": {
                "income": round(expected_income),
                "expense": round(expected_expense),
                "balance": round(expected_balance),
                "incomeRange": {
                    "min": round(float(inc_meta.get("forecastLow", expected_income))),
                    "max": round(float(inc_meta.get("forecastHigh", expected_income))),
                },
                "expenseRange": {
                    "min": round(
                        float(exp_meta.get("forecastLow", forecast_expense))
                        if exp_meta.get("forecastType") == "monthly_expense"
                        else actual_expense + float(exp_meta.get("forecastLow", forecast_expense))
                    ),
                    "max": round(
                        float(exp_meta.get("forecastHigh", forecast_expense))
                        if exp_meta.get("forecastType") == "monthly_expense"
                        else actual_expense + float(exp_meta.get("forecastHigh", forecast_expense))
                    ),
                },
                "balanceRange": {
                    "min": round(
                        float(inc_meta.get("forecastLow", expected_income)) -
                        (
                            float(exp_meta.get("forecastHigh", forecast_expense))
                            if exp_meta.get("forecastType") == "monthly_expense"
                            else actual_expense + float(exp_meta.get("forecastHigh", forecast_expense))
                        )
                    ),
                    "max": round(
                        float(inc_meta.get("forecastHigh", expected_income)) -
                        (
                            float(exp_meta.get("forecastLow", forecast_expense))
                            if exp_meta.get("forecastType") == "monthly_expense"
                            else actual_expense + float(exp_meta.get("forecastLow", forecast_expense))
                        )
                    ),
                },
            },
            "forecastStrategy": {
                "income": "monthly_average_trend_horizon_adjusted",
                "expense": exp_meta.get("forecastType", exp_meta.get("model")),
                "longHorizonPolicy": "Tháng tương lai dùng monthly trend có giới hạn theo khoảng cách; không recursive LSTM dài hạn.",
                "incomePolicy": "Thu nhập được dự báo theo tổng tháng; daily values là phân bổ để hiển thị.",
                "futureMonthSupported": True,
                "futureDailyDetailSupported": True,
                "monthsAhead": self._months_between(today, month_start) if month_start > today else 0,
            },
            "model": {
                "income": inc_meta,
                "expense": exp_meta,
                "tensorflowAvailable": TF_AVAILABLE,
                "sequenceLength": self.sequence_length,
                "minLstmDays": self.min_lstm_days,
            },
            "trendDetail": {
                "income": income_trend,
                "expense": expense_trend,
            },
            "weeklyComparison": {
                "type": "current_week_to_date_vs_full_previous_week",
                "income": income_trend,
                "expense": expense_trend,
                "note": "Tuần này lấy từ Thứ 2 đến hiện tại; tuần trước lấy đủ Thứ 2 đến Chủ nhật. Nếu tuần này chưa kết thúc, tỷ lệ chỉ phản ánh tiến độ hiện tại.",
            },
            "financialAnalysis": financial_analysis,
            "forecastExplanation": forecast_explanation,
            "insightVersion": "v10_two_stage_7day",
        }

        if cutoff >= month_end:
            message = "Tháng đã hoàn tất; hệ thống trả về tổng hợp thực tế và không dự báo thêm ngày."
        elif not target_dates:
            message = "Không còn ngày nào trong khoảng dự báo."
        elif exp_meta.get("forecastType") == "short_daily_expense":
            message = "Thu nhập được ước tính theo mức tháng; chi tiêu ngắn hạn dùng hành vi gần đây và LSTM có kiểm soát khi validation phù hợp."
        else:
            months_ahead = self._months_between(today, month_start) if month_start > today else 0
            if month_start > today:
                message = (
                    f"Dự báo tháng tương lai (+{months_ahead} tháng): hệ thống dự báo tổng thu/chi theo lịch sử "
                    "và xu hướng tháng có giới hạn, sau đó phân bổ đầy đủ từng ngày để hiển thị. "
                    "Khoảng bất định được mở rộng khi dự báo xa hơn."
                )
            else:
                message = "Dự báo dài hạn dùng mô hình tổng theo tháng để tránh sai số tích lũy của recursive LSTM. Thu nhập và chi tiêu được xử lý bằng chiến lược riêng."

        return TrendPredictionResponse(
            success=True,
            user_id=user_id,
            predictions=predictions,
            summary=summary,
            message=message,
        )


lstm_service = LSTMService()