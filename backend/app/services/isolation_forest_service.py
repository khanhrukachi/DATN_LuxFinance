import calendar
from datetime import datetime
from typing import List, Dict, Any, Optional, Tuple

import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import RobustScaler

from app.schemas.spending import SpendingItem
from app.schemas.response import AnomalyDetectionResponse, AnomalyTransaction
from app.config import settings
from .kmeans_service import _normalize_transactions, _category_key


class IsolationForestService:
    """
    Phát hiện giao dịch chi tiêu bất thường theo TỪNG THÁNG.

    Thiết kế:
    - Chỉ phân tích giao dịch chi tiêu (money < 0).
    - target month = tháng được yêu cầu; nếu không truyền year/month thì lấy tháng mới nhất.
    - Học baseline từ các tháng TRƯỚC target month của chính user (tối đa HISTORY_MONTHS).
    - Nếu lịch sử chưa đủ, fallback sang fit trên target month để app vẫn hoạt động.
    - RobustScaler + IsolationForest để giảm ảnh hưởng của khoản chi cực lớn.
    - Feature mang tính cá nhân: số tiền so với lịch sử category/user, thời gian, tần suất trong ngày.
    - Rule duplicate chỉ bổ trợ; không thay thế Isolation Forest.
    - Không dự báo chi tiêu ở service này (forecast thuộc LSTM).

    Backward compatible:
        detect_anomalies(user_id, transactions, sensitivity=None)
    Có thể gọi theo tháng:
        detect_anomalies(user_id, transactions, year=2026, month=9)
    """

    HISTORY_MONTHS = 6
    MIN_TARGET_TRANSACTIONS = 1
    MIN_HISTORY_TRANSACTIONS = 25
    MIN_MODEL_TRANSACTIONS = 12
    RANDOM_STATE = 42
    N_ESTIMATORS = 300

    # Hybrid anomaly thresholds.
    # Isolation Forest alone is relative/ranking based, therefore strong
    # deterministic amount deviations must also be allowed to trigger anomaly.
    CATEGORY_RATIO_MEDIUM = 2.0
    CATEGORY_RATIO_HIGH = 3.0
    CATEGORY_Z_MEDIUM = 2.5
    CATEGORY_Z_HIGH = 4.0
    USER_RATIO_HIGH = 4.0
    USER_Z_HIGH = 4.0

    CATEGORY_MAP = {
        "eating": "Ăn uống", "move": "Di chuyển", "rent_house": "Thuê nhà",
        "water_money": "Tiền nước", "electricity_bill": "Tiền điện", "gas_money": "Tiền ga",
        "telephone_fee": "Điện thoại", "internet_money": "Internet", "tv_money": "Truyền hình",
        "necessary_spending": "Chi thiết yếu", "repair_and_decorate_the_house": "Sửa nhà",
        "vehicle_maintenance": "Sửa xe", "housewares": "Đồ gia dụng",
        "personal_belongings": "Đồ cá nhân", "pet": "Thú cưng", "family_service": "Việc nhà",
        "education": "Học phí", "physical_examination": "Khám bệnh", "insurance": "Bảo hiểm",
        "fun_play": "Vui chơi", "shopping": "Mua sắm", "travel": "Du lịch",
        "beautify": "Làm đẹp", "sport": "Thể thao", "online_services": "Dịch vụ Online",
        "gifts_donations": "Quà cáp", "charity": "Từ thiện", "invest": "Đầu tư",
        "saving": "Tiết kiệm", "borrow": "Đi vay", "loan": "Cho vay", "pay": "Trả nợ",
        "pay_interest": "Trả lãi", "debt_collection": "Thu nợ", "earn_profit": "Tiền lời",
        "investments_loans_debts": "Vay nợ", "salary": "Lương", "revenue": "Doanh thu",
        "other_income": "Thu nhập khác", "money_transferred_to": "Nhận tiền",
        "money_transferred": "Chuyển tiền", "other_costs": "Chi phí khác",
        "new_group": "Nhóm mới", "other": "Khác",
    }

    # Các khoản định kỳ thường xuất hiện đầu tháng. Không whitelist tuyệt đối;
    # chỉ giảm mức nghi ngờ nếu giá trị vẫn gần lịch sử của chính category đó.
    RECURRING_CATEGORIES = {"Thuê nhà", "Tiền nước", "Tiền điện", "Internet", "Điện thoại", "Bảo hiểm", "Học phí"}

    FEATURE_COLUMNS = [
        "log_amount",
        "category_robust_z",
        "user_robust_z",
        "amount_vs_category_median",
        "amount_vs_user_median",
        "hour_sin",
        "hour_cos",
        "weekday_sin",
        "weekday_cos",
        "is_weekend",
        "daily_count",
        "daily_total_ratio",
    ]

    def __init__(self):
        self.default_contamination = float(settings.ISOLATION_FOREST_CONTAMINATION)

    # ------------------------------------------------------------------
    # Data preparation
    # ------------------------------------------------------------------
    def _get_vietnamese_type_name(self, original_name: Optional[str]) -> str:
        if not original_name:
            return "Khác"
        key_raw = _category_key(original_name).lower().strip()
        if key_raw in self.CATEGORY_MAP:
            return self.CATEGORY_MAP[key_raw]
        key_normalized = key_raw.replace("-", "_").replace(" ", "_")
        if key_normalized in self.CATEGORY_MAP:
            return self.CATEGORY_MAP[key_normalized]
        return str(original_name).replace("_", " ").strip().capitalize()

    def _to_dataframe(self, transactions: List[SpendingItem]) -> pd.DataFrame:
        rows = []
        for t in transactions:
            if t.date_time is None or t.money is None:
                continue
            # Isolation Forest trong đề tài này phục vụ bất thường CHI TIÊU.
            if float(t.money) >= 0:
                continue
            dt = pd.Timestamp(t.date_time)
            rows.append({
                "id": t.id,
                "money": float(t.money),
                "amount": abs(float(t.money)),
                "type": t.type,
                "type_name": self._get_vietnamese_type_name(t.type_name),
                "date_time": dt,
                "year": int(dt.year),
                "month": int(dt.month),
                "day_of_month": int(dt.day),
                "hour": int(dt.hour),
                "weekday": int(dt.weekday()),
            })

        if not rows:
            return pd.DataFrame()
        return pd.DataFrame(rows).sort_values("date_time").reset_index(drop=True)

    def _resolve_target_month(self, df: pd.DataFrame, year: Optional[int], month: Optional[int]) -> Tuple[int, int]:
        if (year is None) != (month is None):
            raise ValueError('Phải truyền đồng thời year và month')
        if year is not None and month is not None:
            if isinstance(year,bool) or isinstance(month,bool) or int(year)!=float(year) or int(month)!=float(month):
                raise ValueError('year/month phải là số nguyên')
            datetime(int(year),int(month),1)
            if month < 1 or month > 12:
                raise ValueError("month phải nằm trong khoảng 1..12")
            return int(year), int(month)
        latest = df["date_time"].max()
        return int(latest.year), int(latest.month)

    @staticmethod
    def _month_key(year: int, month: int) -> int:
        return year * 12 + month

    def _split_month_data(self, df: pd.DataFrame, year: int, month: int) -> Tuple[pd.DataFrame, pd.DataFrame]:
        target_key = self._month_key(year, month)
        keys = df["year"] * 12 + df["month"]
        target = df[keys == target_key].copy()
        min_history_key = target_key - self.HISTORY_MONTHS
        history = df[(keys < target_key) & (keys >= min_history_key)].copy()
        return history, target

    @staticmethod
    def _robust_center_scale(series: pd.Series) -> Tuple[float, float]:
        values = pd.to_numeric(series, errors="coerce").dropna()
        if values.empty:
            return 0.0, 1.0
        median = float(values.median())
        mad = float(np.median(np.abs(values.to_numpy() - median)))
        # 1.4826 * MAD ~ std nếu dữ liệu gần normal.
        scale = 1.4826 * mad
        if not np.isfinite(scale) or scale < 1.0:
            q75, q25 = values.quantile(0.75), values.quantile(0.25)
            scale = float((q75 - q25) / 1.349) if q75 > q25 else max(abs(median) * 0.10, 1.0)
        return median, max(scale, 1.0)

    def _build_reference_stats(self, reference_df: pd.DataFrame) -> Dict[str, Any]:
        user_median, user_scale = self._robust_center_scale(reference_df["amount"])
        category_stats: Dict[str, Dict[str, float]] = {}
        for category, group in reference_df.groupby("type_name"):
            med, scale = self._robust_center_scale(group["amount"])
            category_stats[str(category)] = {
                "median": med,
                "scale": scale,
                "count": int(len(group)),
            }
        return {
            "user_median": user_median,
            "user_scale": user_scale,
            "category_stats": category_stats,
        }

    def _engineer_features(self, df: pd.DataFrame, reference_stats: Dict[str, Any]) -> pd.DataFrame:
        if df.empty:
            return df.copy()

        out = df.copy().sort_values("date_time").reset_index(drop=True)
        user_median = max(float(reference_stats["user_median"]), 1.0)
        user_scale = max(float(reference_stats["user_scale"]), 1.0)
        cat_stats = reference_stats["category_stats"]

        out["log_amount"] = np.log1p(out["amount"])
        out["user_robust_z"] = (out["amount"] - user_median) / user_scale
        out["amount_vs_user_median"] = out["amount"] / user_median

        cat_medians, cat_scales = [], []
        for _, row in out.iterrows():
            stat = cat_stats.get(str(row["type_name"]))
            # Category mới trong tháng: fallback sang baseline toàn user.
            if stat and stat["count"] >= 2:
                cat_medians.append(max(float(stat["median"]), 1.0))
                cat_scales.append(max(float(stat["scale"]), 1.0))
            else:
                cat_medians.append(user_median)
                cat_scales.append(user_scale)

        out["category_median"] = cat_medians
        out["category_scale"] = cat_scales
        out["category_robust_z"] = (out["amount"] - out["category_median"]) / out["category_scale"]
        out["amount_vs_category_median"] = out["amount"] / out["category_median"].clip(lower=1.0)

        # Circular encoding: 23h gần 0h, Chủ nhật gần Thứ hai.
        out["hour_sin"] = np.sin(2 * np.pi * out["hour"] / 24.0)
        out["hour_cos"] = np.cos(2 * np.pi * out["hour"] / 24.0)
        out["weekday_sin"] = np.sin(2 * np.pi * out["weekday"] / 7.0)
        out["weekday_cos"] = np.cos(2 * np.pi * out["weekday"] / 7.0)
        out["is_weekend"] = out["weekday"].isin([5, 6]).astype(int)

        date_key = out["date_time"].dt.date
        out["daily_count"] = out.groupby(date_key)["id"].transform("count").astype(float)
        daily_total = out.groupby(date_key)["amount"].transform("sum").astype(float)
        out["daily_total_ratio"] = daily_total / user_median

        return out

    # ------------------------------------------------------------------
    # Model + rules
    # ------------------------------------------------------------------
    def _sanitize_contamination(self, sensitivity: Optional[float], n_samples: int) -> float:
        value = self.default_contamination if sensitivity is None else float(sensitivity)
        value = float(np.clip(value, 0.01, 0.20))
        # Tránh ép quá nhiều anomaly khi tháng có ít giao dịch.
        if n_samples < 20:
            value = min(value, 0.05)
        return value

    def _detect_duplicates(self, target_df: pd.DataFrame) -> List[Dict[str, Any]]:
        if target_df.empty:
            return []
        work = target_df.sort_values("date_time").copy()
        anomalies: List[Dict[str, Any]] = []
        for _, group in work.groupby(["type_name", "amount"], dropna=False):
            group = group.sort_values("date_time")
            previous_time = None
            for _, row in group.iterrows():
                if previous_time is not None:
                    seconds = (row["date_time"] - previous_time).total_seconds()
                    if 0 <= seconds <= 300:
                        anomalies.append({
                            "id": row["id"],
                            "reason": f"Nghi vấn giao dịch trùng lặp: cùng danh mục và số tiền trong vòng {max(1, int(seconds // 60))} phút.",
                            "score": 1.0,
                            "severity": "high",
                        })
                previous_time = row["date_time"]
        return anomalies

    def _is_expected_recurring(self, row: pd.Series) -> bool:
        return (
            row["type_name"] in self.RECURRING_CATEGORIES
            and int(row["day_of_month"]) <= 7
            and abs(float(row["category_robust_z"])) < 2.0
        )

    def _amount_rule_evidence(self, row: pd.Series) -> Dict[str, Any]:
        """
        Rule layer độc lập với Isolation Forest.

        Một giao dịch chênh lệch rất lớn so với baseline category/user phải có
        khả năng được đánh dấu bất thường ngay cả khi IF không gắn label -1.
        Điều này sửa nhược điểm của contamination/ranking-based detection.
        """
        cat_ratio = max(float(row.get("amount_vs_category_median", 0.0)), 0.0)
        user_ratio = max(float(row.get("amount_vs_user_median", 0.0)), 0.0)
        cat_z = abs(float(row.get("category_robust_z", 0.0)))
        user_z = abs(float(row.get("user_robust_z", 0.0)))

        strong = (
            (cat_ratio >= self.CATEGORY_RATIO_HIGH and cat_z >= self.CATEGORY_Z_MEDIUM)
            or cat_z >= self.CATEGORY_Z_HIGH
            or (user_ratio >= self.USER_RATIO_HIGH and user_z >= self.USER_Z_HIGH)
        )
        medium = (
            (cat_ratio >= self.CATEGORY_RATIO_MEDIUM and cat_z >= self.CATEGORY_Z_MEDIUM)
            or cat_z >= 3.0
            or (user_ratio >= 3.0 and user_z >= 3.0)
        )

        # Rule score is intentionally interpretable, not a probability.
        cat_component = min(cat_ratio / max(self.CATEGORY_RATIO_HIGH, 1.0), 1.5)
        z_component = min(max(cat_z, user_z) / max(self.CATEGORY_Z_HIGH, 1.0), 1.5)
        ratio_component = min(user_ratio / max(self.USER_RATIO_HIGH, 1.0), 1.5)
        evidence = max(cat_component, z_component, ratio_component)

        if strong:
            severity = "high"
            score = max(0.82, min(1.0, 0.72 + 0.18 * evidence))
        elif medium:
            severity = "medium"
            score = max(0.60, min(0.81, 0.52 + 0.16 * evidence))
        else:
            severity = "low"
            score = min(0.59, max(0.0, 0.35 * evidence))

        return {
            "strong": bool(strong),
            "medium": bool(medium),
            "score": float(score),
            "severity": severity,
            "categoryRatio": cat_ratio,
            "userRatio": user_ratio,
            "categoryRobustZ": cat_z,
            "userRobustZ": user_z,
        }

    def _is_rule_anomaly(self, row: pd.Series) -> bool:
        evidence = self._amount_rule_evidence(row)

        # Khoản định kỳ chỉ được giảm cảnh báo nếu THỰC SỰ gần baseline.
        if self._is_expected_recurring(row):
            return False

        return bool(evidence["strong"] or evidence["medium"])

    def _reason_for(self, row: pd.Series, month_thresholds: Dict[str, float]) -> str:
        reasons = []
        cat = str(row["type_name"])
        cat_z = abs(float(row["category_robust_z"]))
        user_z = abs(float(row["user_robust_z"]))
        cat_ratio = float(row["amount_vs_category_median"])

        user_ratio = float(row["amount_vs_user_median"])

        if cat_ratio >= self.CATEGORY_RATIO_HIGH and cat_z >= self.CATEGORY_Z_MEDIUM:
            reasons.append(
                f"Số tiền cao khoảng {cat_ratio:.1f} lần mức điển hình của '{cat}'"
            )
        elif cat_ratio >= self.CATEGORY_RATIO_MEDIUM and cat_z >= self.CATEGORY_Z_MEDIUM:
            reasons.append(
                f"Số tiền cao khoảng {cat_ratio:.1f} lần mức thường thấy của '{cat}'"
            )
        elif cat_z >= 3.0:
            reasons.append(f"Khác biệt rất rõ so với lịch sử chi tiêu '{cat}'")

        if user_ratio >= self.USER_RATIO_HIGH and user_z >= 3.0:
            reasons.append(
                f"Giá trị cao khoảng {user_ratio:.1f} lần mức giao dịch điển hình của bạn"
            )
        elif user_z >= 3.0:
            reasons.append("Giá trị giao dịch rất cao so với mức chi tiêu thông thường của bạn")

        if float(row["daily_count"]) > month_thresholds["daily_count"]:
            reasons.append(f"Ngày này có tần suất giao dịch cao ({int(row['daily_count'])} giao dịch)")

        if float(row["daily_total_ratio"]) > month_thresholds["daily_total_ratio"]:
            reasons.append("Tổng chi trong ngày cao bất thường so với mức chi điển hình")

        hour = int(row["hour"])
        if hour <= 4 and (cat_z >= 1.5 or user_z >= 2.0):
            reasons.append(f"Phát sinh vào khung giờ ít gặp ({hour:02d}h)")

        if self._is_expected_recurring(row):
            reasons.append("Khoản định kỳ đầu tháng; giá trị vẫn gần lịch sử nên mức cảnh báo đã được giảm")

        if not reasons:
            reasons.append("Tổ hợp số tiền, thời điểm và tần suất khác với hành vi chi tiêu thường thấy")
        return "; ".join(reasons)

    def _severity_for(self, row: pd.Series) -> str:
        score = float(row["anomaly_score_normalized"])
        evidence = self._amount_rule_evidence(row)
        robust_z = max(
            abs(float(row["category_robust_z"])),
            abs(float(row["user_robust_z"])),
        )

        if evidence["strong"] or score >= 0.80 or robust_z >= 4.0:
            return "high"
        if evidence["medium"] or score >= 0.55 or robust_z >= 2.5:
            return "medium"
        return "low"

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def detect_anomalies(
        self,
        user_id: str,
        transactions: List[SpendingItem],
        sensitivity: float = None,
        year: int = None,
        month: int = None,
        reference_date=None,
    ) -> AnomalyDetectionResponse:
        normalized, diagnostics = _normalize_transactions(transactions, reference_date)
        all_df = self._to_dataframe(normalized)
        if all_df.empty:
            return self._empty_response(user_id, 0, "Không có giao dịch chi tiêu hợp lệ.")

        target_year, target_month = self._resolve_target_month(all_df, year, month)
        history_raw, target_raw = self._split_month_data(all_df, target_year, target_month)
        month_label = f"{target_month:02d}/{target_year}"

        if target_raw.empty:
            return self._empty_response(user_id, 0, f"Không có giao dịch chi tiêu trong tháng {month_label}.")

        if len(target_raw) < self.MIN_TARGET_TRANSACTIONS:
            return AnomalyDetectionResponse(
                success=False,
                user_id=user_id,
                total_transactions=int(len(target_raw)),
                anomalies_detected=0,
                anomalies=[],
                statistics={"analysisMonth": month_label, "targetTransactions": int(len(target_raw))},
                alerts=[f"Tháng {month_label} mới có {len(target_raw)} giao dịch; cần ít nhất {self.MIN_TARGET_TRANSACTIONS} để phân tích."],
                message="Chưa đủ dữ liệu trong tháng",
            )

        # Ưu tiên baseline các tháng trước. Nếu chưa đủ, dùng target month làm fallback.
        use_historical_baseline = len(history_raw) >= self.MIN_HISTORY_TRANSACTIONS
        reference_raw = history_raw if use_historical_baseline else target_raw
        reference_stats = self._build_reference_stats(reference_raw)
        reference_df = self._engineer_features(reference_raw, reference_stats)
        target_df = self._engineer_features(target_raw, reference_stats)

        # Nếu reference quá ít, vẫn trả duplicate/rule result thay vì ép ML thiếu tin cậy.
        model_ready = len(reference_df) >= self.MIN_MODEL_TRANSACTIONS
        contamination = self._sanitize_contamination(sensitivity, len(reference_df))

        target_df["anomaly_label"] = 1
        target_df["anomaly_score_raw"] = 0.0
        target_df["anomaly_score_normalized"] = 0.0

        if model_ready:
            scaler = RobustScaler(quantile_range=(10.0, 90.0))
            X_ref = np.nan_to_num(reference_df[self.FEATURE_COLUMNS].to_numpy(dtype=float), nan=0.0, posinf=0.0, neginf=0.0)
            X_target = np.nan_to_num(target_df[self.FEATURE_COLUMNS].to_numpy(dtype=float), nan=0.0, posinf=0.0, neginf=0.0)
            X_ref_scaled = scaler.fit_transform(X_ref)
            X_target_scaled = scaler.transform(X_target)

            model = IsolationForest(
                n_estimators=self.N_ESTIMATORS,
                contamination=contamination,
                max_samples="auto",
                random_state=self.RANDOM_STATE,
                n_jobs=-1,
            )
            model.fit(X_ref_scaled)
            target_df["anomaly_label"] = model.predict(X_target_scaled)
            # decision_function càng thấp càng bất thường => đổi dấu.
            target_df["anomaly_score_raw"] = -model.decision_function(X_target_scaled)

            # Normalize dựa trên score của reference + target để ổn định hơn theo tháng.
            ref_scores = -model.decision_function(X_ref_scaled)
            combined_scores = np.concatenate([ref_scores, target_df["anomaly_score_raw"].to_numpy()])
            low, high = np.quantile(combined_scores, [0.05, 0.95]) if len(combined_scores) >= 5 else (combined_scores.min(), combined_scores.max())
            denom = max(float(high - low), 1e-9)
            target_df["anomaly_score_normalized"] = ((target_df["anomaly_score_raw"] - low) / denom).clip(0.0, 1.0)

        # Khoản định kỳ chỉ giảm cảnh báo khi giá trị thực sự gần baseline.
        # Không whitelist theo category/date nếu amount đã lệch mạnh.
        recurring_mask = target_df.apply(self._is_expected_recurring, axis=1)
        target_df.loc[recurring_mask, "anomaly_label"] = 1
        target_df.loc[recurring_mask, "anomaly_score_normalized"] *= 0.35

        # Hybrid rule score: deterministic amount deviation can override IF.
        rule_evidence = target_df.apply(self._amount_rule_evidence, axis=1)
        target_df["rule_anomaly"] = [bool(x["strong"] or x["medium"]) for x in rule_evidence]
        target_df["rule_score"] = [float(x["score"]) for x in rule_evidence]

        # Expected recurring rows are excluded only because _is_expected_recurring
        # already requires category_robust_z < 2.0.
        target_df.loc[recurring_mask, "rule_anomaly"] = False

        # Final score is the stronger evidence from IF or interpretable rules.
        target_df["anomaly_score_normalized"] = np.maximum(
            target_df["anomaly_score_normalized"].astype(float),
            target_df["rule_score"].astype(float),
        )

        duplicate_items = self._detect_duplicates(target_df)
        duplicate_ids = {item["id"] for item in duplicate_items}

        daily_count_threshold = max(5.0, float(target_df["daily_count"].quantile(0.95)))
        daily_ratio_threshold = max(4.0, float(target_df["daily_total_ratio"].quantile(0.95)))
        thresholds = {
            "daily_count": daily_count_threshold,
            "daily_total_ratio": daily_ratio_threshold,
        }

        final_anomalies: List[AnomalyTransaction] = []

        # IMPORTANT: anomaly = Isolation Forest OR strong interpretable rule.
        # Previously only anomaly_label == -1 was returned, therefore an obvious
        # amount deviation could disappear if IF ranked it as normal.
        hybrid_mask = (
            (target_df["anomaly_label"] == -1)
            | (target_df["rule_anomaly"] == True)
        )
        ai_rows = target_df[hybrid_mask & (~target_df["id"].isin(duplicate_ids))]
        for _, row in ai_rows.iterrows():
            final_anomalies.append(AnomalyTransaction(
                transaction_id=row["id"],
                money=int(row["money"]),
                type_name=str(row["type_name"]),
                date_time=row["date_time"].strftime("%Y-%m-%d %H:%M"),
                anomaly_score=round(float(row["anomaly_score_normalized"]), 3),
                anomaly_reason=self._reason_for(row, thresholds),
                severity=self._severity_for(row),
            ))

        for item in duplicate_items:
            row = target_df[target_df["id"] == item["id"]].iloc[0]
            final_anomalies.append(AnomalyTransaction(
                transaction_id=item["id"],
                money=int(row["money"]),
                type_name=str(row["type_name"]),
                date_time=row["date_time"].strftime("%Y-%m-%d %H:%M"),
                anomaly_score=float(item["score"]),
                anomaly_reason=item["reason"],
                severity=item["severity"],
            ))

        severity_order = {"high": 0, "medium": 1, "low": 2}
        final_anomalies.sort(key=lambda x: (severity_order.get(x.severity, 9), -float(x.anomaly_score)))

        anomaly_ids = {x.transaction_id for x in final_anomalies}
        anomaly_df = target_df[target_df["id"].isin(anomaly_ids)].copy()
        severity_map = {x.transaction_id: x.severity for x in final_anomalies}

        statistics = self._build_statistics(
            target_df=target_df,
            anomaly_df=anomaly_df,
            severity_map=severity_map,
            target_year=target_year,
            target_month=target_month,
            history_count=len(history_raw),
            use_historical_baseline=use_historical_baseline,
            contamination=contamination,
            model_ready=model_ready,
        )
        statistics['inputDiagnostics'] = diagnostics
        statistics['scoreMeaning'] = 'relative_anomaly_score_not_probability'
        statistics['recommendations'] = [
            {'transactionId': a.transaction_id, 'type': 'review_transaction',
             'title': 'Kiểm tra khoản chi khác thường',
             'reason': a.anomaly_reason,
             'suggestion': 'Đối chiếu số tiền, danh mục và giao dịch trùng. Nếu khoản chi đã có kế hoạch, ghi nhận điều đó; không tự động xóa hoặc cắt giảm.',
             'severity': a.severity, 'source': 'isolation_forest_and_rules'}
            for a in final_anomalies[:5]]
        alerts = self._generate_monthly_alerts(final_anomalies, statistics, target_df)

        mode_text = "baseline lịch sử" if use_historical_baseline else "baseline nội tháng (do lịch sử chưa đủ)"
        return AnomalyDetectionResponse(
            success=True,
            user_id=user_id,
            total_transactions=int(len(target_df)),
            anomalies_detected=len(final_anomalies),
            anomalies=final_anomalies,
            statistics=statistics,
            alerts=alerts,
            message=f"Phân tích bất thường tháng {month_label} hoàn tất - {mode_text}",
        )

    def _empty_response(self, user_id: str, total: int, message: str) -> AnomalyDetectionResponse:
        return AnomalyDetectionResponse(
            success=False,
            user_id=user_id,
            total_transactions=int(total),
            anomalies_detected=0,
            anomalies=[],
            statistics={},
            alerts=[message],
            message="Không đủ dữ liệu",
        )

    # ------------------------------------------------------------------
    # Output
    # ------------------------------------------------------------------
    def _build_statistics(
        self,
        target_df: pd.DataFrame,
        anomaly_df: pd.DataFrame,
        severity_map: Dict[Any, str],
        target_year: int,
        target_month: int,
        history_count: int,
        use_historical_baseline: bool,
        contamination: float,
        model_ready: bool,
    ) -> Dict[str, Any]:
        total_amount = float(target_df["amount"].sum())
        anomaly_amount = float(anomaly_df["amount"].sum()) if not anomaly_df.empty else 0.0
        normal_df = target_df[~target_df["id"].isin(anomaly_df["id"])] if not anomaly_df.empty else target_df

        top_cat = "Không có"
        if not anomaly_df.empty:
            by_amount = anomaly_df.groupby("type_name")["amount"].sum().sort_values(ascending=False)
            if not by_amount.empty:
                top_cat = str(by_amount.index[0])

        severity_distribution = {"high": 0, "medium": 0, "low": 0}
        for severity in severity_map.values():
            if severity in severity_distribution:
                severity_distribution[severity] += 1

        days_in_month = calendar.monthrange(target_year, target_month)[1]
        active_days = int(target_df["date_time"].dt.date.nunique())

        return {
            "analysisMonth": f"{target_month:02d}/{target_year}",
            "analysisYear": int(target_year),
            "analysisMonthNumber": int(target_month),
            "daysInMonth": int(days_in_month),
            "activeDays": active_days,
            "totalTransactions": int(len(target_df)),
            "historyTransactionsUsed": int(history_count),
            "baselineMode": "previous_months" if use_historical_baseline else "current_month_fallback",
            "modelReady": bool(model_ready),
            "contamination": round(float(contamination), 4),
            "detectionMode": "hybrid_isolation_forest_plus_robust_rules",
            "ruleTriggeredTransactions": int(target_df["rule_anomaly"].sum()) if "rule_anomaly" in target_df.columns else 0,
            "isolationForestTriggeredTransactions": int((target_df["anomaly_label"] == -1).sum()),
            "normalTransactions": int(len(target_df) - len(anomaly_df)),
            "anomalyRate": round(len(anomaly_df) / len(target_df) * 100, 2) if len(target_df) else 0.0,
            "totalSpent": round(total_amount, 0),
            "totalAnomalyAmount": round(anomaly_amount, 0),
            "anomalyAmountPercentage": round(anomaly_amount / total_amount * 100, 2) if total_amount > 0 else 0.0,
            "topAnomalyCategory": top_cat,
            "severityDistribution": severity_distribution,
            "averageNormalAmount": round(float(normal_df["amount"].mean()), 0) if not normal_df.empty else 0.0,
            "averageAnomalyAmount": round(float(anomaly_df["amount"].mean()), 0) if not anomaly_df.empty else 0.0,
        }

    def _generate_monthly_alerts(
        self,
        anomalies: List[AnomalyTransaction],
        stats: Dict[str, Any],
        target_df: pd.DataFrame,
    ) -> List[str]:
        alerts: List[str] = []
        month_label = stats["analysisMonth"]
        high_count = int(stats["severityDistribution"]["high"])
        medium_count = int(stats["severityDistribution"]["medium"])

        if high_count > 0:
            alerts.append(f"⚠️ Tháng {month_label} có {high_count} giao dịch bất thường mức CAO cần kiểm tra.")
        elif medium_count > 0:
            alerts.append(f"🔎 Tháng {month_label} có {medium_count} giao dịch mức bất thường trung bình.")

        if stats["anomalyAmountPercentage"] >= 25:
            alerts.append(
                f"💰 Các giao dịch bất thường chiếm {stats['anomalyAmountPercentage']:.1f}% tổng chi tháng {month_label}."
            )

        top_cat = stats["topAnomalyCategory"]
        if top_cat != "Không có":
            alerts.append(f"📌 Danh mục cần chú ý nhất trong tháng: {top_cat}.")

        # Distribution only, not an equal-period growth rate.
        first_half = float(target_df[target_df["day_of_month"] <= 15]["amount"].sum())
        second_half = float(target_df[target_df["day_of_month"] > 15]["amount"].sum())
        if first_half > 0 and second_half > first_half * 1.5:
            alerts.append("📈 Tổng chi đã ghi nhận tập trung ở nửa cuối tháng; hai giai đoạn có thể chưa đủ cùng số ngày.")
        elif second_half > 0 and first_half > second_half * 1.5:
            alerts.append("📅 Chi tiêu tập trung nhiều vào nửa đầu tháng.")

        if not stats["modelReady"]:
            alerts.append("ℹ️ Dữ liệu nền còn ít; kết quả tháng này chủ yếu mang tính tham khảo và sẽ ổn định hơn khi có thêm lịch sử.")
        elif stats["baselineMode"] == "current_month_fallback":
            alerts.append("ℹ️ Chưa đủ dữ liệu các tháng trước nên hệ thống đang dùng chính tháng này làm baseline tạm thời.")

        if not anomalies:
            alerts.insert(0, f"✅ Tháng {month_label} chưa phát hiện giao dịch chi tiêu bất thường đáng kể.")

        alerts.append("Khoản chi khác thường không đồng nghĩa với sai phạm hoặc lãng phí; hãy xác nhận bối cảnh trước khi điều chỉnh.")
        return alerts[:6]


isolation_forest_service = IsolationForestService()
