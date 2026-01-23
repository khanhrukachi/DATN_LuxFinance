import numpy as np
import pandas as pd
from typing import List, Dict, Any
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from collections import Counter

from app.schemas.spending import SpendingItem
from app.schemas.response import ClusteringResponse, SpendingCluster
from app.config import settings


class KMeansService:

    CLUSTER_PROFILES = {
        "high_freq_low_amount": {
            "name": "Chi tiêu thường xuyên",
            "description": "Nhiều giao dịch nhỏ, chi tiêu hàng ngày",
            "icon": "shopping_cart"
        },
        "low_freq_high_amount": {
            "name": "Chi tiêu lớn định kỳ",
            "description": "Ít giao dịch nhưng giá trị cao (tiền nhà, học phí...)",
            "icon": "account_balance"
        },
        "essential_spending": {
            "name": "Chi tiêu thiết yếu",
            "description": "Các khoản chi cần thiết như ăn uống, di chuyển",
            "icon": "restaurant"
        },
        "entertainment_spending": {
            "name": "Chi tiêu giải trí",
            "description": "Mua sắm, giải trí, du lịch",
            "icon": "celebration"
        },
        "mixed_spending": {
            "name": "Chi tiêu hỗn hợp",
            "description": "Đa dạng loại chi tiêu",
            "icon": "category"
        }
    }

    CATEGORY_GROUPS = {
        "essential": [0, 1, 2, 3, 15],
        "entertainment": [4, 5, 6, 7],
        "investment": [8, 9, 10],
        "other": [11, 12, 13, 14]
    }

    INCOME_TYPES = [8, 9, 10]

    def __init__(self):
        self.scaler = StandardScaler()
        self.default_n_clusters = settings.KMEANS_N_CLUSTERS

    def _extract_features(self, transactions: List[SpendingItem]) -> pd.DataFrame:
        data = []
        for t in transactions:
            is_expense = t.money < 0 or (t.money > 0 and t.type not in self.INCOME_TYPES)
            if is_expense:
                data.append({
                    'id': t.id,
                    'amount': abs(t.money),
                    'type': t.type,
                    'type_name': t.type_name,
                    'hour': t.date_time.hour,
                    'weekday': t.date_time.weekday(),
                    'day_of_month': t.date_time.day,
                    'month': t.date_time.month
                })

        if not data:
            return pd.DataFrame()

        df = pd.DataFrame(data)

        df['is_weekend'] = df['weekday'].isin([5, 6]).astype(int)
        df['is_morning'] = df['hour'].between(6, 11).astype(int)
        df['is_afternoon'] = df['hour'].between(12, 17).astype(int)
        df['is_evening'] = df['hour'].between(18, 23).astype(int)
        df['is_early_month'] = (df['day_of_month'] <= 10).astype(int)
        df['is_mid_month'] = df['day_of_month'].between(11, 20).astype(int)
        df['is_late_month'] = (df['day_of_month'] > 20).astype(int)

        df['is_essential'] = df['type'].isin(self.CATEGORY_GROUPS['essential']).astype(int)
        df['is_entertainment'] = df['type'].isin(self.CATEGORY_GROUPS['entertainment']).astype(int)

        df['log_amount'] = np.log1p(df['amount'])
        df['amount_normalized'] = df['amount'] / df['amount'].max() if df['amount'].max() > 0 else 0

        return df

    def _determine_cluster_profile(self, cluster_data: pd.DataFrame, all_data: pd.DataFrame) -> Dict[str, Any]:
        avg_amount = cluster_data['amount'].mean()
        total_amount = cluster_data['amount'].sum()
        transaction_count = len(cluster_data)
        overall_avg = all_data['amount'].mean()

        essential_ratio = cluster_data['is_essential'].mean()
        entertainment_ratio = cluster_data['is_entertainment'].mean()
        weekend_ratio = cluster_data['is_weekend'].mean()

        if avg_amount > overall_avg * 2:
            profile_key = "low_freq_high_amount"
        elif transaction_count > len(all_data) * 0.3 and avg_amount < overall_avg:
            profile_key = "high_freq_low_amount"
        elif essential_ratio > 0.6:
            profile_key = "essential_spending"
        elif entertainment_ratio > 0.4:
            profile_key = "entertainment_spending"
        else:
            profile_key = "mixed_spending"

        profile = self.CLUSTER_PROFILES[profile_key].copy()

        top_categories = cluster_data['type_name'].value_counts().head(3).to_dict()
        top_categories = {str(k): int(v) for k, v in top_categories.items()}

        profile['characteristics'] = {
            "averageAmount": float(round(avg_amount, 0)),
            "totalAmount": float(round(total_amount, 0)),
            "transactionCount": int(transaction_count),
            "essentialRatio": float(round(essential_ratio * 100, 1)),
            "entertainmentRatio": float(round(entertainment_ratio * 100, 1)),
            "weekendRatio": float(round(weekend_ratio * 100, 1)),
            "topCategories": top_categories
        }

        return profile

    def cluster_spending(
        self,
        user_id: str,
        transactions: List[SpendingItem],
        n_clusters: int = None
    ) -> ClusteringResponse:
        df = self._extract_features(transactions)

        if df.empty or len(df) < 5:
            return ClusteringResponse(
                success=False,
                user_id=user_id,
                clusters=[],
                user_profile={},
                recommendations=["Cần ít nhất 5 giao dịch chi tiêu để phân tích hành vi."],
                message="Insufficient data for clustering"
            )

        n_clusters = n_clusters or min(self.default_n_clusters, max(2, len(df) // 3))
        n_clusters = max(2, min(n_clusters, min(6, len(df) // 2)))

        feature_columns = [
            'log_amount', 'is_weekend', 'is_morning', 'is_afternoon', 'is_evening',
            'is_early_month', 'is_mid_month', 'is_late_month',
            'is_essential', 'is_entertainment'
        ]
        X = df[feature_columns].values
        X_scaled = self.scaler.fit_transform(X)

        kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
        df['cluster'] = kmeans.fit_predict(X_scaled)

        clusters = []
        for cluster_id in range(n_clusters):
            cluster_data = df[df['cluster'] == cluster_id]
            profile = self._determine_cluster_profile(cluster_data, df)

            clusters.append(SpendingCluster(
                cluster_id=cluster_id,
                cluster_name=profile['name'],
                description=profile['description'],
                characteristics=profile['characteristics'],
                transaction_ids=cluster_data['id'].tolist(),
                percentage=round(len(cluster_data) / len(df) * 100, 1)
            ))

        clusters.sort(key=lambda x: x.percentage, reverse=True)

        user_profile = self._build_user_profile(df, clusters)
        recommendations = self._generate_recommendations(df, clusters)

        return ClusteringResponse(
            success=True,
            user_id=user_id,
            clusters=clusters,
            user_profile=user_profile,
            recommendations=recommendations,
            message="Phân tích hành vi chi tiêu thành công"
        )

    def _build_user_profile(self, df: pd.DataFrame, clusters: List[SpendingCluster]) -> Dict[str, Any]:
        total_spent = float(df['amount'].sum())
        avg_transaction = float(df['amount'].mean())
        transaction_count = int(len(df))

        category_dist = df.groupby('type_name')['amount'].sum().sort_values(ascending=False)
        top_categories = {str(k): float(v) for k, v in category_dist.head(5).to_dict().items()}

        weekday_spending = float(df[df['is_weekend'] == 0]['amount'].sum())
        weekend_spending = float(df[df['is_weekend'] == 1]['amount'].sum())

        dominant_cluster = clusters[0] if clusters else None

        return {
            "totalSpent": float(round(total_spent, 0)),
            "averageTransaction": float(round(avg_transaction, 0)),
            "transactionCount": transaction_count,
            "topCategories": top_categories,
            "weekdayVsWeekend": {
                "weekday": float(round(weekday_spending, 0)),
                "weekend": float(round(weekend_spending, 0)),
                "weekendRatio": float(round(weekend_spending / total_spent * 100, 1)) if total_spent > 0 else 0.0
            },
            "dominantBehavior": {
                "name": dominant_cluster.cluster_name if dominant_cluster else "N/A",
                "percentage": float(dominant_cluster.percentage) if dominant_cluster else 0.0
            },
            "spendingStyle": self._determine_spending_style(df)
        }

    def _determine_spending_style(self, df: pd.DataFrame) -> str:
        essential_ratio = df['is_essential'].mean()
        entertainment_ratio = df['is_entertainment'].mean()
        avg_amount = df['amount'].mean()
        median_amount = df['amount'].median()

        if essential_ratio > 0.7:
            return "Tiết kiệm - Tập trung vào chi tiêu thiết yếu"
        elif entertainment_ratio > 0.4:
            return "Hưởng thụ - Chi nhiều cho giải trí và mua sắm"
        elif avg_amount > median_amount * 2:
            return "Biến động - Chi tiêu không đều, có các khoản lớn"
        else:
            return "Cân bằng - Chi tiêu đa dạng và ổn định"

    def _generate_recommendations(self, df: pd.DataFrame, clusters: List[SpendingCluster]) -> List[str]:
        recommendations = []

        entertainment_ratio = df['is_entertainment'].mean()
        essential_ratio = df['is_essential'].mean()
        weekend_ratio = df['is_weekend'].mean()

        if entertainment_ratio > 0.35:
            recommendations.append(
                "Chi tiêu giải trí chiếm tỷ lệ cao. Cân nhắc đặt ngân sách cụ thể cho mục này."
            )

        if essential_ratio < 0.3:
            recommendations.append(
                "Tỷ lệ chi tiêu thiết yếu thấp. Hãy đảm bảo ghi nhận đầy đủ các khoản chi hàng ngày."
            )

        if weekend_ratio > 0.4:
            recommendations.append(
                "Chi tiêu cuối tuần cao hơn bình thường. Lập kế hoạch trước cho các hoạt động cuối tuần."
            )

        for cluster in clusters:
            if "lớn" in cluster.cluster_name.lower() and cluster.percentage > 20:
                recommendations.append(
                    "Có nhiều giao dịch giá trị lớn. Xem xét chia nhỏ hoặc lập quỹ dự phòng."
                )
                break

        if not recommendations:
            recommendations.append(
                "Hành vi chi tiêu của bạn khá cân bằng. Tiếp tục duy trì và theo dõi định kỳ."
            )

        return recommendations[:4]


kmeans_service = KMeansService()
