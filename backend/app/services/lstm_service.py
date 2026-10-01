import os
import calendar
import math
import hashlib
import re
import unicodedata
from types import SimpleNamespace
from zoneinfo import ZoneInfo
import warnings
import copy
import threading
from collections import OrderedDict
from contextvars import ContextVar
from .kmeans_service import KMeansService, _normalize_transactions, _category_key
from .isolation_forest_service import IsolationForestService

_LSTM_ENABLED = ContextVar("lux_lstm_enabled", default=True)
_LSTM_LOCK = threading.RLock()
_LSTM_CACHE = OrderedDict()
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
except (ImportError, OSError):
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

    def _fit_lstm_and_forecast(self, values, days, history=None):
        """Compare LSTM and the actual baseline on identical 7-day holdout windows.
        Holdout metrics select a model; they are not independent test-set accuracy.
        Training is serialized and cached by exact input to avoid repeated fits.
        """
        if not _LSTM_ENABLED.get():
            return [], {'model':'disabled', 'mae':None, 'confidence':0.0}
        if not TF_AVAILABLE:
            return [], {'model':'tensorflow_unavailable', 'mae':None, 'confidence':0.0}
        values = np.asarray(values, dtype=np.float32)
        if len(values) < self.min_lstm_days or days <= 0 or history is None:
            return [], {'model':'insufficient_history', 'mae':None, 'confidence':0.0}
        if not np.isfinite(values).all() or np.count_nonzero(values) < 20:
            return [], {'model':'insufficient_nonzero_days', 'mae':None, 'confidence':0.0}
        epochs = max(1, min(60, int(getattr(settings, 'LSTM_EPOCHS', 20))))
        key = hashlib.sha256(values.tobytes() + str((days, self.sequence_length, epochs,
            history['date'].astype(str).tolist())).encode()).hexdigest()
        with _LSTM_LOCK:
            if key in _LSTM_CACHE:
                _LSTM_CACHE.move_to_end(key)
                return copy.deepcopy(_LSTM_CACHE[key])
            cut = len(values) - 14
            scale = RobustScaler(quantile_range=(10,90))
            scale.fit(values[:cut].reshape(-1,1))
            z = scale.transform(values.reshape(-1,1)).astype(np.float32)
            X, y = self._build_sequences(z[:cut])
            if len(X) < 20:
                return [], {'model':'insufficient_sequences','mae':None,'confidence':0.0}
            def make_model():
                model = Sequential([Input(shape=(self.sequence_length,1)),
                    LSTM(48,return_sequences=True), Dropout(.15), LSTM(24),
                    Dense(16,activation='relu'), Dense(1)])
                model.compile(optimizer=Adam(learning_rate=8e-4),loss=tf.keras.losses.Huber())
                return model
            def recursive(model, seq, count, scaler):
                seq = np.asarray(seq,dtype=np.float32).reshape(1,self.sequence_length,1)
                out=[]
                for _ in range(count):
                    value = float(model(seq,training=False).numpy()[0,0])
                    if not np.isfinite(value):
                        raise ValueError('LSTM produced a nonfinite prediction')
                    out.append(value)
                    seq = np.concatenate([seq[:,1:,:],np.array([[[value]]],dtype=np.float32)],axis=1)
                return np.maximum(scaler.inverse_transform(np.array(out).reshape(-1,1)).ravel(),0)
            try:
                tf.keras.backend.clear_session()
                tf.keras.utils.set_random_seed(42)
                model=make_model()
                # train_on_batch avoids allocating a tf.data private pool per request.
                for _ in range(epochs):
                    for j in range(0,len(X),32):
                        model.train_on_batch(X[j:j+32],y[j:j+32])
                errors, baseline_errors = [], []
                for origin in (cut,cut+7):
                    truth=values[origin:origin+7]
                    pred=recursive(model,z[origin-self.sequence_length:origin],len(truth),scale)
                    hist=history.iloc[:origin].copy()
                    dates=history.iloc[origin:origin+7]['date'].tolist()
                    p=self._expense_occurrence_probability(hist,dates)
                    a,_=self._expense_amount_when_spending(hist,dates)
                    base=np.asarray([0.0 if pi<.18 else pi*ai for pi,ai in zip(p,a)])
                    errors.extend(np.abs(truth-pred).tolist())
                    baseline_errors.extend(np.abs(truth-base).tolist())
                mae=float(np.mean(errors)); bmae=float(np.mean(baseline_errors))
                meta={'model':'lstm_evaluated','mae':round(mae,2),
                      'baselineMae':round(bmae,2),'validationSamples':len(errors),
                      'validationHorizon':7,'evaluationMeaning':'model_selection_holdout_not_final_test',
                      'confidence':round(1/(1+mae/max(float(np.mean(values[-14:])),1)),3)}
                if mae >= bmae:
                    result=([], {**meta,'model':'baseline_selected'})
                else:
                    # Refit to all observed data only after selection; no future actuals.
                    scale=RobustScaler(quantile_range=(10,90))
                    z=scale.fit_transform(values.reshape(-1,1)).astype(np.float32)
                    X,y=self._build_sequences(z)
                    tf.keras.backend.clear_session()
                    tf.keras.utils.set_random_seed(42)
                    model=make_model()
                    for _ in range(epochs):
                        for j in range(0,len(X),32):
                            model.train_on_batch(X[j:j+32],y[j:j+32])
                    pred=recursive(model,z[-self.sequence_length:],days,scale)
                    result=([float(x) for x in pred], {**meta,'model':'lstm'})
                _LSTM_CACHE[key]=copy.deepcopy(result)
                while len(_LSTM_CACHE)>8:
                    _LSTM_CACHE.popitem(last=False)
                return result
            except (ValueError, RuntimeError, FloatingPointError) as exc:
                return [], {'model':'lstm_runtime_fallback','mae':None,'confidence':0.0,
                            'reason':type(exc).__name__}
            finally:
                tf.keras.backend.clear_session()

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
        if (target_dates[0] - hist["date"].max()).days > 7:
            lstm_preds, lm = [], {"model": "stale_history", "mae": None}
        else:
            lstm_preds, lm = self._fit_lstm_and_forecast(
                hist["expense"].to_numpy(dtype=float), len(target_dates), history=hist
            )

        lstm_weight = 0.0
        if lstm_preds and lm.get("mae") is not None and lm.get("baselineMae") is not None:
            lmae = float(lm["mae"])
            bmae = float(lm["baselineMae"])

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
            "lstmEvaluation": lm,
            "modelActuallyUsed": "baseline_plus_lstm" if lstm_weight > 0 else "behavior_baseline",
            "maeMeaning": "baseline_backtest_not_ensemble_accuracy",
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
                "expenseIsAllocation": exp_meta.get("forecastType") == "monthly_expense" and not bool(behavior),
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
    def _predict_month_trend(
        self,
        user_id: str,
        transactions: List[Any],
        prediction_days: Optional[int] = None,
        year: Optional[int] = None,
        month: Optional[int] = None,
        reference_date: Optional[pd.Timestamp] = None,
    ) -> TrendPredictionResponse:
        today = pd.Timestamp(reference_date).normalize() if reference_date is not None else pd.Timestamp.now().normalize()
        if year is None and month is None:
            year, month = today.year, today.month
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
            cutoff = today
            forecast_start = month_start

        # Actual chỉ thuộc đúng tháng đang phân tích. Nếu tháng hiện tại chưa có
        # giao dịch thì tổng actual = 0, tuyệt đối không lấy số tháng cũ thay thế.
        actual_end = min(cutoff, month_end)
        actual_month = daily[(daily["date"] >= month_start) & (daily["date"] <= actual_end)]

        # HISTORY:
        # - current month: dữ liệu tới hôm nay, bao gồm actual tháng hiện tại nếu có.
        # - future month: chỉ dữ liệu TRƯỚC ngày đầu tháng mục tiêu.
        # - past month: chỉ dữ liệu tới cuối tháng đó.
        history = daily[daily["date"] <= min(cutoff, today)].copy()

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

        # Full-month accounting with adaptive short-term expense for the first week.
        if is_current_month and len(target_dates) > 7:
            short_preds, short_meta = self._expense_short_forecast(history, target_dates[:7])
            old_total = float(exp_meta.get("expectedMonthlyExpense", actual_expense + sum(exp_preds)))
            margin = max(old_total - float(exp_meta.get("forecastLow", old_total)),
                         float(exp_meta.get("forecastHigh", old_total)) - old_total, 0.0)
            exp_preds = short_preds + exp_preds[7:]
            revised_total = actual_expense + sum(exp_preds)
            exp_meta.update({"expectedMonthlyExpense": revised_total,
                             "remainingExpenseForecast": sum(exp_preds),
                             "forecastLow": max(actual_expense, revised_total-margin),
                             "forecastHigh": revised_total+margin,
                             "shortTermModel": short_meta,
                             "dailyBehavior": short_meta.get("dailyBehavior", []),
                             "hybridFirstWeek": True})

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
        if month_end <= today:
            expected_income, expected_expense = actual_income, actual_expense
            for meta, value in ((inc_meta, actual_income), (exp_meta, actual_expense)):
                if meta is exp_meta and meta.get("forecastType") == "short_daily_expense":
                    value = 0.0
                meta["forecastLow"] = meta["forecastHigh"] = value
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


    # ------------------------------------------------------------------
    # PERSONAL ADVISOR — additive API, no Firebase/UI side effects.
    # ------------------------------------------------------------------
    # Existing calls remain valid:
    #   predict_trend(uid, transactions, prediction_days=7)
    # Optional keyword-only input:
    #   advisor_context={
    #     "available_balance": 5000000,  # snapshot at reference_date; includes actuals
    #     "reserve_amount": 1000000, "savings_hold": 0,
    #     "horizon_days": 30, "timezone": "Asia/Ho_Chi_Minh",
    #     "reference_date": "2026-09-29T18:00:00+07:00",
    #     "events": [{"id":"rent-oct", "title":"Tiền nhà",
    #       "due_date":"2026-10-03", "amount":2000000, "kind":"expense",
    #       "confirmed":True, "status":"pending", "required":True,
    #       "category":"rent", "recurrence_id":"rent-series",
    #       "transaction_ids":[]}],
    #     "budgets": [{"id":"food", "limit":3000000, "spent":1000000,
    #       "year":2026, "month":9, "category":"food"}],
    #     "notification_opt_in": True, "notification_hour": 9,
    #     "dismissed_card_ids": [], "sent_notification_keys": []
    #   }
    # Monetary unit: VND. Pass numbers, NOT formatted strings. Existing snapshot
    # must already include paid transactions; they are never deducted again.
    # Events are dated occurrences, not recurrence rules: caller persists/generates
    # confirmed future occurrences. Detected candidates require user confirmation.
    # Caller owns auth/uid filtering, transactions completeness, persistent action
    # state, idempotent payment write, FCM token, scheduler and dispatch.
    # Action descriptors and notificationPlan are proposals, never executions.
    # On Windows, install tzdata if ZoneInfo cannot find Asia/Ho_Chi_Minh.

    @staticmethod
    def _field(obj: Any, *keys: str, default: Any = None) -> Any:
        for key in keys:
            value = obj.get(key) if isinstance(obj, dict) else getattr(obj, key, None)
            if value is not None:
                return value
        return default

    @staticmethod
    def _number(value: Any, name: str, allow_negative: bool = False) -> float:
        if isinstance(value, bool):
            raise ValueError(f"{name} phải là số tiền hợp lệ.")
        try:
            result = float(value)
        except (ValueError, TypeError):
            raise ValueError(f"{name} phải là số tiền hợp lệ.")
        if not math.isfinite(result) or (not allow_negative and result < 0):
            raise ValueError(f"{name} phải hữu hạn" + ("." if allow_negative else " và không âm."))
        return result

    @staticmethod
    def _local_day(value: Any, timezone: str) -> pd.Timestamp:
        ts = pd.Timestamp(value)
        if pd.isna(ts):
            raise ValueError("Ngày không hợp lệ.")
        if ts.tzinfo is not None:
            ts = ts.tz_convert(timezone).tz_localize(None)
        return ts.normalize()

    @staticmethod
    def _stable_id(*parts: Any) -> str:
        return hashlib.sha256("|".join(map(str, parts)).encode()).hexdigest()[:20]

    def _advisor_transactions(self, transactions: List[Any], timezone: str,
                              today: pd.Timestamp) -> Tuple[List[Any], List[str]]:
        clean, warnings_out, seen = [], [], set()
        for index, tx in enumerate(transactions or []):
            try:
                amount = self._number(self._field(tx, "money", "amount", default=0), "money", True)
                day = self._local_day(self._field(tx, "date_time", "dateTime", "date"), timezone)
                if amount == 0:
                    continue
                if day > today:
                    warnings_out.append(f"Giao dịch tương lai #{index} không được dùng làm thực tế; hãy khai báo events.")
                    continue
                tid = str(self._field(tx, "id", default=""))
                if tid and tid in seen:
                    warnings_out.append(f"Bỏ giao dịch trùng id: {tid}.")
                    continue
                if tid:
                    seen.add(tid)
                # Explicit transfer flags prevent treating own-account transfers as income.
                if self._field(tx, "is_transfer", "isTransfer", default=False) is True:
                    continue
                expense = self._field(tx, "is_expense", "isExpense")
                income = self._field(tx, "is_income", "isIncome")
                if expense is True and income is True:
                    raise ValueError("Giao dịch không thể đồng thời là thu và chi.")
                kind = "expense" if expense is True else "income" if income is True else (
                    "expense" if amount < 0 else "income")
                clean.append(SimpleNamespace(
                    id=tid, money=abs(amount) * (-1 if kind == "expense" else 1),
                    date_time=day, is_expense=kind == "expense", is_income=kind == "income",
                    category=str(self._field(tx, "category_name", "type_name", "typeName", "category", "type", default="")),
                    category_id=str(self._field(tx, "category_id", "type", default="")),
                    note=str(self._field(tx, "note", default="")),
                    merchant=str(self._field(tx, "merchant", "payee", default="")),
                    recurrence_id=str(self._field(tx, "recurrence_id", "recurrenceId", default="")),
                ))
            except (ValueError, TypeError, OverflowError) as exc:
                warnings_out.append(f"Bỏ giao dịch #{index}: {exc}")
        return sorted(clean, key=lambda x: x.date_time), warnings_out

    def _detect_recurring(self, transactions: List[Any], today: pd.Timestamp) -> List[Dict[str, Any]]:
        """Conservative heuristic: 3+ separate dates, stable amount and cadence.
        Group by recurrence id OR merchant/note + category; category alone is weak.
        These are candidates, not guaranteed future income or reserved expenses.
        """
        groups: Dict[Any, List[Any]] = {}
        for tx in transactions:
            label = tx.recurrence_id or tx.merchant or re.sub(r"\s+", " ", tx.note.strip().lower())
            if not label:
                continue
            key = ("expense" if tx.is_expense else "income", tx.category, label)
            groups.setdefault(key, []).append(tx)
        result = []
        for key, records in groups.items():
            records = records[-12:]
            dates = sorted(set(x.date_time for x in records))
            if len(dates) < 3 or len(dates) != len(records):
                continue
            amounts = np.array([abs(x.money) for x in records])
            median = float(np.median(amounts))
            if median <= 0 or float(np.max(np.abs(amounts - median))) / median > .25:
                continue
            gaps = np.array([(b - a).days for a, b in zip(dates, dates[1:])])
            if np.all((gaps >= 6) & (gaps <= 8)):
                cadence, step = "weekly", 7
            elif np.all((gaps >= 13) & (gaps <= 15)):
                cadence, step = "biweekly", 14
            elif np.all((gaps >= 27) & (gaps <= 32)):
                cadence, step = "monthly", 0
            else:
                continue
            if (today - dates[-1]).days > (65 if cadence == "monthly" else step * 2):
                continue
            due = dates[-1]
            anchor_day = int(np.median([d.day for d in dates]))
            end_of_month = all(d.day == calendar.monthrange(d.year, d.month)[1] for d in dates)
            for _ in range(100):
                if cadence == "monthly":
                    period = due.to_period("M") + 1
                    last = calendar.monthrange(period.year, period.month)[1]
                    due = pd.Timestamp(period.year, period.month, last if end_of_month else min(anchor_day, last))
                else:
                    due += timedelta(days=step)
                if due > today:
                    break
            result.append({
                "id": self._stable_id(*key), "title": records[-1].merchant or records[-1].note or key[2],
                "kind": key[0], "category": key[1], "amount": round(median),
                "cadence": cadence, "nextDueDate": due.strftime("%Y-%m-%d"),
                "sampleCount": len(records), "transactionIds": [x.id for x in records if x.id],
                "recurrenceId": records[-1].recurrence_id or None,
                "status": "needs_confirmation", "confidenceType": "heuristic_not_probability",
            })
        return result

    def _advisor_events(self, context: Dict[str, Any], transactions: List[Any],
                        today: pd.Timestamp, timezone: str) -> List[Dict[str, Any]]:
        events, seen = [], set()
        actual_ids = {t.id for t in transactions if t.id}
        for item in context.get("events", []):
            eid = str(item.get("id", "")).strip()
            if not eid or eid in seen:
                raise ValueError("Mỗi event phải có id duy nhất, không rỗng.")
            seen.add(eid)
            status = item.get("status", "pending")
            if status not in ("pending", "paid", "received", "cancelled"):
                raise ValueError(f"Event {eid}: status không hợp lệ.")
            # Status and explicit actual links are authoritative, no fuzzy auto-payment.
            linked = list(map(str, item.get("transaction_ids", [])))
            if status != "pending" or (set(linked) & actual_ids):
                continue
            kind = item.get("kind")
            if kind not in ("income", "expense"):
                raise ValueError(f"Event {eid}: kind phải là income hoặc expense.")
            amount = self._number(item.get("amount"), f"event {eid}.amount")
            if amount <= 0:
                raise ValueError(f"Event {eid}: amount phải lớn hơn 0.")
            due = self._local_day(item.get("due_date"), timezone)
            events.append({
                "id": eid, "title": str(item.get("title", eid)), "amount": amount,
                "kind": kind, "dueDate": due.strftime("%Y-%m-%d"),
                "effectiveDate": max(due, today + timedelta(days=1)).strftime("%Y-%m-%d"),
                "overdue": due < today, "dueToday": due == today,
                "confirmed": item.get("confirmed") is True,
                "required": item.get("required", True) is True,
                "category": str(item.get("category", "")),
                "recurrenceId": str(item.get("recurrence_id", "")),
                "transactionIds": linked,
                # Overdue income cannot support safe spending until date is reconfirmed.
                "usableIncome": kind == "income" and item.get("confirmed") is True and due > today,
            })
        return sorted(events, key=lambda e: (e["effectiveDate"], e["id"]))

    def build_advisor(self, user_id: str, transactions: List[Any],
                      context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Pure recalculation. Reinvoke after add/edit/delete/payment/balance change.
        Timeline starts tomorrow; due/overdue unpaid expenses are reserved immediately.
        No scheduled job, persistence, push dispatch or financial action occurs here.
        """
        c = dict(context or {})
        for key in ("events", "budgets"):
            if not isinstance(c.get(key, []), list) or not all(isinstance(x, dict) for x in c.get(key, [])):
                raise ValueError(f"{key} phải là danh sách object.")
        timezone = str(c.get("timezone", "Asia/Ho_Chi_Minh"))
        ZoneInfo(timezone)  # fail clearly instead of silently using server timezone
        now = pd.Timestamp(c.get("reference_date") or datetime.now(ZoneInfo(timezone)))
        now = now.tz_localize(timezone) if now.tzinfo is None else now.tz_convert(timezone)
        today = now.tz_localize(None).normalize()
        raw_horizon = c.get("horizon_days", 30)
        horizon = int(raw_horizon)
        if isinstance(raw_horizon, bool) or horizon != float(raw_horizon) or not 1 <= horizon <= 30:
            raise ValueError("horizon_days phải là số nguyên từ 1 đến 30.")
        reserve = self._number(c.get("reserve_amount", 0), "reserve_amount")
        savings = self._number(c.get("savings_hold", 0), "savings_hold")
        balance = None if c.get("available_balance") is None else self._number(
            c["available_balance"], "available_balance", True)
        clean, warnings_out = self._advisor_transactions(transactions, timezone, today)
        candidates = self._detect_recurring(clean, today)
        events = self._advisor_events(c, clean, today, timezone)
        dates = [today + timedelta(days=i) for i in range(1, horizon + 1)]
        end = dates[-1].strftime("%Y-%m-%d")
        active = [e for e in events if e["effectiveDate"] <= end]
        # Remove only explicitly linked recurring historical expenses. Unknown
        # overlaps remain conservative and are surfaced as a data warning.
        recurring_ids = {e["recurrenceId"] for e in active if e["confirmed"] and e["recurrenceId"]}
        excluded_ids = set()
        for event in active:
            if event["confirmed"]:
                excluded_ids.update(event["transactionIds"])
        # Candidate matching by an explicit series ID lets confirmed occurrences
        # refer to historical records without misusing payment transaction_ids.
        excluded_ids.update(str(x) for x in c.get("fixed_expense_transaction_ids", []))
        flex_records = [t for t in clean if t.is_expense and t.id not in excluded_ids
                        and not (t.recurrence_id and t.recurrence_id in recurring_ids)]
        full_daily = self._prepare_daily_data(clean)
        flex_daily = self._prepare_daily_data(flex_records)
        if not full_daily.empty:
            # Preserve zero-expense dates in observed history after removing fixed bills.
            skeleton = full_daily[["date", "observed"]].copy()
            flex_daily = skeleton.merge(flex_daily[["date", "expense"]], on="date", how="left")
            flex_daily["expense"] = flex_daily["expense"].fillna(0.0)
            flex_daily["income"] = 0.0
        stale = not clean or (today - clean[-1].date_time).days > 7
        if stale:
            warnings_out.append("Lịch sử thiếu hoặc quá 7 ngày chưa cập nhật; dự báo chi linh hoạt có thể không phản ánh hiện tại.")
        if any(e["confirmed"] and e["kind"] == "expense" for e in active) and not (recurring_ids or excluded_ids):
            warnings_out.append("Chưa liên kết khoản cố định với lịch sử; dự báo chi linh hoạt có thể còn chứa khoản cố định.")
        # Adviser uses robust daily behavior. Old monthly forecast retains optional LSTM.
        probs = self._expense_occurrence_probability(flex_daily, dates)
        amounts, _ = self._expense_amount_when_spending(flex_daily, dates)
        flex = [0.0 if p < .18 else p * a for p, a in zip(probs, amounts)]
        running = balance
        fixed_cash = balance
        safe_caps, timeline, first_shortfall = [], [], None
        for i, (day, flexible) in enumerate(zip(dates, flex), 1):
            day_key = day.strftime("%Y-%m-%d")
            day_events = [e for e in active if e["effectiveDate"] == day_key]
            income = sum(e["amount"] for e in day_events if e["usableIncome"])
            # All confirmed spending is a commitment until cancelled by the user.
            committed = sum(e["amount"] for e in day_events if e["kind"] == "expense" and e["confirmed"])
            if running is not None:
                opening = running
                # Expenses before same-day income: do not assume salary arrives first.
                low = opening - committed - flexible
                running = low + income
                if low < 0 and first_shortfall is None:
                    first_shortfall = day_key
                fixed_cash -= committed
                safe_caps.append((fixed_cash - reserve - savings) / i)
                fixed_cash += income
            else:
                opening = low = None
            timeline.append({
                "date": day_key, "openingBalance": round(opening) if opening is not None else None,
                "confirmedIncome": round(income), "committedExpense": round(committed),
                "flexibleExpenseForecast": round(flexible),
                "projectedBalance": round(running) if running is not None else None,
                "conservativeIntradayBalance": round(low) if low is not None else None,
                "belowReserve": low < reserve + savings if low is not None else None,
                "events": day_events,
            })
        allowance = math.floor(max(0.0, min(safe_caps))) if safe_caps else None
        budgets = []
        seen_budgets = set()
        for b in c.get("budgets", []):
            bid = str(b.get("id", ""))
            if not bid or bid in seen_budgets:
                raise ValueError("Mỗi budget phải có id duy nhất.")
            seen_budgets.add(bid)
            limit = self._number(b.get("limit", b.get("limitMoney")), "budget.limit")
            spent = self._number(b.get("spent"), "budget.spent")
            if int(b.get("year", today.year)) != today.year or int(b.get("month", today.month)) != today.month:
                continue
            days_left = calendar.monthrange(today.year, today.month)[1] - today.day
            budgets.append({"id": bid, "category": str(b.get("category", bid)),
                            "limit": round(limit), "spent": round(spent),
                            "remaining": round(max(0.0, limit-spent)),
                            "remainingPerDay": math.floor(max(0.0, limit-spent)/days_left) if days_left else 0,
                            "usagePercent": round(spent/limit*100, 1) if limit else None,
                            "overBudget": spent > limit})
        cards = []
        def add_card(kind, key, title, body, priority, actions, due=None):
            cid = self._stable_id(user_id, kind, key)
            cards.append({"id": cid, "type": kind, "title": title, "body": body,
                          "priority": priority, "dueDate": due, "actions": actions})
        def action(name, label, payload):
            return {"type": name, "label": label, "payload": payload,
                    "requiresUserConfirmation": name not in ("view_timeline", "view_budget"),
                    "execution": "client_or_authenticated_api"}
        if balance is None:
            add_card("missing_balance", "balance", "Cập nhật số dư khả dụng",
                     "Cần số dư thực tế để tính mức chi an toàn và nguy cơ thiếu tiền.", 1,
                     [action("update_balance", "Cập nhật số dư", {})])
        elif first_shortfall:
            add_card("cash_shortfall", first_shortfall, "Có nguy cơ thiếu tiền",
                     f"Dòng tiền có thể âm vào {first_shortfall}; kiểm tra khoản đến hạn và giảm chi linh hoạt.", 1,
                     [action("view_timeline", "Xem kế hoạch", {"date": first_shortfall}),
                      action("review_budget", "Điều chỉnh ngân sách", {})])
        if allowance is not None and flex and float(np.mean(flex)) > allowance:
            add_card("reduce_spending", today.strftime("%Y-%m-%d"), "Giảm nhịp chi linh hoạt",
                     f"Chi dự báo trung bình {np.mean(flex):,.0f}đ/ngày; mức khả dụng thận trọng {allowance:,.0f}đ/ngày.", 2,
                     [action("review_budget", "Xem lại ngân sách", {"dailyTarget": allowance})])
        for e in active:
            if not e["confirmed"]:
                continue
            due = pd.Timestamp(e["dueDate"])
            if e["kind"] == "expense":
                add_card("bill_due", e["id"], e["title"],
                         f"{'Quá hạn' if e['overdue'] else 'Đến hạn'} {e['dueDate']}: {e['amount']:,.0f}đ.",
                         1 if (due-today).days <= 3 else 3,
                         [action("mark_paid", "Ghi nhận đã thanh toán", {"eventId": e["id"]}),
                          action("reschedule_event", "Đổi ngày", {"eventId": e["id"]})], e["dueDate"])
            elif e["usableIncome"]:
                obligations = sum(x["amount"] for x in active if x["kind"] == "expense" and x["confirmed"]
                                  and x["effectiveDate"] >= e["effectiveDate"])
                fixed_share = min(e["amount"], obligations)
                # Proposal only, not a transfer or a guaranteed salary recognition.
                add_card("allocate_income", e["id"], "Lập kế hoạch cho khoản thu sắp tới",
                         f"{e['title']}: {e['amount']:,.0f}đ dự kiến ngày {e['dueDate']}. Xem và chỉnh phương án trước khi áp dụng.", 3,
                         [action("review_income_allocation", "Phân bổ khoản thu", {
                             "eventId": e["id"], "amount": round(e["amount"]),
                             "suggestedCommitted": round(fixed_share),
                             "unallocated": round(e["amount"]-fixed_share)})], e["dueDate"])
        for b in budgets:
            if b["overBudget"] or (b["usagePercent"] is not None and b["usagePercent"] >= 85):
                add_card("budget_pressure", b["id"], f"Kiểm tra ngân sách {b['category']}",
                         f"Đã chi {b['spent']:,.0f}đ trên hạn mức {b['limit']:,.0f}đ.", 2,
                         [action("view_budget", "Xem ngân sách", {"budgetId": b["id"]}),
                          action("edit_budget", "Điều chỉnh", {"budgetId": b["id"]})])
        for candidate in candidates:
            if c.get("enable_recurring_confirmation") is not True:
                continue
            if candidate["recurrenceId"] and candidate["recurrenceId"] in recurring_ids:
                continue
            add_card("confirm_recurring", candidate["id"], "Có thể là khoản định kỳ",
                     f"{candidate['title']}: khoảng {candidate['amount']:,.0f}đ. Xác nhận lịch trước khi đưa vào kế hoạch.", 4,
                     [action("confirm_recurring", "Xác nhận lịch", {"candidateId": candidate["id"], "candidate": candidate})])
        dismissed = set(map(str, c.get("dismissed_card_ids", [])))
        cards = sorted([x for x in cards if x["id"] not in dismissed], key=lambda x: (x["priority"], x["id"]))
        notification_plan = []
        hour = int(c.get("notification_hour", 9))
        if not 8 <= hour <= 20:
            raise ValueError("notification_hour phải nằm trong 8..20 để tránh giờ nghỉ.")
        sent = set(map(str, c.get("sent_notification_keys", [])))
        if c.get("notification_opt_in") is True:
            for card in cards:
                if card["type"] not in ("bill_due", "cash_shortfall", "budget_pressure"):
                    continue
                notify_day = max(today, pd.Timestamp(card["dueDate"])-timedelta(days=3)) if card["dueDate"] else today
                send_at = (notify_day + timedelta(hours=hour)).tz_localize(timezone)
                if send_at < now:
                    send_at = now.ceil("min")
                    if send_at.hour < 8:
                        send_at = send_at.normalize() + timedelta(hours=hour)
                    elif send_at.hour >= 21:
                        send_at = send_at.normalize() + timedelta(days=1, hours=hour)
                key = self._stable_id(user_id, card["id"], send_at.strftime("%Y-%m-%d"))
                if key in sent:
                    continue
                notification_plan.append({"deduplicationKey": key, "cardId": card["id"],
                                          "scheduledAt": send_at.isoformat(), "title": card["title"],
                                          "body": card["body"], "status": "planned_not_sent",
                                          "revalidateBeforeSend": True})
            notification_plan = sorted(notification_plan, key=lambda x: x["scheduledAt"])[:3]
        if balance is None:
            warnings_out.append("Thiếu available_balance: không tính số dư hoặc mức chi an toàn.")
        warnings_out.append("Khoản thu dự báo chỉ là ước tính, không được cộng vào số dư thực tế.")
        return {
            "version": "v12_personal_advisor", "userId": user_id, "timezone": timezone,
            "asOf": now.isoformat(), "horizonDays": horizon,
            "dailySafeToSpend": {
                "amount": allowance, "currency": "VND", "availableBalance": balance,
                "reserveAmount": reserve, "savingsHold": savings,
                "status": "missing_balance" if balance is None else "no_headroom" if allowance == 0 else "estimated",
                "startDate": dates[0].strftime("%Y-%m-%d"), "endDate": end,
                "method": "minimum_prefix_cash_after_commitments_and_reserves_divided_by_elapsed_days",
                "assumptions": ["Số dư đã bao gồm giao dịch thực tế đến thời điểm tính.",
                                "Khoản chi trong ngày có thể đến trước khoản thu cùng ngày.",
                                "Đây là hạn mức dòng tiền; ngân sách từng danh mục vẫn áp dụng riêng.",
                                "Chỉ bảo vệ trong khoảng ngày hiển thị; tính lại khi dữ liệu thay đổi."],
            },
            "timeline": timeline, "recurringCandidates": candidates, "actionCards": cards,
            "budgets": budgets, "notificationPlan": notification_plan,
            "firstShortfallDate": first_shortfall, "warnings": list(dict.fromkeys(warnings_out)),
            "integration": {"actionsExecuted": False, "notificationsSent": False,
                            "requiresRecalculationAfterMutation": True,
                            "forecastConfidenceIsAccuracy": False},
        }

    def _predict_legacy_month(self, user_id: str, transactions: List[Any],
                      prediction_days: Optional[int] = None, year: Optional[int] = None,
                      month: Optional[int] = None, *,
                      advisor_context: Optional[Dict[str, Any]] = None) -> TrendPredictionResponse:
        """Compatible entry point. Old monthly keys + summary.personalAdvisor.
        Monthly prediction_days is capped at month end for legacy compatibility.
        personalAdvisor.timeline independently spans 7-30 days across months.
        available_balance always describes NOW, not the selected analysis month.
        Pass advisor_context through the route/schema to enable additional inputs.
        """
        try:
            context = dict(advisor_context or {})
            advisor = self.build_advisor(user_id, transactions, context)
            today = self._local_day(advisor["asOf"], advisor["timezone"])
            clean, _ = self._advisor_transactions(transactions, advisor["timezone"], today)
            if year is not None or month is not None:
                if year is None or month is None or not 1 <= int(month) <= 12 or not 1 <= int(year) <= 9999:
                    raise ValueError("Phải truyền đồng thời year hợp lệ và month trong 1..12.")
            if prediction_days is not None and (isinstance(prediction_days, bool) or int(prediction_days) < 1
                                                or int(prediction_days) != float(prediction_days)):
                raise ValueError("prediction_days phải là số nguyên dương.")
            # Always calculate complete month before slicing UI horizon, preventing
            # a 7-day estimate being mislabeled as the full month-end result.
            response = self._predict_month_trend(user_id, clean, None, year, month, today)
            summary = response.summary
            summary["personalAdvisor"] = advisor
            summary["insightVersion"] = "v11_personal_advisor"
            summary["balanceMeaning"] = "net_cash_flow_not_wallet_balance"
            summary["confidenceMeaning"] = "heuristic_score_not_accuracy_probability"
            details = summary.get("dailyForecastDetail", [])
            if prediction_days is not None and details:
                kept = details[:int(prediction_days)]
                response.predictions = response.predictions[:len(kept)]
                income = sum(x["predictedIncome"] for x in kept)
                expense = sum(x["predictedExpense"] for x in kept)
                summary.update({"dailyForecastDetail": kept, "dailyForecastCount": len(kept),
                                "totalPredictedIncome": income, "totalPredictedExpense": expense,
                                "predictedBalance": income-expense,
                                "forecastRemaining": {"days": len(kept), "income": income,
                                                      "expense": expense, "balance": income-expense}})
                summary["dailyForecastPeriod"].update({"end": kept[-1]["date"], "days": len(kept)})
                summary["predictionPeriod"] = f"{kept[0]['date']} - {kept[-1]['date']}"
                summary["forecastExplanation"]["forecastDays"] = len(kept)
            summary["forecastScopeNote"] = (
                "forecastRemaining là khoảng đang hiển thị; expectedMonthEnd tính toàn phần còn lại của tháng. "
                "personalAdvisor dùng số dư hiện tại và lịch 7–30 ngày độc lập với tháng đang xem.")
            if not response.success and advisor_context is not None:
                response.success = True
                response.message = "Đã lập kế hoạch từ số dư/sự kiện; chưa có lịch sử để dự báo thống kê."
            return response
        except (ValueError, TypeError, KeyError, OverflowError) as exc:
            return TrendPredictionResponse(success=False, user_id=user_id, predictions=[], summary={},
                                           message=f"Dữ liệu đầu vào không hợp lệ: {exc}")


    def _predict_v12(self, user_id: str, transactions: List[Any],
                      prediction_days: Optional[int] = None, year: Optional[int] = None,
                      month: Optional[int] = None, *,
                      advisor_context: Optional[Dict[str, Any]] = None,
                      forecast_mode: str = "rolling") -> TrendPredictionResponse:
        """V12: default rolling tomorrow -> tomorrow + N - 1, even across years.

        rolling: prediction_days defaults to context.horizon_days or 7; supports
                 1..30 days. year/month select MONTHLY REPORT only, never trim
                 rolling predictions. Adviser uses the identical date window.
        month: explicit legacy month view; days may be truncated at month end.

        predictions/dailyForecastDetail/totals all describe forecastWindow.
        actualSoFar/expectedMonthEnd/financialAnalysis describe analysisMonth.
        monthlyBreakdown explicitly separates each partial window from its
        full month estimate. Income allocation is not a dated salary promise.
        """
        try:
            if forecast_mode not in ("rolling", "month"):
                raise ValueError("forecast_mode phải là rolling hoặc month.")
            if forecast_mode == "month":
                response = self._predict_legacy_month(user_id, transactions, prediction_days,
                                                      year, month, advisor_context=advisor_context)
                if response.success:
                    response.summary["forecastMode"] = "month"
                    response.summary["insightVersion"] = "v12_cross_month"
                return response
            context = dict(advisor_context or {})
            raw_days = prediction_days if prediction_days is not None else context.get("horizon_days", 7)
            days = int(raw_days)
            if isinstance(raw_days, bool) or days != float(raw_days) or not 1 <= days <= 30:
                raise ValueError("prediction_days phải là số nguyên từ 1 đến 30.")
            context["horizon_days"] = days
            advisor = self.build_advisor(user_id, transactions, context)
            today = self._local_day(advisor["asOf"], advisor["timezone"])
            clean, warnings_out = self._advisor_transactions(transactions, advisor["timezone"], today)
            if (year is None) != (month is None):
                raise ValueError("Phải truyền đồng thời year và month hoặc bỏ cả hai.")
            selected_year = int(year) if year is not None else today.year
            selected_month = int(month) if month is not None else today.month
            if year is not None and (isinstance(year, bool) or isinstance(month, bool)
                                      or float(year) != selected_year or float(month) != selected_month):
                raise ValueError("year/month phải là số nguyên.")
            self._month_bounds(selected_year, selected_month)
            dates = [today + timedelta(days=i) for i in range(1, days+1)]
            periods = list(dict.fromkeys((d.year, d.month) for d in dates))
            reports = {}
            # Each month uses the same real history cutoff. Never feed generated
            # September forecasts into October training as if they were actuals.
            for yy, mm in list(dict.fromkeys(periods + [(selected_year, selected_month)])):
                reports[(yy, mm)] = self._predict_month_trend(user_id, clean, None, yy, mm, today)
            selected = reports[(selected_year, selected_month)]
            summary = dict(selected.summary)
            daily_rows = {}
            for key, response in reports.items():
                for row in response.summary.get("dailyForecastDetail", []):
                    daily_rows[row["date"]] = dict(row)
            details, predictions, suggestions = [], [], []
            cumulative_income = cumulative_expense = 0
            plan_by_date = {r["date"]: r for r in advisor["timeline"]}
            safe = advisor["dailySafeToSpend"]["amount"]
            for index, day in enumerate(dates, 1):
                date_key = day.strftime("%Y-%m-%d")
                row = daily_rows.get(date_key)
                available = row is not None
                if row is None:
                    # Numeric zeros preserve legacy response schemas. Explicit
                    # availability prevents interpreting missing history as no spending.
                    row = {"date": date_key, "displayDate": day.strftime("%d/%m/%Y"),
                           "weekday": ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ nhật"][day.weekday()],
                           "predictedIncome": 0, "predictedExpense": 0, "confidence": 0.0,
                           "incomeIsAllocation": True, "expenseIsAllocation": True,
                           "description": "Chưa đủ lịch sử để ước tính thu–chi ngày này."}
                income, expense = int(row["predictedIncome"]), int(row["predictedExpense"])
                cumulative_income += income
                cumulative_expense += expense
                row.update({"index": index, "analysisMonth": day.strftime("%m/%Y"),
                            "forecastAvailable": available, "predictedBalance": income-expense,
                            "cumulativeIncome": cumulative_income, "cumulativeExpense": cumulative_expense,
                            "cumulativeBalance": cumulative_income-cumulative_expense})
                plan = plan_by_date[date_key]
                # Statistics and cash commitments remain distinct; not added twice.
                plan["statisticalForecast"] = {
                    "income": income if available else None, "expense": expense if available else None,
                    "incomeIsAllocation": row["incomeIsAllocation"],
                    "expenseIsAllocation": row["expenseIsAllocation"],
                    "usedAsConfirmedCash": False,
                }
                if plan["conservativeIntradayBalance"] is not None and plan["conservativeIntradayBalance"] < 0:
                    kind, text = "cash_shortfall", "Có nguy cơ thiếu tiền; kiểm tra khoản đến hạn trước khi chi thêm."
                elif plan["committedExpense"] > 0:
                    kind, text = "bill_due", f"Giữ {plan['committedExpense']:,.0f}đ cho khoản chi đã xác nhận."
                elif plan["confirmedIncome"] > 0:
                    kind, text = "income_due", f"Có khoản thu xác nhận {plan['confirmedIncome']:,.0f}đ; chỉ cập nhật số dư khi thực nhận."
                elif safe is not None:
                    kind, text = "daily_plan", f"Mức chi linh hoạt thận trọng trong kế hoạch: tối đa khoảng {safe:,.0f}đ/ngày."
                else:
                    kind, text = "missing_balance", "Cập nhật số dư và lịch hóa đơn để tính mức chi an toàn."
                suggestion = {"date": date_key, "type": kind, "text": text,
                              "dailySafeToSpend": safe, "forecastAvailable": available,
                              "action": {"type": "view_timeline", "label": "Xem kế hoạch ngày",
                                         "payload": {"date": date_key}, "requiresUserConfirmation": False}}
                row["suggestion"] = suggestion
                plan["suggestion"] = suggestion
                suggestions.append(suggestion)
                details.append(row)
                predictions.append(PredictedValue(date=date_key, predicted_income=income,
                                                  predicted_expense=expense, confidence=row["confidence"],
                                                  description=row["description"]))
            breakdown = []
            for yy, mm in periods:
                rows = [r for r in details if r["analysisMonth"] == f"{mm:02d}/{yy}"]
                monthly = reports[(yy, mm)].summary
                inc = sum(r["predictedIncome"] for r in rows)
                exp = sum(r["predictedExpense"] for r in rows)
                breakdown.append({"month": f"{mm:02d}/{yy}", "start": rows[0]["date"],
                                  "end": rows[-1]["date"], "daysInWindow": len(rows),
                                  "forecastInWindow": {"income": inc, "expense": exp, "balance": inc-exp},
                                  "actualSoFar": monthly.get("actualSoFar"),
                                  "expectedFullMonth": monthly.get("expectedMonthEnd"),
                                  "model": monthly.get("model"),
                                  "forecastAvailable": reports[(yy, mm)].success})
            total = {"days": days, "income": cumulative_income, "expense": cumulative_expense,
                     "balance": cumulative_income-cumulative_expense}
            window = {"start": dates[0].strftime("%Y-%m-%d"), "end": dates[-1].strftime("%Y-%m-%d"),
                      "days": days, "crossesMonth": len(periods) > 1 or periods[0] != (today.year, today.month),
                      "crossesYear": dates[0].year != dates[-1].year or dates[-1].year != today.year,
                      "completeDailySeries": True, "startsTomorrow": True}
            # Retain monthly financial insights with an explicit scope; do not
            # relabel the rolling total as an end-of-month balance.
            summary.update({
                "insightVersion": "v12_cross_month", "forecastMode": "rolling",
                "analysisMonth": f"{selected_month:02d}/{selected_year}",
                "monthlyAnalysisScope": f"{selected_month:02d}/{selected_year}",
                "currentDate": today.strftime("%Y-%m-%d"), "dataUntil": today.strftime("%Y-%m-%d"),
                "predictionPeriod": f"{window['start']} - {window['end']}",
                "forecastWindow": window, "dailyForecastPeriod": dict(window),
                "dailyForecastCount": days, "dailyForecastDetail": details,
                "totalPredictedIncome": cumulative_income, "totalPredictedExpense": cumulative_expense,
                "predictedBalance": cumulative_income-cumulative_expense,
                "forecastRemaining": total, "rollingForecast": dict(total),
                "modelConfidence": round(sum(r["confidence"] for r in details)/days, 2),
                "monthlyBreakdown": breakdown, "dailySuggestions": suggestions,
                "personalAdvisor": advisor, "forecastAvailable": all(r["forecastAvailable"] for r in details),
                "balanceMeaning": "net_cash_flow_not_wallet_balance",
                "confidenceMeaning": "heuristic_score_not_accuracy_probability",
                "forecastScopeNote": (
                    "predictions và forecastRemaining thuộc forecastWindow xuyên tháng. "
                    "actualSoFar, expectedMonthEnd, financialAnalysis thuộc monthlyAnalysisScope. "
                    "personalAdvisor.timeline dùng số dư thật và khoản xác nhận; không cộng thu phân bổ vào số dư."),
                "forecastExplanation": {
                    "method": "Tính đầy đủ từng tháng từ cùng lịch sử thật, lấy đúng ngày trong cửa sổ, ghép liên tục và tính lại lũy kế.",
                    "income": "Thu theo ngày là phân bổ tổng thu còn lại của từng tháng; không phải cam kết nhận tiền ngày đó.",
                    "expense": "Giữ mô hình ngắn hạn cho phần tháng hiện tại theo engine; ngày thuộc tháng tương lai dùng phân bổ tổng tháng.",
                    "forecastDays": days, "dailyDetailAvailable": True,
                    "dailyDetailKey": "summary.dailyForecastDetail",
                },
                "warnings": list(dict.fromkeys(warnings_out + advisor["warnings"])),
            })
            if "trend" in summary:
                summary["trend"] = dict(summary["trend"])
                summary["trend"]["recommendation"] = (
                    f"Xem kế hoạch {days} ngày từ {window['start']} đến {window['end']}; "
                    "ưu tiên khoản đến hạn và đề xuất có căn cứ trong personalAdvisor.")
            summary.setdefault("forecastStrategy", {})["windowPolicy"] = "rolling_calendar_days_no_month_cutoff"
            # A useful card exists even without explicit upcoming events. Daily
            # suggestions do not generate a push per day (avoids notification spam).
            plan_id = self._stable_id(user_id, "rolling_plan", window["start"], window["end"])
            if plan_id not in set(map(str, context.get("dismissed_card_ids", []))):
                advisor["actionCards"].append({"id": plan_id, "type": "rolling_plan", "priority": 5,
                    "title": f"Kế hoạch {days} ngày sắp tới",
                    "body": f"Theo dõi liên tục từ {window['start']} đến {window['end']}, không dừng ở cuối tháng.",
                    "dueDate": None,
                    "actions": [{"type": "view_timeline", "label": "Xem các ngày sắp tới",
                                 "payload": {"start": window["start"], "end": window["end"]},
                                 "requiresUserConfirmation": False, "execution": "client_or_authenticated_api"}]})
            return TrendPredictionResponse(
                success=True, user_id=user_id, predictions=predictions, summary=summary,
                message=(f"Dự báo liên tục {days} ngày: {window['start']} đến {window['end']}. "
                         + ("" if clean else "Chưa có lịch sử: số 0 trong dự báo là placeholder, forecastAvailable=False. ")
                         + "Số liệu theo tháng và lịch dòng tiền được tách riêng."))
        except (ValueError, TypeError, KeyError, OverflowError) as exc:
            return TrendPredictionResponse(success=False, user_id=user_id, predictions=[], summary={},
                                           message=f"Dữ liệu đầu vào không hợp lệ: {exc}")


    @staticmethod
    def _normalized_text(value: Any) -> str:
        value = unicodedata.normalize("NFD", str(value).lower().replace("đ", "d"))
        return re.sub(r"\s+", " ", "".join(c for c in value if unicodedata.category(c) != "Mn")).strip()

    def prepare_import_candidates(self, items: List[Dict[str, Any]],
                                  existing_transactions: Optional[List[Any]] = None,
                                  timezone: str = "Asia/Ho_Chi_Minh") -> Dict[str, Any]:
        """Parse already-authorized notification text or OCR TEXT, not image bytes.
        No device access, OCR engine, bank login or automatic ledger write here.
        Input: id, source(bank_notification|wallet_notification|ocr_text), text,
        occurred_at(optional ISO), account_id(optional), direction(optional enum).
        Original text is not echoed/logged (may contain balances/account numbers).
        Notification permission/OCR consent and storage belong to caller.
        Exact source IDs should be persisted with imported transactions as import_id.
        Soft matches are review flags, never silently discard legitimate transactions.
        """
        if not isinstance(items, list) or not all(isinstance(x, dict) for x in items):
            raise ValueError("import_items phải là danh sách object.")
        ZoneInfo(timezone)
        candidates, seen = [], set()
        existing = existing_transactions or []
        imported_ids = {str(self._field(t, "import_id", default="")) for t in existing}
        for item in items:
            source = item.get("source")
            sid = str(item.get("id", "")).strip()
            if source not in ("bank_notification", "wallet_notification", "ocr_text") or not sid:
                raise ValueError("Import cần id ổn định và source hợp lệ.")
            account = str(item.get("account_id", ""))
            key = self._stable_id(source, account, sid)
            if key in seen:
                continue
            seen.add(key)
            txt = self._normalized_text(item.get("text", ""))
            direction = item.get("direction")
            if direction not in (None, "income", "expense", "transfer"):
                raise ValueError("direction phải là income, expense hoặc transfer.")
            debit = bool(re.search(r"ghi no|thanh toan|chi tieu|tru tien|\bdebit\b", txt))
            credit = bool(re.search(r"ghi co|nhan tien|cong tien|\bcredit\b", txt))
            if direction is None and debit != credit:
                direction = "expense" if debit else "income"
            values = []
            # Only amounts attached to transaction labels, never the available balance.
            amount_pattern = r"([0-9][0-9.,]*(?:\s[0-9]{3})*)\s*(?:vnd|vnđ|dong|đ)\b"
            label = (r"(?:tong thanh toan|tong cong|grand total|total)\s*[:=]?\s*" if source == "ocr_text"
                     else r"(?:ghi no|ghi co|thanh toan|nhan tien|tru tien|cong tien|debit|credit|so tien(?: giao dich)?)\s*[:=]?\s*[+-]?\s*")
            for match in re.finditer(label + amount_pattern, txt):
                raw = match.group(1).replace(" ", "")
                # VND whole amounts only; avoid interpreting 12.50 as 1,250.
                if re.fullmatch(r"\d+|\d{1,3}(?:[.,]\d{3})+", raw):
                    amount = int(raw.replace(",", "").replace(".", ""))
                    if amount > 0:
                        values.append(amount)
            amounts = sorted(set(values))
            amount = amounts[0] if len(amounts) == 1 else None
            if source == "ocr_text" and direction is None:
                direction = "expense"  # receipt candidate only; user confirms it was paid
            day = None
            if item.get("occurred_at") is not None:
                day = self._local_day(item["occurred_at"], timezone).strftime("%Y-%m-%d")
            possible_duplicate = False
            if amount is not None and day and direction in ("income", "expense"):
                for tx in existing:
                    try:
                        tx_day = self._local_day(self._field(tx, "date_time", "dateTime", "date"), timezone).strftime("%Y-%m-%d")
                        money = self._number(self._field(tx, "money", "amount"), "money", True)
                        tx_kind = "expense" if self._field(tx, "is_expense", "isExpense") is True else (
                            "income" if self._field(tx, "is_income", "isIncome") is True else "expense" if money < 0 else "income")
                        if tx_day == day and abs(money) == amount and tx_kind == direction:
                            possible_duplicate = True
                    except (ValueError, TypeError):
                        continue
            missing = [name for name, value in (("amount", amount), ("date", day), ("direction", direction)) if value is None]
            candidates.append({"importId": key, "sourceId": sid, "source": source,
                               "amount": amount, "currency": "VND", "direction": direction, "date": day,
                               "status": "already_imported" if key in imported_ids else "needs_review",
                               "missingFields": missing, "possibleDuplicate": possible_duplicate,
                               "ambiguousAmount": len(amounts) > 1, "requiresUserConfirmation": True,
                               "ledgerWritten": False})
        return {"candidates": candidates, "writesPerformed": 0,
                "capability": "parse_notification_or_ocr_text_only",
                "note": "Thiếu/không rõ số tiền hoặc ngày phải xác nhận; chuyển khoản nội bộ không tính thành thu nhập."}

    def summarize_net_worth(self, assets: List[Dict[str, Any]], liabilities: List[Dict[str, Any]],
                            reference_date: Any, timezone: str = "Asia/Ho_Chi_Minh") -> Dict[str, Any]:
        """Snapshot only. VND valuations supplied by caller, no live market prices.
        Each holding exactly once. Do not pass both an account total and positions
        inside it. parent_id links children to a parent; overlapping input is rejected.
        Real estate/stock values do not become available cash automatically.
        Assets: id, type(cash|savings|stocks|real_estate|other), value, valued_at.
        Liabilities: id, outstanding, valued_at. Currency defaults VND.
        """
        today = self._local_day(reference_date, timezone)
        if not all(isinstance(v, list) and all(isinstance(x, dict) for x in v) for v in (assets, liabilities)):
            raise ValueError("assets/liabilities phải là danh sách object.")
        ids = [str(x.get("id", "")).strip() for x in assets+liabilities]
        if any(not x for x in ids) or len(ids) != len(set(ids)):
            raise ValueError("Mỗi tài sản/khoản nợ cần id duy nhất.")
        if any(str(x.get("parent_id", "")) in set(ids) for x in assets):
            raise ValueError("Không cộng đồng thời tổng tài khoản và tài sản con; chỉ gửi một cấp.")
        asset_rows, debt_rows, warnings_out = [], [], []
        totals = {key: 0.0 for key in ("cash", "savings", "stocks", "real_estate", "other")}
        for source, is_debt in ((assets, False), (liabilities, True)):
            for x in source:
                if x.get("currency", "VND") != "VND":
                    raise ValueError("Cần quy đổi tài sản/nợ về VND trước khi tổng hợp.")
                value = self._number(x.get("outstanding") if is_debt else x.get("value"), "valuation")
                valued = self._local_day(x.get("valued_at"), timezone)
                if valued > today:
                    raise ValueError("Ngày định giá không được nằm trong tương lai.")
                kind = "debt" if is_debt else x.get("type")
                if not is_debt and kind not in totals:
                    raise ValueError("Loại tài sản không hợp lệ.")
                age = (today-valued).days
                stale_after = 7 if kind == "stocks" else 180 if kind == "real_estate" else 30
                stale = age > stale_after
                row = {"id": str(x["id"]), "type": kind, "value": round(value),
                       "valuedAt": valued.strftime("%Y-%m-%d"), "valuationAgeDays": age, "stale": stale}
                if stale:
                    warnings_out.append(f"Định giá {x['id']} đã cũ ({age} ngày).")
                if is_debt:
                    debt_rows.append(row)
                else:
                    totals[kind] += value
                    asset_rows.append(row)
        total_assets = sum(totals.values())
        total_debt = sum(x["value"] for x in debt_rows)
        available = bool(asset_rows or debt_rows)
        return {"currency": "VND", "asOf": today.strftime("%Y-%m-%d"),
                "totalAssets": round(total_assets) if available else None,
                "totalLiabilities": round(total_debt) if available else None,
                "netWorth": round(total_assets-total_debt) if available else None,
                "assetsByType": {k:round(v) for k,v in totals.items()}, "assets": asset_rows,
                "liabilities": debt_rows, "warnings": warnings_out,
                "status": "provided_holdings_only" if available else "missing_data",
                "usedForSafeToSpend": False,
                "note": "Chỉ tổng hợp tài sản đã cung cấp; số dư khả dụng được truyền riêng, không cộng thêm lần nữa."}

    def _balanced_trend(self, clean: List[Any], today: pd.Timestamp,
                        complete_history: bool, advisor: Dict[str, Any]) -> Dict[str, Any]:
        """Describe recorded transactions in two completed local 7-day windows.
        No inference that missing days mean zero real-world spending.
        history_complete is metadata, not a gate on observed comparisons.
        """
        today = pd.Timestamp(today).normalize()
        start = today - timedelta(days=7)
        prior_start = today - timedelta(days=14)
        recent, previous = [], []
        for item in clean:
            date = pd.Timestamp(item.date_time)
            if date.tzinfo is not None:
                date = date.tz_convert(advisor.get("timezone", "Asia/Ho_Chi_Minh"))
                date = date.tz_localize(None)
            if start <= date < today:
                recent.append(item)
            elif prior_start <= date < start:
                previous.append(item)

        def totals(rows):
            income = sum(abs(t.money) for t in rows if t.is_income)
            expense = sum(abs(t.money) for t in rows if t.is_expense)
            return {"income": round(income), "expense": round(expense),
                    "netCashFlow": round(income-expense),
                    "transactionCount": len(rows),
                    "expenseTransactionCount": sum(bool(t.is_expense) for t in rows),
                    "activeDays": len({pd.Timestamp(t.date_time).date() for t in rows})}

        a, b = totals(recent), totals(previous)
        comparable = bool(recent) and bool(previous)
        change = ((a["expense"]-b["expense"])/b["expense"]*100
                  if comparable and b["expense"] > 0 else None)
        reasons, positives, attention = [], [], []
        if not recent:
            reasons.append("Không có giao dịch được ghi nhận trong 7 ngày gần nhất đã kết thúc.")
        if not previous:
            reasons.append("Không có giao dịch được ghi nhận trong 7 ngày trước đó.")
        if comparable and b["expense"] == 0:
            reasons.append("Kỳ trước không có khoản chi được ghi nhận nên không tính tỷ lệ thay đổi.")
        if comparable:
            if change is None:
                status = "no_expense_baseline"
                headline = (f"Chi ghi nhận kỳ gần đây là {a['expense']:,.0f}đ; "
                            "kỳ trước không ghi nhận khoản chi để tính tỷ lệ tăng/giảm.")
            elif change < 0:
                status = "recorded_decrease"
                headline = f"Chi tiêu ghi nhận giảm {abs(change):.1f}% so với 7 ngày trước."
            elif change > 0:
                status = "recorded_increase"
                headline = f"Chi tiêu ghi nhận tăng {change:.1f}% so với 7 ngày trước."
            else:
                status = "recorded_stable"
                headline = "Tổng chi tiêu ghi nhận bằng với 7 ngày trước."
            if change is not None and change <= -5:
                positives.append({
                    "text": f"Tổng chi ghi nhận giảm {b['expense']-a['expense']:,.0f}đ.",
                    "basis": "observed_expense_change",
                    "doesNotImply": "Chưa thể kết luận đã tiết kiệm hơn; khoản chi có thể được ghi nhận hoặc thanh toán khác kỳ."
                })
            if a["netCashFlow"] > 0:
                positives.append({
                    "text": f"Thu trừ chi ghi nhận trong kỳ là {a['netCashFlow']:,.0f}đ.",
                    "basis": "observed_net_cash_flow",
                    "doesNotImply": "Chênh lệch này không phải số dư ví hoặc tiền tiết kiệm."
                })
            if change is not None and change >= 20:
                attention.append({
                    "type": "spending_change",
                    "text": f"Chi ghi nhận tăng {change:.1f}%; xem các khoản lớn và thời điểm thanh toán trước khi điều chỉnh chi tiêu."
                })
        else:
            status = "insufficient_comparison"
            headline = "Chưa có giao dịch ở cả hai kỳ để so sánh xu hướng."
        if advisor.get("firstShortfallDate"):
            attention.append({
                "type": "cash_shortfall",
                "text": f"Theo các giả định dự báo hiện tại, có nguy cơ thiếu tiền vào {advisor['firstShortfallDate']}."
            })
        return {
            "status": status, "headline": headline,
            "positiveSignals": positives, "attentionPoints": attention,
            "comparisonType": "last_7_completed_days_vs_previous_7_completed_days",
            "currentPeriod": {"start": str(start.date()),
                              "end": str((today-timedelta(days=1)).date()), **a},
            "previousPeriod": {"start": str(prior_start.date()),
                               "end": str((start-timedelta(days=1)).date()), **b},
            "expenseChangePercent": round(change, 1) if change is not None else None,
            "historyConfirmedComplete": complete_history,
            "conclusionsSupported": comparable,
            "comparisonAvailable": comparable,
            "comparisonReasons": reasons,
            "analysisScope": "recorded_transactions_only",
            "note": "So sánh các giao dịch đã ghi nhận; không coi ngày chưa có giao dịch là ngày không chi tiêu. Không tính hôm nay vì ngày chưa kết thúc.",
        }

    def _category_recommendations(self, clean: List[Any], dates: List[str],
                                  context: Dict[str, Any], advisor: Dict[str, Any],
                                  today: pd.Timestamp) -> List[Dict[str, Any]]:
        """V14: observed facts -> dated, conditional action. Never invent a category.
        category_labels maps IDs to labels; type_name/typeName are also supported.
        A budget warning is scheduled once in the matching month; spending trends
        require complete history. Habit advice needs >=3 matching weekday samples.
        Only near-term habits (next 7 days) are used; future events keep exact dates.
        """
        labels = context.get("category_labels", {})
        policies = context.get("category_policies", {})
        if not isinstance(labels, dict) or not isinstance(policies, dict):
            raise ValueError("category_labels và category_policies phải là object.")
        normalize = lambda v: self._normalized_text(v).replace("_", " ")
        label_map = {str(k): str(v).strip() for k,v in labels.items()}
        policy_map = {normalize(k): v for k,v in policies.items()}
        aliases = {
            "coffee": ("Cà phê, đồ uống", "coffee"), "ca phe": ("Cà phê, đồ uống", "coffee"),
            "eating": ("Ăn uống", "food"), "move": ("Đi lại", "transport"),
            "fun play": ("Giải trí", "entertainment"), "rent house": ("Tiền nhà", "essential"),
            "physical examination": ("Y tế", "essential"),
            "electricity bill": ("Tiền điện", "essential"),
            "food": ("Ăn uống", "food"), "an uong": ("Ăn uống", "food"),
            "eating out": ("Ăn ngoài", "food"), "an ngoai": ("Ăn ngoài", "food"),
            "shopping": ("Mua sắm", "shopping"), "mua sam": ("Mua sắm", "shopping"),
            "entertainment": ("Giải trí", "entertainment"), "giai tri": ("Giải trí", "entertainment"),
            "transport": ("Đi lại", "transport"), "di lai": ("Đi lại", "transport"),
            "rent": ("Tiền nhà", "essential"), "tien nha": ("Tiền nhà", "essential"),
            "health": ("Y tế", "essential"), "y te": ("Y tế", "essential"),
            "education": ("Học tập", "essential"), "hoc tap": ("Học tập", "essential"),
        }
        def identity(raw, cid=""):
            label = label_map.get(str(cid)) or label_map.get(str(raw)) or str(raw).strip()
            if not label or re.fullmatch(r"[+-]?\d+(?:\.0+)?", label):
                return None
            return normalize(label)
        buckets = {}
        for tx in clean:
            if not tx.is_expense:
                continue
            cid = getattr(tx, "category_id", "")
            key = identity(tx.category, cid)
            if key is None:
                continue
            b = buckets.setdefault(key, {"label": label_map.get(cid) or label_map.get(tx.category) or tx.category,
                                         "ids": set(), "transactions": []})
            b["ids"].add(cid)
            b["transactions"].append(tx)
        timeline = {r["date"]:r for r in advisor.get("timeline", [])}
        output = []
        emitted = set()
        advised_categories = set()
        complete = context.get("history_complete") is True
        history_start = min((t.date_time for t in clean), default=today)
        history_last = max((t.date_time for t in clean), default=today-timedelta(days=999))
        for date_key in dates:
            day = pd.Timestamp(date_key)
            if day <= today:
                output.append({"date":date_key,"recommendations":[],"status":"historical_no_action"})
                continue
            candidates = []
            def add(kind, category_key, title, reason, suggestion, priority, evidence, label=None):
                token = (kind, category_key)
                if token in emitted:
                    return
                candidates.append({"id":self._stable_id("v14",date_key,kind,category_key),
                    "date":date_key,"type":kind,"category":label,
                    "title":title,"reason":reason,"suggestion":suggestion,
                    "priority":priority,"evidence":evidence,"amountIsSpendingTarget":False,
                    "action":{}, "_token":token})
            plan = timeline.get(date_key,{})
            # Only actual confirmed commitments create payment advice.
            for event in plan.get("events",[]):
                if event.get("confirmed") is not True or event.get("kind") != "expense":
                    continue
                amount = float(event["amount"])
                add("scheduled_payment",event["id"],f"Ưu tiên khoản {event['title']}",
                    f"Khoản đã xác nhận {amount:,.0f}đ, đến hạn {event['dueDate']}.",
                    "Kiểm tra đã thanh toán chưa; nếu chưa, dành tiền cho khoản này trước khi mua sắm thêm.",
                    1,{"source":"confirmed_event","eventId":event["id"],"amount":round(amount),"dueDate":event["dueDate"]})
            for key,bucket in buckets.items():
                raw_label=bucket["label"]
                default_label, default_kind=aliases.get(key,(raw_label,"unknown"))
                policy=policy_map.get(key,{})
                for cid in bucket["ids"]:
                    if cid and normalize(cid) in policy_map:
                        policy=policy_map[normalize(cid)]
                if not isinstance(policy,dict):
                    raise ValueError("Mỗi category_policy phải là object.")
                label=str(policy.get("label") or default_label)
                kind=str(policy.get("advice_type") or default_kind)
                essential=policy.get("essential") is True or default_kind=="essential"
                txs=bucket["transactions"]
                end=today-timedelta(days=1)
                recent_start=end-timedelta(days=27)
                daily={}
                for t in txs:
                    if recent_start<=t.date_time<=end:
                        daily[t.date_time]=daily.get(t.date_time,0)+abs(t.money)
                evidence={"source":"recorded_transactions","asOf":str(today.date()),
                          "category":label,"historyStart":str(recent_start.date()),"historyEnd":str(end.date()),
                          "transactionCount":sum(1 for t in txs if recent_start<=t.date_time<=end),
                          "spendingDays":len(daily)}
                # Match budget by stable category ID OR normalized label, never budget document ID.
                relevant=[]
                for budget in context.get("budgets",[]):
                    if budget.get("isActive",True) is False:
                        continue
                    by_id=str(budget.get("type",budget.get("category_id","")))
                    by_label=identity(budget.get("category",budget.get("typeName",budget.get("type_name",""))),by_id)
                    match=(by_id and by_id in bucket["ids"]) or by_label==key
                    if match and int(budget.get("year",today.year))==day.year and int(budget.get("month",today.month))==day.month:
                        relevant.append(budget)
                if len(relevant)==1 and (day.year,day.month)==(today.year,today.month):
                    budget=relevant[0]
                    limit=self._number(budget.get("limit",budget.get("limitMoney")),"budget.limit")
                    actual=sum(abs(t.money) for t in txs if (t.date_time.year,t.date_time.month)==(day.year,day.month))
                    spent=self._number(budget["spent"],"budget.spent") if budget.get("spent") is not None else actual
                    if budget.get("spent") is not None or complete:
                        remaining=max(limit-spent,0)
                        elapsed=today.day
                        month_days=calendar.monthrange(today.year,today.month)[1]
                        pressure=spent>limit or (limit>0 and spent>=limit*.85 and elapsed/month_days<.85)
                        if pressure:
                            over=max(spent-limit,0)
                            title=(f"{label}: đã vượt ngân sách" if over else f"{label}: ngân sách đang dùng nhanh")
                            reason=f"Tháng {day.month:02d}/{day.year} đã ghi nhận {spent:,.0f}đ / {limit:,.0f}đ; còn {remaining:,.0f}đ."
                            instruction=("Giữ các khoản thiết yếu; xem lại khoản có thể dời lịch hoặc điều chỉnh ngân sách theo nhu cầu thực tế."
                                if essential else "Hoãn khoản chưa cần thiết trong danh mục này; kiểm tra phần ngân sách còn lại trước khi mua thêm.")
                            add("budget_pressure",key+str(day.to_period('M')),title,reason,instruction,2,
                                {**evidence,"source":"budget_and_actuals","budgetId":str(budget["id"]),"limit":round(limit),
                                 "spent":round(spent),"remaining":round(remaining),"overBudget":round(over),
                                 "elapsedDays":elapsed,"daysInMonth":month_days},label)
                # Compare two complete equal windows; only assert increase with reliable input.
                last7={d:v for d,v in daily.items() if end-timedelta(days=6)<=d<=end}
                prev7={d:v for d,v in daily.items() if end-timedelta(days=13)<=d<end-timedelta(days=6)}
                a,b=sum(last7.values()),sum(prev7.values())
                if complete and history_start<=end-timedelta(days=13) and (today-history_last).days<=3 and len(last7)>=2 and len(prev7)>=2 and b>0 and a>=b*1.25 and a-b>=50000 and day<=today+timedelta(days=7):
                    increase=(a-b)/b*100
                    instruction=("Đối chiếu các khoản phát sinh mới với nhu cầu thực tế; không cắt khoản thiết yếu chỉ vì tổng chi tăng."
                        if essential else "Kiểm tra các lần mua phát sinh thêm; thử hoãn một khoản không cần thiết trước khi mua tiếp.")
                    add("category_increase",key,f"Kiểm tra khoản tăng ở {label}",
                        f"7 ngày đã kết thúc chi {a:,.0f}đ, so với {b:,.0f}đ trong 7 ngày trước (+{increase:.0f}%).",
                        instruction,3,{**evidence,"current7Days":round(a),"previous7Days":round(b),
                            "increasePercent":round(increase,1),"comparisonStart":str((end-timedelta(days=13)).date())},label)
                # Habit alone is not overspending. Give preparation advice, no demand to spend/cut.
                weekday_values=[v for d,v in daily.items() if d.weekday()==day.weekday()]
                if day<=today+timedelta(days=7) and len(daily)>=6 and len(weekday_values)>=3 and (today-history_last).days<=7:
                    steps={
                        "coffee":"Nếu hôm nay vẫn mua đồ uống, chọn một lần mua theo nhu cầu; có thể mang đồ uống từ nhà nếu thuận tiện.",
                        "food":"Nếu có kế hoạch ăn ngoài hôm nay, chọn trước bữa ăn phù hợp; tự chuẩn bị một bữa nếu thuận tiện.",
                        "shopping":"Nếu định mua sắm hôm nay, lập danh sách món cần mua; để món chưa cần thiết sang ngày khác.",
                        "entertainment":"Nếu có lịch giải trí hôm nay, chọn trước hoạt động và kiểm tra ngân sách còn lại.",
                        "transport":"Nếu cần đi lại hôm nay, gộp các việc cùng tuyến khi thuận tiện; ưu tiên nhu cầu đi lại thiết yếu.",
                    }
                    if not essential and kind in steps:
                        typical=round(float(np.median(weekday_values)))
                        add("weekday_preparation",key,f"Chuẩn bị trước cho {label}",
                            f"Trong 28 ngày đã có {len(weekday_values)} ngày cùng thứ chi {label}; trung vị {typical:,.0f}đ mỗi ngày có phát sinh.",
                            steps[kind],4,{**evidence,"sameWeekdaySamples":len(weekday_values),"medianActiveDayAmount":typical},label)
            candidates.sort(key=lambda r:(r['priority'],r['title']))
            chosen=[]
            categories=set()
            for candidate in candidates:
                cat=candidate.get("category")
                if cat and (cat in categories or cat in advised_categories):
                    continue
                if len(chosen)>=2:
                    break
                categories.add(cat)
                if cat:
                    advised_categories.add(cat)
                emitted.add(candidate.pop("_token"))
                chosen.append(candidate)
            output.append({"date":date_key,"recommendations":chosen,
                           "status":"grounded" if chosen else "no_new_evidence",
                           "note":"Không tạo gợi ý mới khi chưa có căn cứ hoặc nội dung đã được nhắc trong kế hoạch."})
        return output

    def _predict_with_advice(self, user_id: str, transactions: List[Any],
                      prediction_days: Optional[int] = None, year: Optional[int] = None,
                      month: Optional[int] = None, *,
                      advisor_context: Optional[Dict[str, Any]] = None,
                      forecast_mode: str = "rolling") -> TrendPredictionResponse:
        """V13 additive summary: trendAnalysis, spendingRecommendations, importReview,
        netWorth. Extra context: history_complete (explicit True only), import_items,
        assets, liabilities, category_policies. See module documentation for schemas.
        Import candidates NEVER enter forecasts until confirmed in the real ledger.
        """
        try:
            c=dict(advisor_context or {})
            if not isinstance(c.get('budgets',[]),list) or not all(isinstance(b,dict) for b in c.get('budgets',[])):
                raise ValueError('budgets phải là danh sách object')
            budgets=[]
            for original in c.get('budgets',[]):
                b=dict(original)
                bid=b.get('type',b.get('category_id',''))
                label=b.get('category',b.get('typeName',b.get('type_name',str(bid))))
                b.setdefault('category',label)
                b.setdefault('id',self._stable_id('budget',b.get('year'),b.get('month'),bid,label))
                budgets.append(b)
            c['budgets']=budgets
            c['_recommendation_budgets']=copy.deepcopy(budgets)
            if not isinstance(c.get("category_labels", {}), dict):
                raise ValueError("category_labels phải là object.")
            # Firestore budget items often omit spent: derive only when the caller
            # explicitly confirms a complete transaction history; never assume 0.
            budget_warnings = []
            if c.get("budgets"):
                timezone = str(c.get("timezone", "Asia/Ho_Chi_Minh"))
                ref = self._local_day(c.get("reference_date") or datetime.now(ZoneInfo(timezone)), timezone)
                normalized_txs, _ = self._advisor_transactions(transactions, timezone, ref)
                normalized_budgets = []
                for original in c["budgets"]:
                    budget = dict(original)
                    if budget.get("isActive", True) is False:
                        continue
                    if budget.get("spent") is None:
                        if c.get("history_complete") is not True:
                            budget_warnings.append("Có ngân sách chưa có số đã chi; chưa dùng để kết luận vượt hạn mức.")
                            continue
                        bid = str(budget.get("type", budget.get("category_id", "")))
                        name = self._normalized_text(budget.get("category", budget.get("typeName", budget.get("type_name", ""))))
                        yy, mm = int(budget.get("year", ref.year)), int(budget.get("month", ref.month))
                        if (yy, mm) > (ref.year, ref.month):
                            budget["spent"] = 0.0
                        else:
                            budget["spent"] = sum(abs(t.money) for t in normalized_txs if t.is_expense
                                and (t.date_time.year, t.date_time.month)==(yy, mm)
                                and ((bid and t.category_id==bid) or (name and self._normalized_text(t.category)==name)))
                    normalized_budgets.append(budget)
                c["budgets"] = normalized_budgets
            response=self._predict_v12(user_id,transactions,prediction_days,year,month,
                                       advisor_context=c,forecast_mode=forecast_mode)
            if not response.success:
                return response
            summary=response.summary
            summary.setdefault("warnings", []).extend(budget_warnings)
            advisor=summary["personalAdvisor"]
            today=self._local_day(advisor["asOf"],advisor["timezone"])
            clean,_=self._advisor_transactions(transactions,advisor["timezone"],today)
            unresolved = sorted({t.category for t in clean if t.is_expense
                and re.fullmatch(r"[+-]?\d+(?:\.0+)?", t.category)
                and not c.get("category_labels", {}).get(t.category)
                and not c.get("category_labels", {}).get(getattr(t, "category_id", ""))})
            if unresolved:
                summary.setdefault("warnings", []).append(
                    "Một số giao dịch chỉ có mã danh mục; chưa đủ tên danh mục để đưa ra gợi ý cụ thể.")
            summary["categoryResolution"] = {"unresolvedIds": unresolved,
                "requiredFields": "type_name/typeName hoặc advisor_context.category_labels"}
            balanced=self._balanced_trend(clean,today,c.get("history_complete") is True,advisor)
            detail=summary.get("dailyForecastDetail",[])
            advice=self._category_recommendations(clean,[d["date"] for d in detail],c,advisor,today)
            by_date={x["date"]:x for x in advice}
            for row in detail:
                row["spendingRecommendations"]=by_date[row["date"]]["recommendations"]
            for row in advisor["timeline"]:
                row["spendingRecommendations"]=by_date.get(row["date"],{}).get("recommendations",[])
            # Remove obsolete daily-allowance UI text and duplicated generic cards.
            advisor["actionCards"] = [x for x in advisor.get("actionCards", [])
                if x.get("type") not in ("missing_balance", "reduce_spending", "budget_pressure")]
            advisor.pop("dailySafeToSpend", None)
            advisor["warnings"] = [w for w in advisor.get("warnings", [])
                if "available_balance" not in w and "mức chi an toàn" not in w]
            summary["warnings"] = [w for w in summary.get("warnings", [])
                if "available_balance" not in w and "mức chi an toàn" not in w]
            # Keep dailySuggestions legacy object shape; enrich with concrete actions.
            for row in summary.get("dailySuggestions",[]):
                recs=by_date.get(row["date"],{}).get("recommendations",[])
                row["recommendations"]=recs
                row.pop("dailySafeToSpend", None)
                if row.get("type") in ("daily_plan", "missing_balance", "reduce_spending"):
                    row["type"] = "category_advice" if recs else "no_new_evidence"
                    row["text"] = recs[0]["suggestion"] if recs else ""
                    row["action"] = {}
            for row in detail + advisor.get("timeline", []):
                date_key = row["date"]
                suggestion = next((x for x in summary.get("dailySuggestions", []) if x["date"] == date_key), None)
                if suggestion is not None:
                    row["suggestion"] = suggestion
                else:
                    row.pop("suggestion", None)
            for day in advice[:7]:
                for rec in day["recommendations"]:
                    if rec["id"] in set(map(str,c.get("dismissed_card_ids",[]))):
                        continue
                    advisor["actionCards"].append({"id":rec["id"],"type":"category_advice",
                        "title":rec["title"],"body":rec["suggestion"],"reason":rec["reason"],
                        "priority":rec["priority"]+2,"dueDate":rec["date"],"actions":[], "evidence":rec["evidence"]})
            advisor["actionCards"].sort(key=lambda x:(x["priority"],x.get("dueDate") or "",x["id"]))
            summary.update({"insightVersion":"v14_evidence_based_advice", "trendAnalysis":balanced,
                            "spendingRecommendations":advice,
                            "importReview":self.prepare_import_candidates(c.get("import_items",[]),transactions,advisor["timezone"]),
                            "netWorth":self.summarize_net_worth(c.get("assets",[]),c.get("liabilities",[]),today,advisor["timezone"])})
            # Change old UI text too: do not leave an unqualified pessimistic legacy headline.
            summary.setdefault("trend",{})["recommendation"]=balanced["headline"]
            summary["trend"]["expenseTrend"]=(
                f"Chi ghi nhận trong 7 ngày đã kết thúc: {balanced['currentPeriod']['expense']:,.0f}đ; "
                f"7 ngày trước: {balanced['previousPeriod']['expense']:,.0f}đ. "
                + ("" if balanced["conclusionsSupported"] else "Chưa có giao dịch ở cả hai kỳ để so sánh."))
            summary["trend"]["incomeTrend"]="Thu nhập cần xem theo kỳ nhận tiền; không kết luận tăng/giảm chỉ từ lịch trả lương giữa hai tuần."
            financial=summary.get("financialAnalysis")
            if financial is not None:
                financial["interpretation"]=balanced["headline"]
                if not balanced["conclusionsSupported"] and not advisor.get("firstShortfallDate"):
                    financial["risk"]={"level":"unknown","reason":"Dữ liệu có thể chưa đầy đủ; chưa đủ cơ sở kết luận rủi ro thấp hay cao."}
            self._integrate_smart_recommendations(user_id,transactions,c,response,today,year,month)
            return response
        except (ValueError,TypeError,KeyError,OverflowError) as exc:
            return TrendPredictionResponse(success=False,user_id=user_id,predictions=[],summary={},
                                           message=f"Dữ liệu đầu vào không hợp lệ: {exc}")


    def predict_trend(self, user_id: str, transactions: List[Any],
                      prediction_days: Optional[int] = None, year: Optional[int] = None,
                      month: Optional[int] = None, *,
                      advisor_context: Optional[Dict[str, Any]] = None,
                      forecast_mode: str = 'rolling') -> TrendPredictionResponse:
        context = dict(advisor_context or {})
        enabled = context.get('use_lstm', True)
        if not isinstance(enabled,bool):
            return TrendPredictionResponse(success=False,user_id=user_id,predictions=[],summary={},
                                           message='use_lstm phải là boolean')
        token = _LSTM_ENABLED.set(enabled)
        try:
            return self._predict_with_advice(user_id,transactions,prediction_days,year,month,
                                            advisor_context=context,forecast_mode=forecast_mode)
        finally:
            _LSTM_ENABLED.reset(token)

    def _integrate_smart_recommendations(self,user_id,transactions,context,response,today,year,month):
        """Fuse observed clusters/anomalies, supplied budgets and actual forecast output.
        New fields are additive. Legacy trend.recommendation also gets readable advice.
        No database writes, no automatic budget updates or push notifications.
        """
        summary=response.summary
        yy,mm=(int(year),int(month)) if year is not None and month is not None else (today.year,today.month)
        normalized,diagnostics=_normalize_transactions(transactions,today)
        month_txs=[t for t in normalized if (t.date_time.year,t.date_time.month)==(yy,mm) and t.money<0]
        cluster=KMeansService().cluster_spending(user_id,normalized,year=yy,month=mm,reference_date=today)
        anomaly=IsolationForestService().detect_anomalies(user_id,normalized,year=yy,month=mm,reference_date=today)
        complete=context.get('history_complete') is True
        feedback=context.get('recommendation_feedback',{})
        if not isinstance(feedback,dict):
            raise ValueError('recommendation_feedback phải là object id -> trạng thái')
        dismissed=set(map(str,context.get('dismissed_card_ids',[])))
        candidates=[]
        def add(kind,key,title,reason,suggestion,priority,sources,evidence,category=None):
            rid=self._stable_id(user_id,'smart_v15',f'{yy}-{mm}',kind,key)
            status=feedback.get(rid)
            if rid in dismissed or status in ('not_relevant','done','planned'):
                return
            candidates.append({'id':rid,'type':kind,'title':title,'reason':reason,
                'suggestion':suggestion,'priority':priority,'sources':sources,'evidence':evidence,
                'category':category,'analysisMonth':f'{mm:02d}/{yy}',
                'feedback':status,'requiresUserConfirmation':True})
        by_id={t.id:t for t in month_txs}
        for a in anomaly.anomalies[:5]:
            tx=by_id.get(a.transaction_id)
            if tx is not None and tx.planned:
                continue
            add('review_anomaly',a.transaction_id,'Kiểm tra khoản chi khác thường',a.anomaly_reason,
                f'Đối chiếu khoản {abs(a.money):,.0f}đ ở {a.type_name}: kiểm tra số tiền và giao dịch trùng; '
                'nếu đã có kế hoạch, hãy đối chiếu với kế hoạch của bạn trước khi điều chỉnh.',
                1 if a.severity=='high' else 3,['isolation_forest','business_rules'],
                {'transactionId':a.transaction_id,'amount':abs(a.money),'severity':a.severity,
                 'score':a.anomaly_score,'scoreMeaning':'relative_not_probability'},a.type_name)
        budget_rows=[]
        seen_budgets=set()
        for b in context.get('_recommendation_budgets',context.get('budgets',[])):
            if b.get('isActive',True) is False or (int(b.get('year',today.year)),int(b.get('month',today.month)))!=(yy,mm):
                continue
            cid=str(b.get('type',b.get('category_id','')))
            label=str(b.get('category',b.get('typeName',b.get('type_name',cid))))
            key=_category_key(label)
            identity=cid or key
            if identity in seen_budgets:
                raise ValueError('Trùng ngân sách tháng/danh mục; hãy gửi một ngân sách đang hoạt động')
            seen_budgets.add(identity)
            limit=self._number(b.get('limit',b.get('limitMoney')),'budget.limit')
            matching=[t for t in month_txs if (cid and str(t.type)==cid) or (not cid and _category_key(t.type_name)==key)]
            observed=sum(abs(t.money) for t in matching)
            known=b.get('spent') is not None or complete
            spent=self._number(b['spent'],'budget.spent') if b.get('spent') is not None else observed
            remaining=max(limit-spent,0)
            # Projection is transparent arithmetic, not a per-category LSTM forecast.
            current=(yy,mm)==(today.year,today.month)
            endday=calendar.monthrange(yy,mm)[1]
            projection=spent/today.day*endday if known and current and today.day>=7 else None
            ev={'budgetId':str(b.get('id','')),'limit':limit,'spent':spent,'remaining':remaining,
                'actualComplete':known,'projection':round(projection) if projection is not None else None,
                'projectionMethod':'elapsed_day_rate_not_lstm','month':f'{mm:02d}/{yy}'}
            budget_rows.append(ev)
            essential=key in {'rent_house','education','physical_examination','insurance','electricity_bill','water_money','move'}
            action=('Giữ các khoản thiết yếu; rà soát phát sinh và điều chỉnh hạn mức nếu nhu cầu thực tế thay đổi.' if essential else
                    'Xem lại khoản chưa cần thiết trong danh mục này; cân nhắc hoãn trước khi chi thêm.')
            if spent>limit:
                add('budget_exceeded',identity,f'{label}: đã vượt ngân sách',
                    f'Đã ghi nhận {spent:,.0f}đ trên hạn mức {limit:,.0f}đ; vượt {spent-limit:,.0f}đ.',
                    action,2,['budget','recorded_transactions'],ev,label)
            elif projection is not None and projection>limit*1.1 and today.day<endday:
                perday=remaining/(endday-today.day)
                add('budget_pace',identity,f'{label}: cần theo dõi nhịp chi',
                    f'Nếu giữ mức chi trung bình hiện tại, tổng tháng khoảng {projection:,.0f}đ; '
                    f'hạn mức {limit:,.0f}đ. Đây là ngoại suy theo ngày, không phải dự báo LSTM theo danh mục.',
                    action+f' Ngân sách còn lại tương đương {perday:,.0f}đ/ngày; đây là mức tham khảo, không phải số tiền phải chi.',
                    3,['budget','recorded_transactions'],ev,label)
        # Cluster-dependent suggestions genuinely use learned memberships.
        for c in cluster.clusters[:2]:
            stats=c.characteristics
            names=', '.join(list(stats.get('topCategories',{}))[:2])
            ids=sorted(c.transaction_ids)
            add('behavior_review',self._stable_id(*ids),f'Rà soát nhóm {names}',
                f'K-Means nhóm {len(ids)} giao dịch tương đồng, tổng {stats["totalAmount"]:,.0f}đ.',
                ('Ưu tiên giữ khoản thiết yếu; xem lại khoản phát sinh chưa dự kiến.' if stats['essentialRatio']>=60 else
                 'Đối chiếu nhóm giao dịch này với kế hoạch tháng; lập danh sách nhu cầu trước lần mua tiếp theo.'),
                5,['kmeans'],{'clusterId':c.cluster_id,'transactionIds':ids,
                    'totalAmount':stats['totalAmount'],'transactionCount':len(ids),
                    'silhouette':cluster.user_profile.get('kMeans',{}).get('silhouetteScore')},names)
        window=summary.get('forecastWindow',{})
        if summary.get('forecastAvailable') and window:
            total=summary.get('totalPredictedExpense',0)
            add('forecast_plan',window.get('start'),'Chuẩn bị cho chi tiêu sắp tới',
                f'Tổng chi ước tính trong {window.get("days",0)} ngày ({window.get("start")} đến {window.get("end")}): {total:,.0f}đ.',
                'Đối chiếu ước tính với khoản đến hạn và ngân sách trước khi mua thêm. '
                + ('Dự báo chưa được kiểm chứng trên một tập kiểm tra độc lập.' if complete else
                   'Dữ liệu có thể chưa đầy đủ; dùng con số này để tham khảo, không xem là hạn mức an toàn.'),
                4,['forecast_engine'],{'window':window,'predictedExpense':total,
                    'model':summary.get('model'),'historyComplete':complete})
        # Deduplicate identical user-facing messages and limit notification overload.
        unique=[]; seen=set()
        for row in sorted(candidates,key=lambda r:(r['priority'],r['id'])):
            if row['id'] not in seen:
                seen.add(row['id']); unique.append(row)
        selected=unique[:6]
        summary['smartRecommendations']=selected
        summary['recommendations']=[r['suggestion'] for r in selected]
        summary['recommendationDiagnostics']={
            'version':'v15_integrated','kmeansReady':cluster.success,
            'anomalyReady':anomaly.success,'anomalyModelReady':anomaly.statistics.get('modelReady',False),
            'tensorflowAvailable':TF_AVAILABLE,'lstmEnabled':_LSTM_ENABLED.get(),
            'budgetCount':len(budget_rows),'historyComplete':complete,
            'inputDiagnostics':diagnostics,'scope':f'{mm:02d}/{yy}',
            'feedbackPersistence':'client_must_store_and_resend',
            'generatedCount':len(unique),'displayedCount':len(selected)}
        summary['budgetRecommendationsEvidence']=budget_rows
        if not complete:
            summary.setdefault('warnings',[]).append('Ngày không có giao dịch được ghi nhận có thể là ngày chưa nhập dữ liệu; dự báo vì vậy chỉ mang tính tham khảo.')
        advisor=summary.get('personalAdvisor',{})
        advisor.setdefault('actionCards',[])
        for r in selected:
            advisor['actionCards'].append({'id':r['id'],'type':r['type'],'title':r['title'],
                'body':r['suggestion'],'reason':r['reason'],'priority':r['priority'],'dueDate':None,
                'actions':[],'evidence':r['evidence'],'sources':r['sources']})
        advisor['actionCards']=sorted(advisor['actionCards'],key=lambda r:(r['priority'],r['id']))
        if selected:
            # Existing Flutter clients commonly display this field already.
            summary.setdefault('trend',{})['recommendation']=' '.join(
                r['title']+': '+r['suggestion'] for r in selected[:2])
        summary['insightVersion']='v15_integrated_recommendations'


lstm_service = LSTMService()