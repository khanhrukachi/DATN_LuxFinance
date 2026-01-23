import numpy as np
import pandas as pd
from typing import List, Dict, Any
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from datetime import datetime, timedelta

from app.schemas.spending import SpendingItem
from app.schemas.response import AnomalyDetectionResponse, AnomalyTransaction
from app.config import settings


class IsolationForestService:

    def __init__(self):
        self.scaler = StandardScaler()
        self.default_contamination = settings.ISOLATION_FOREST_CONTAMINATION

    def _extract_features(self, transactions: List[SpendingItem]) -> pd.DataFrame:
        data = []
        for t in transactions:
            data.append({
                'id': t.id,
                'money': t.money,
                'amount': abs(t.money),
                'type': t.type,
                'type_name': t.type_name,
                'date_time': t.date_time,
                'hour': t.date_time.hour,
                'weekday': t.date_time.weekday(),
                'day_of_month': t.date_time.day,
                'is_expense': t.money < 0
            })

        if not data:
            return pd.DataFrame()

        df = pd.DataFrame(data)
        df = df.sort_values('date_time').reset_index(drop=True)

        df['log_amount'] = np.log1p(df['amount'])

        for type_id in df['type'].unique():
            mask = df['type'] == type_id
            type_amounts = df.loc[mask, 'amount']
            df.loc[mask, 'type_mean'] = type_amounts.expanding().mean()
            df.loc[mask, 'type_std'] = type_amounts.expanding().std().fillna(0)

        df['type_mean'] = df['type_mean'].fillna(df['amount'].mean())
        df['type_std'] = df['type_std'].fillna(df['amount'].std())

        df['amount_zscore'] = np.where(
            df['type_std'] > 0,
            (df['amount'] - df['type_mean']) / df['type_std'],
            0
        )

        global_mean = df['amount'].mean()
        global_std = df['amount'].std()
        df['global_zscore'] = (df['amount'] - global_mean) / global_std if global_std > 0 else 0

        df['is_unusual_hour'] = df['hour'].apply(
            lambda x: 1 if x < 6 or x > 23 else 0
        )
        df['is_weekend'] = df['weekday'].isin([5, 6]).astype(int)

        df['daily_count'] = df.groupby(df['date_time'].dt.date)['id'].transform('count')
        df['daily_total'] = df.groupby(df['date_time'].dt.date)['amount'].transform('sum')

        return df

    def _determine_anomaly_reason(self, row: pd.Series, thresholds: Dict[str, float]) -> str:
        reasons = []

        if abs(row['amount_zscore']) > 2:
            if row['amount'] > row['type_mean']:
                reasons.append(f"Số tiền cao bất thường cho danh mục {row['type_name']}")
            else:
                reasons.append(f"Số tiền thấp bất thường cho danh mục {row['type_name']}")

        if abs(row['global_zscore']) > 2.5:
            reasons.append("Số tiền vượt xa mức trung bình chung")

        if row['is_unusual_hour']:
            reasons.append(f"Giao dịch vào giờ bất thường ({row['hour']}:00)")

        if row['daily_count'] > thresholds.get('daily_count', 10):
            reasons.append(f"Quá nhiều giao dịch trong ngày ({int(row['daily_count'])} giao dịch)")

        if row['daily_total'] > thresholds.get('daily_total', row['amount'] * 5):
            reasons.append("Tổng chi tiêu trong ngày cao bất thường")

        if not reasons:
            reasons.append("Mẫu giao dịch khác biệt so với hành vi thông thường")

        return "; ".join(reasons)

    def _determine_severity(self, anomaly_score: float, amount_zscore: float) -> str:
        combined_score = abs(anomaly_score) + abs(amount_zscore) / 3

        if combined_score > 0.8 or abs(amount_zscore) > 4:
            return "high"
        elif combined_score > 0.5 or abs(amount_zscore) > 2.5:
            return "medium"
        else:
            return "low"

    def detect_anomalies(
        self,
        user_id: str,
        transactions: List[SpendingItem],
        sensitivity: float = None
    ) -> AnomalyDetectionResponse:
        df = self._extract_features(transactions)

        if df.empty or len(df) < 10:
            return AnomalyDetectionResponse(
                success=False,
                user_id=user_id,
                total_transactions=len(transactions),
                anomalies_detected=0,
                anomalies=[],
                statistics={},
                alerts=["Cần ít nhất 10 giao dịch để phát hiện bất thường."],
                message="Insufficient data for anomaly detection"
            )

        contamination = sensitivity or self.default_contamination

        feature_columns = [
            'log_amount', 'amount_zscore', 'global_zscore',
            'is_unusual_hour', 'is_weekend', 'daily_count'
        ]
        X = df[feature_columns].values

        X = np.nan_to_num(X, nan=0.0, posinf=0.0, neginf=0.0)

        X_scaled = self.scaler.fit_transform(X)

        iso_forest = IsolationForest(
            contamination=contamination,
            random_state=42,
            n_estimators=100,
            max_samples='auto'
        )

        df['anomaly_label'] = iso_forest.fit_predict(X_scaled)
        df['anomaly_score'] = -iso_forest.decision_function(X_scaled)

        score_min = df['anomaly_score'].min()
        score_max = df['anomaly_score'].max()
        if score_max > score_min:
            df['anomaly_score_normalized'] = (df['anomaly_score'] - score_min) / (score_max - score_min)
        else:
            df['anomaly_score_normalized'] = 0.5

        anomaly_df = df[df['anomaly_label'] == -1].copy()

        thresholds = {
            'daily_count': df['daily_count'].quantile(0.9),
            'daily_total': df['daily_total'].quantile(0.9)
        }

        anomalies = []
        for _, row in anomaly_df.iterrows():
            reason = self._determine_anomaly_reason(row, thresholds)
            severity = self._determine_severity(
                row['anomaly_score_normalized'],
                row['amount_zscore']
            )

            anomalies.append(AnomalyTransaction(
                transaction_id=row['id'],
                money=int(row['money']),
                type_name=row['type_name'],
                date_time=row['date_time'].strftime('%Y-%m-%d %H:%M'),
                anomaly_score=round(row['anomaly_score_normalized'], 3),
                anomaly_reason=reason,
                severity=severity
            ))

        severity_order = {'high': 0, 'medium': 1, 'low': 2}
        anomalies.sort(key=lambda x: (severity_order[x.severity], -x.anomaly_score))

        statistics = self._build_statistics(df, anomaly_df)
        alerts = self._generate_alerts(anomalies, statistics)

        return AnomalyDetectionResponse(
            success=True,
            user_id=user_id,
            total_transactions=len(df),
            anomalies_detected=len(anomalies),
            anomalies=anomalies,
            statistics=statistics,
            alerts=alerts,
            message="Phát hiện giao dịch bất thường thành công"
        )

    def _build_statistics(self, df: pd.DataFrame, anomaly_df: pd.DataFrame) -> Dict[str, Any]:
        total_amount = df['amount'].sum()
        anomaly_amount = anomaly_df['amount'].sum() if not anomaly_df.empty else 0

        if not anomaly_df.empty:
            anomaly_by_category = anomaly_df['type_name'].value_counts()
            top_anomaly_category = anomaly_by_category.index[0] if len(anomaly_by_category) > 0 else "N/A"
        else:
            top_anomaly_category = "N/A"

        if not anomaly_df.empty:
            high_severity = len(anomaly_df[anomaly_df['amount_zscore'].abs() > 3])
            medium_severity = len(anomaly_df[(anomaly_df['amount_zscore'].abs() > 2) &
                                             (anomaly_df['amount_zscore'].abs() <= 3)])
            low_severity = len(anomaly_df) - high_severity - medium_severity
        else:
            high_severity = medium_severity = low_severity = 0

        normal_df = df[df['anomaly_label'] == 1]
        avg_normal = float(round(normal_df['amount'].mean(), 0)) if len(normal_df) > 0 else 0.0
        avg_anomaly = float(round(anomaly_df['amount'].mean(), 0)) if not anomaly_df.empty else 0.0

        return {
            "totalTransactions": int(len(df)),
            "normalTransactions": int(len(df) - len(anomaly_df)),
            "anomalyRate": float(round(len(anomaly_df) / len(df) * 100, 2)) if len(df) > 0 else 0.0,
            "totalAnomalyAmount": float(round(anomaly_amount, 0)),
            "anomalyAmountPercentage": float(round(anomaly_amount / total_amount * 100, 2)) if total_amount > 0 else 0.0,
            "topAnomalyCategory": str(top_anomaly_category),
            "severityDistribution": {
                "high": int(high_severity),
                "medium": int(medium_severity),
                "low": int(low_severity)
            },
            "averageNormalAmount": avg_normal,
            "averageAnomalyAmount": avg_anomaly
        }

    def _generate_alerts(
        self,
        anomalies: List[AnomalyTransaction],
        statistics: Dict[str, Any]
    ) -> List[str]:
        alerts = []

        high_count = statistics['severityDistribution']['high']
        if high_count > 0:
            alerts.append(
                f"⚠️ Phát hiện {high_count} giao dịch có mức độ bất thường CAO cần kiểm tra ngay."
            )

        if statistics['anomalyRate'] > 15:
            alerts.append(
                f"📊 Tỷ lệ giao dịch bất thường cao ({statistics['anomalyRate']}%). "
                "Xem xét lại thói quen chi tiêu."
            )

        if statistics['anomalyAmountPercentage'] > 20:
            alerts.append(
                f"💰 Các giao dịch bất thường chiếm {statistics['anomalyAmountPercentage']}% tổng chi tiêu. "
                "Cần kiểm soát các khoản chi lớn."
            )

        if statistics['topAnomalyCategory'] != "N/A":
            alerts.append(
                f"📌 Danh mục '{statistics['topAnomalyCategory']}' có nhiều giao dịch bất thường nhất."
            )

        if len(anomalies) == 0:
            alerts.append(
                "✅ Không phát hiện giao dịch bất thường. Hành vi chi tiêu của bạn ổn định."
            )

        return alerts[:5]


isolation_forest_service = IsolationForestService()
