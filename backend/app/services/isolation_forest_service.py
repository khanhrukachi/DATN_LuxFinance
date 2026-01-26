import numpy as np
import pandas as pd
from typing import List, Dict, Any
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from datetime import datetime, timedelta

# Import giữ nguyên theo yêu cầu
from app.schemas.spending import SpendingItem
from app.schemas.response import AnomalyDetectionResponse, AnomalyTransaction
from app.config import settings

class IsolationForestService:

    CATEGORY_MAP = {
        "eating": "Ăn uống",
        "move": "Di chuyển",
        "rent_house": "Thuê nhà",
        "water_money": "Tiền nước",
        "electricity_bill": "Tiền điện",
        "gas_money": "Tiền ga",
        "telephone_fee": "Điện thoại",
        "internet_money": "Internet",
        "tv_money": "Truyền hình",
        "necessary_spending": "Chi thiết yếu",
        "repair_and_decorate_the_house": "Sửa nhà",
        "vehicle_maintenance": "Sửa xe",
        "housewares": "Đồ gia dụng",
        "personal_belongings": "Đồ cá nhân",
        "pet": "Thú cưng",
        "family_service": "Việc nhà",
        "education": "Học phí",
        "physical_examination": "Khám bệnh",
        "insurance": "Bảo hiểm",
        "fun_play": "Vui chơi",
        "shopping": "Mua sắm",
        "travel": "Du lịch",
        "beautify": "Làm đẹp",
        "sport": "Thể thao",
        "online_services": "Dịch vụ Online",
        "gifts_donations": "Quà cáp",
        "charity": "Từ thiện",
        "invest": "Đầu tư",
        "saving": "Tiết kiệm",
        "borrow": "Đi vay",
        "loan": "Cho vay",
        "pay": "Trả nợ",
        "pay_interest": "Trả lãi",
        "debt_collection": "Thu nợ",
        "earn_profit": "Tiền lời",
        "investments_loans_debts": "Vay nợ",
        "salary": "Lương",
        "revenue": "Doanh thu",
        "other_income": "Thu nhập khác",
        "money_transferred_to": "Nhận tiền",
        "money_transferred": "Chuyển tiền",
        "other_costs": "Chi phí khác",
        "new_group": "Nhóm mới",
        "other": "Khác",
    }

    def __init__(self):
        self.scaler = StandardScaler()
        self.default_contamination = settings.ISOLATION_FOREST_CONTAMINATION

    def _get_vietnamese_type_name(self, original_name: str) -> str:
        if not original_name: return "Khác"
        key_raw = str(original_name).lower().strip()
        if key_raw in self.CATEGORY_MAP: return self.CATEGORY_MAP[key_raw]
        key_normalized = key_raw.replace("_", " ").replace("-", " ")
        if key_normalized in self.CATEGORY_MAP: return self.CATEGORY_MAP[key_normalized]
        for key, value in self.CATEGORY_MAP.items():
            if len(key) > 2 and f" {key} " in f" {key_normalized} ": return value
            if len(key) > 3 and key in key_normalized: return value
        return key_normalized.capitalize()

    def _extract_features(self, transactions: List[SpendingItem]) -> pd.DataFrame:
        data = []
        for t in transactions:
            vn_type_name = self._get_vietnamese_type_name(t.type_name)
            data.append({
                'id': t.id, 'money': t.money, 'amount': abs(t.money),
                'type': t.type, 'type_name': vn_type_name,
                'date_time': t.date_time,
                'hour': t.date_time.hour,
                'weekday': t.date_time.weekday(),
                'day_of_month': t.date_time.day,
                'is_expense': t.money < 0
            })

        if not data: return pd.DataFrame()

        df = pd.DataFrame(data)
        df = df.sort_values('date_time').reset_index(drop=True)

        df['log_amount'] = np.log1p(df['amount'])

        indexer = pd.api.indexers.FixedForwardWindowIndexer(window_size=7) # Hack for rolling
        df['rolling_mean_7d'] = df['amount'].rolling(window=7, min_periods=1).mean()
        df['rolling_std_7d'] = df['amount'].rolling(window=7, min_periods=1).std().fillna(1)
        
        df['is_month_start'] = df['day_of_month'].apply(lambda x: 1 if x <= 5 else 0)

        for type_name_vn in df['type_name'].unique():
            mask = df['type_name'] == type_name_vn
            type_amounts = df.loc[mask, 'amount']
            df.loc[mask, 'type_mean'] = type_amounts.expanding().mean()
            df.loc[mask, 'type_std'] = type_amounts.expanding().std().fillna(0)

        df['type_mean'] = df['type_mean'].fillna(df['amount'].mean())
        df['type_std'] = df['type_std'].fillna(df['amount'].std())

        df['amount_zscore'] = np.where(df['type_std'] > 0, (df['amount'] - df['type_mean']) / df['type_std'], 0)
        
        global_mean, global_std = df['amount'].mean(), df['amount'].std()
        df['global_zscore'] = (df['amount'] - global_mean) / global_std if global_std > 0 else 0

        df['is_unusual_hour'] = df['hour'].apply(lambda x: 1 if x < 6 or x > 23 else 0)
        df['is_weekend'] = df['weekday'].isin([5, 6]).astype(int)

        df['daily_count'] = df.groupby(df['date_time'].dt.date)['id'].transform('count')
        df['daily_total'] = df.groupby(df['date_time'].dt.date)['amount'].transform('sum')

        return df

    def _detect_logical_anomalies(self, df: pd.DataFrame) -> List[Dict]:
        anomalies = []
        
        df_sorted = df.sort_values(['type_name', 'amount', 'date_time'])
        df_sorted['prev_time'] = df_sorted['date_time'].shift(1)
        df_sorted['prev_amount'] = df_sorted['amount'].shift(1)
        df_sorted['prev_type'] = df_sorted['type_name'].shift(1)
        
        for index, row in df_sorted.iterrows():
            if (row['amount'] == row['prev_amount'] and row['type_name'] == row['prev_type'] and row['amount'] > 0):
                if pd.notnull(row['prev_time']):
                    diff = (row['date_time'] - row['prev_time']).total_seconds()
                    if diff < 300: # 5 phút
                        anomalies.append({
                            'id': row['id'],
                            'reason': f"Nghi vấn trùng lặp: Giống hệt giao dịch lúc {row['prev_time'].strftime('%H:%M')}",
                            'score': 1.0,
                            'severity': 'high'
                        })
        return anomalies

    def _determine_anomaly_reason(self, row: pd.Series, thresholds: Dict[str, float]) -> str:
        reasons = []
        cat_name = row['type_name']

        if row['amount'] > row['rolling_mean_7d'] * 3:
             reasons.append(f"Cao gấp 3 lần mức chi tiêu trung bình tuần qua")
        elif abs(row['amount_zscore']) > 2:
            reasons.append(f"Khác biệt lớn so với lịch sử chi tiêu '{cat_name}'")

        if abs(row['global_zscore']) > 3:
            reasons.append("Số tiền cực lớn so với thu nhập/chi tiêu chung")

        if row['is_unusual_hour']:
            reasons.append(f"Phát sinh lúc đêm khuya ({row['hour']}h)")

        if row['daily_count'] > thresholds.get('daily_count', 10):
            reasons.append(f"Tần suất giao dịch bất thường ({int(row['daily_count'])} lần/ngày)")

        if not reasons: reasons.append("Hành vi chi tiêu khác biệt so với thói quen")
        
        full_reason = "; ".join(reasons)
        return full_reason[0].upper() + full_reason[1:] if full_reason else "Bất thường không xác định"

    def _determine_severity(self, anomaly_score: float, amount_zscore: float, manual_severity: str = None) -> str:
        if manual_severity: return manual_severity # Ưu tiên mức độ từ Rule-based
        
        combined_score = abs(anomaly_score) + abs(amount_zscore) / 3
        if combined_score > 0.8 or abs(amount_zscore) > 4: return "high"
        elif combined_score > 0.5 or abs(amount_zscore) > 2.5: return "medium"
        else: return "low"

    def detect_anomalies(self, user_id: str, transactions: List[SpendingItem], sensitivity: float = None) -> AnomalyDetectionResponse:
        df = self._extract_features(transactions)
        
        if df.empty or len(df) < 5:
            return AnomalyDetectionResponse(
                success=False, user_id=user_id, total_transactions=len(transactions),
                anomalies_detected=0, anomalies=[], statistics={},
                alerts=["Cần thêm dữ liệu (tối thiểu 5 giao dịch) để AI phân tích."],
                message="Chưa đủ dữ liệu"
            )

        contamination = sensitivity or self.default_contamination
        feature_columns = ['log_amount', 'amount_zscore', 'is_unusual_hour', 'daily_count', 'rolling_mean_7d']
        X = df[feature_columns].values
        X = np.nan_to_num(X, nan=0.0, posinf=0.0, neginf=0.0)
        X_scaled = self.scaler.fit_transform(X)

        iso_forest = IsolationForest(contamination=contamination, random_state=42, n_estimators=100)
        df['anomaly_label'] = iso_forest.fit_predict(X_scaled)
        df['anomaly_score'] = -iso_forest.decision_function(X_scaled)

        score_min, score_max = df['anomaly_score'].min(), df['anomaly_score'].max()
        df['anomaly_score_normalized'] = (df['anomaly_score'] - score_min) / (score_max - score_min) if score_max > score_min else 0.5

        whitelist_mask = (df['is_month_start'] == 1) & (df['type_name'].isin(["Lưu trú & Thuê nhà", "Hóa đơn Điện", "Hóa đơn Nước"]))
        df.loc[whitelist_mask, 'anomaly_label'] = 1 
        df.loc[whitelist_mask, 'anomaly_score_normalized'] = 0.1

        logical_anomalies = self._detect_logical_anomalies(df)
        logical_ids = [item['id'] for item in logical_anomalies]

        ai_anomaly_df = df[(df['anomaly_label'] == -1) & (~df['id'].isin(logical_ids))].copy()
        
        thresholds = {
            'daily_count': df['daily_count'].quantile(0.95),
            'daily_total': df['daily_total'].quantile(0.95)
        }

        final_anomalies = []

        for _, row in ai_anomaly_df.iterrows():
            reason = self._determine_anomaly_reason(row, thresholds)
            sev = self._determine_severity(row['anomaly_score_normalized'], row['amount_zscore'])
            final_anomalies.append(AnomalyTransaction(
                transaction_id=row['id'], money=int(row['money']), type_name=row['type_name'],
                date_time=row['date_time'].strftime('%Y-%m-%d %H:%M'),
                anomaly_score=round(row['anomaly_score_normalized'], 3),
                anomaly_reason=reason, severity=sev
            ))

        for item in logical_anomalies:
            row = df[df['id'] == item['id']].iloc[0]
            final_anomalies.append(AnomalyTransaction(
                transaction_id=item['id'], money=int(row['money']), type_name=row['type_name'],
                date_time=row['date_time'].strftime('%Y-%m-%d %H:%M'),
                anomaly_score=item['score'],
                anomaly_reason=item['reason'], severity=item['severity']
            ))

        sev_order = {'high': 0, 'medium': 1, 'low': 2}
        final_anomalies.sort(key=lambda x: (sev_order[x.severity], -x.anomaly_score))
        
        all_anomaly_ids = [x.transaction_id for x in final_anomalies]
        anomaly_df_combined = df[df['id'].isin(all_anomaly_ids)]
        
        statistics = self._build_statistics(df, anomaly_df_combined)
        
        alerts = self._generate_alerts_advanced(final_anomalies, statistics, df)

        return AnomalyDetectionResponse(
            success=True, user_id=user_id, total_transactions=len(df),
            anomalies_detected=len(final_anomalies), anomalies=final_anomalies,
            statistics=statistics, alerts=alerts,
            message="Phân tích chuyên sâu hoàn tất"
        )

    def _build_statistics(self, df: pd.DataFrame, anomaly_df: pd.DataFrame) -> Dict[str, Any]:
        total_amount = df['amount'].sum()
        anomaly_amount = anomaly_df['amount'].sum() if not anomaly_df.empty else 0
        top_cat = "Không có"
        if not anomaly_df.empty:
            counts = anomaly_df['type_name'].value_counts()
            if len(counts) > 0: top_cat = counts.index[0]
        
        high = len(anomaly_df[anomaly_df['amount_zscore'].abs() > 3])
        med = len(anomaly_df[(anomaly_df['amount_zscore'].abs() > 2) & (anomaly_df['amount_zscore'].abs() <= 3)])
        low = len(anomaly_df) - high - med # Còn lại

        return {
            "totalTransactions": int(len(df)),
            "normalTransactions": int(len(df) - len(anomaly_df)),
            "anomalyRate": float(round(len(anomaly_df) / len(df) * 100, 2)) if len(df) > 0 else 0.0,
            "totalAnomalyAmount": float(round(anomaly_amount, 0)),
            "anomalyAmountPercentage": float(round(anomaly_amount / total_amount * 100, 2)) if total_amount > 0 else 0.0,
            "topAnomalyCategory": str(top_cat),
            "severityDistribution": {"high": int(high), "medium": int(med), "low": int(low)},
            "averageNormalAmount": float(round(df[~df.index.isin(anomaly_df.index)]['amount'].mean(), 0)) if len(df) > len(anomaly_df) else 0.0,
            "averageAnomalyAmount": float(round(anomaly_df['amount'].mean(), 0)) if not anomaly_df.empty else 0.0
        }

    def _generate_alerts_advanced(self, anomalies: List[AnomalyTransaction], stats: Dict[str, Any], df: pd.DataFrame) -> List[str]:
        alerts = []
        
        if not df.empty:
            last_date = df['date_time'].max()
            curr_month_df = df[(df['date_time'].dt.month == last_date.month) & (df['date_time'].dt.year == last_date.year)]
            spent = curr_month_df['amount'].sum()
            day = last_date.day
            if day > 5:
                days_in_month = 31
                projected = (spent / day) * days_in_month
                alerts.append(f"🔮 Dự báo: Bạn có thể tiêu khoảng {int(projected):,}đ tháng này (Hiện tại: {int(spent):,}đ).")

        high_count = stats['severityDistribution']['high']
        if high_count > 0:
            alerts.append(f"⚠️ Có {high_count} giao dịch rủi ro CAO (bao gồm lỗi trùng lặp hoặc chi tiêu đột biến).")

        if stats['anomalyAmountPercentage'] > 30:
            alerts.append(f"💰 Báo động: {stats['anomalyAmountPercentage']}% tiền của bạn đang đi vào các khoản bất thường!")

        top_cat = stats['topAnomalyCategory']
        if top_cat not in ["Không có", "N/A"]:
            alerts.append(f"📌 Chú ý nhóm '{top_cat}': Đang có nhiều biến động nhất tuần qua.")

        if not anomalies and not alerts:
            alerts.append("✅ Tài chính ổn định. Không phát hiện rủi ro hay lỗi trùng lặp nào.")

        return alerts[:5]

isolation_forest_service = IsolationForestService()