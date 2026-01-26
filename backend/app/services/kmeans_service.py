import numpy as np
import pandas as pd
from typing import List, Dict, Any, Optional
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from collections import Counter
from datetime import datetime

from app.schemas.spending import SpendingItem
from app.schemas.response import ClusteringResponse, SpendingCluster
from app.config import settings

class KMeansService:

    ID_TO_KEY_MAPPING = {
        0: "eating", 1: "move", 2: "rent_house", 3: "electricity_bill", 
        4: "fun_play", 5: "shopping", 6: "travel", 7: "beautify",
        8: "invest", 9: "saving", 10: "education",
        11: "physical_examination", 12: "gifts_donations", 13: "charity", 
        14: "other", 15: "necessary_spending"
    }

    CATEGORY_TRANSLATIONS = {
        "eating": "Ẩm thực & Ăn uống", 
        "move": "Giao thông & Di chuyển",
        "rent_house": "Lưu trú & Thuê nhà", 
        "water_money": "Hóa đơn Nước", 
        "electricity_bill": "Hóa đơn Điện", 
        "gas_money": "Nhiên liệu & Khí đốt", 
        "telephone_fee": "Cước Viễn thông",
        "internet_money": "Internet & Dữ liệu", 
        "tv_money": "Truyền hình & Giải trí tại gia",
        "necessary_spending": "Chi tiêu Thiết yếu khác",
        "repair_and_decorate_the_house": "Sửa chữa & Nhà cửa", 
        "vehicle_maintenance": "Bảo dưỡng Phương tiện",
        "housewares": "Vật dụng Gia đình", 
        "personal_belongings": "Tư trang Cá nhân", 
        "pet": "Chăm sóc Thú cưng",
        "family_service": "Dịch vụ Gia đình", 
        "education": "Giáo dục & Đào tạo",
        "physical_examination": "Y tế & Sức khỏe", 
        "insurance": "Bảo hiểm", 
        "fun_play": "Vui chơi & Giải trí",
        "shopping": "Mua sắm",
        "travel": "Du lịch & Trải nghiệm",
        "beautify": "Làm đẹp & Spa", 
        "sport": "Thể thao & Rèn luyện",
        "online_services": "Dịch vụ Số & Subscription",
        "gifts_donations": "Quà tặng & Đối ngoại",
        "charity": "Từ thiện & Xã hội",
        "invest": "Đầu tư Tài sản", 
        "saving": "Tiết kiệm & Tích lũy",
        "borrow": "Vay vốn", 
        "loan": "Cho vay",
        "pay": "Thanh toán Nợ", 
        "pay_interest": "Trả lãi vay", 
        "debt_collection": "Thu hồi nợ", 
        "earn_profit": "Lợi nhuận Đầu tư", 
        "investments_loans_debts": "Tài chính & Tín dụng",
        "salary": "Lương", 
        "revenue": "Doanh thu Kinh doanh", 
        "other_income": "Thu nhập khác", 
        "money_transferred_to": "Tiền nhận về", 
        "money_transferred": "Chuyển tiền đi",
        "other_costs": "Chi phí phát sinh", 
        "new_group": "Nhóm mới", 
        "other": "Khác",
        0: "Ẩm thực", 1: "Di chuyển", 2: "Tiền nhà", 3: "Điện",
        4: "Giải trí", 5: "Mua sắm", 6: "Du lịch", 7: "Làm đẹp", 8: "Đầu tư", 
        10: "Giáo dục", 11: "Y tế", 12: "Hiếu hỉ", 15: "Nhu yếu phẩm"
    }

    CATEGORY_GROUPS = {
        "essential": [
            "eating", "move", "rent_house", "water_money", "electricity_bill",
            "gas_money", "telephone_fee", "internet_money", "tv_money",
            "repair_and_decorate_the_house", "vehicle_maintenance",
            "physical_examination", "insurance", "education",
            "housewares", "personal_belongings", "pet", "family_service",
            "necessary_spending", "Nhu yếu phẩm", 
            0, 1, 2, 3, 11, 15
        ],
        "entertainment": [
            "fun_play", "sport", "beautify", "online_services", "gifts_donations", 
            "travel", "shopping", "charity",
            4, 5, 6, 7, 12, 13
        ],
        "investment": [
            "invest", "borrow", "loan", "pay", "pay_interest",
            "debt_collection", "earn_profit", "investments_loans_debts", 
            "saving", 
            8, 9, 10
        ],
        "income": [
            "salary", "revenue", "other_income", "money_transferred_to"
        ],
        "other": [
            "current_money", "money_transferred", "other_costs", "other", "new_group", 14
        ]
    }

    CLUSTER_PROFILES = {
        "high_value_outliers": {
            "name": "🔥 Khoản Chi Trọng Yếu",
            "description_base": "Nhóm này bao gồm các giao dịch có giá trị rất lớn, mang tính chất đột biến hoặc định kỳ (thuê nhà, mua sắm tài sản lớn). Đây là các khoản tác động mạnh nhất đến dòng tiền hàng tháng.",
            "advice": "Hãy kiểm tra lại tính thiết yếu của các khoản này. Với những khoản mua sắm lớn, hãy áp dụng quy tắc '30 ngày suy ngẫm' trước khi ra quyết định."
        },
        "daily_essentials": {
            "name": "🏠 Sinh Hoạt Phí Cốt Lõi",
            "description_base": "Các khoản chi bắt buộc để duy trì cuộc sống: Ăn uống, đi lại, hóa đơn điện nước. Đây là nền tảng của tháp nhu cầu tài chính.",
            "advice": "Chi phí này khó cắt bỏ nhưng dễ tối ưu. Bạn có thể tiết kiệm bằng cách nấu ăn tại nhà hoặc rà soát lại các gói cước dịch vụ viễn thông."
        },
        "lifestyle_entertainment": {
            "name": "🥂 Phong Cách Sống & Hưởng Thụ",
            "description_base": "Khoản chi cho niềm vui tinh thần, sở thích cá nhân và các mối quan hệ xã hội. Nhóm này giúp cân bằng cuộc sống nhưng dễ gây 'vung tay quá trán'.",
            "advice": "Cố gắng giữ nhóm này dưới 20-30% thu nhập. Hãy đặt hạn mức cụ thể cho việc vui chơi mỗi cuối tuần."
        },
        "micro_spending": {
            "name": "☕ Chi Tiêu Nhỏ Lẻ (Latte Factor)",
            "description_base": "Tập hợp các khoản tiền nhỏ (dưới 50k-100k) nhưng tần suất dày đặc (cà phê, ăn vặt, phí ship). 'Kiến tha lâu cũng đầy tổ' - đây là nơi tiền rò rỉ âm thầm nhất.",
            "advice": "Hãy thử thách bản thân 'Một tuần không chi vặt' và tổng kết lại số tiền giữ được. Bạn sẽ bất ngờ với con số đó đấy."
        },
        "investment_future": {
            "name": "🌱 Tích Lũy & Phát Triển",
            "description_base": "Dòng tiền dành cho tương lai: Tiết kiệm, đầu tư, trả nợ hoặc học tập. Đây là dấu hiệu của sức khỏe tài chính tốt.",
            "advice": "Tuyệt vời! Hãy cố gắng tự động hóa việc này ngay khi nhận lương để duy trì kỷ luật tài chính."
        },
        "mixed_irregular": {
            "name": "🧩 Chi Phí Phát Sinh Khác",
            "description_base": "Các giao dịch hỗn hợp hoặc chưa rõ mục đích. Thường là các tình huống bất ngờ hoặc chi phí không tên.",
            "advice": "Nên có một quỹ dự phòng khẩn cấp (3-6 tháng sinh hoạt phí) để các khoản này không làm đảo lộn kế hoạch tài chính của bạn."
        }
    }

    def __init__(self):
        self.scaler = StandardScaler()

    def _resolve_category_name(self, type_id: int, type_name: Optional[str]) -> str:
        raw_name = str(type_name).strip() if type_name else ""
        
        if raw_name in self.CATEGORY_TRANSLATIONS: 
            return self.CATEGORY_TRANSLATIONS[raw_name]
        
        if type_id in self.CATEGORY_TRANSLATIONS: 
            return self.CATEGORY_TRANSLATIONS[type_id]
        
        if raw_name: 
            return raw_name.replace("_", " ").title()
        
        return "Danh mục Khác"

    def _extract_features(self, transactions: List[SpendingItem]) -> pd.DataFrame:
        data = []
        for t in transactions:
            if t.money >= 0 or t.money == 0: continue 
            if not t.date_time: continue
            
            display_name = self._resolve_category_name(t.type, t.type_name)
            
            original_key = t.type_name if t.type_name else self.ID_TO_KEY_MAPPING.get(t.type, "other")

            dt = t.date_time
            day_of_month = dt.day

            is_start_month = 1 if day_of_month <= 5 else 0
            is_end_month = 1 if day_of_month >= 25 else 0

            data.append({
                'id': t.id, 
                'amount': abs(t.money), 
                'type': t.type,
                'type_name': display_name, 
                'original_key': original_key,
                'date': dt.date(), 
                'hour': dt.hour,
                'day_of_month': day_of_month,
                'weekday': dt.weekday(),
                'is_start_month': is_start_month,
                'is_end_month': is_end_month
            })

        if not data: return pd.DataFrame()
        
        df = pd.DataFrame(data)
        
        df['is_weekend'] = df['weekday'].isin([5, 6]).astype(int)
        
        def check_group(row, group_key):
            group_list = self.CATEGORY_GROUPS.get(group_key, [])
            cond1 = row['original_key'] in group_list
            cond2 = row['type'] in group_list
            return 1 if (cond1 or cond2) else 0

        df['is_essential'] = df.apply(lambda x: check_group(x, 'essential'), axis=1)
        df['is_entertainment'] = df.apply(lambda x: check_group(x, 'entertainment'), axis=1)
        df['is_investment'] = df.apply(lambda x: check_group(x, 'investment'), axis=1)
        
        df['log_amount'] = np.log1p(df['amount'])
        
        return df

    def _get_profile_key_strategy(self, segment_df: pd.DataFrame, full_df: pd.DataFrame) -> str:
        avg_amount = segment_df['amount'].mean()
        overall_avg = full_df['amount'].mean()
        
        essential_ratio = segment_df['is_essential'].mean()
        investment_ratio = segment_df['is_investment'].mean()
        entertainment_ratio = segment_df['is_entertainment'].mean()
        
        if avg_amount > overall_avg * 3.0: 
            return "high_value_outliers"
        
        if investment_ratio > 0.5: 
            return "investment_future"

        if avg_amount < overall_avg * 0.25 or avg_amount < 50000: 
            return "micro_spending"
        
        if essential_ratio > 0.6: 
            return "daily_essentials"
        
        if entertainment_ratio > 0.5: 
            return "lifestyle_entertainment"
        
        return "mixed_irregular"

    def _build_merged_cluster_response(self, profile_key: str, merged_df: pd.DataFrame, full_df: pd.DataFrame, cluster_index: int) -> SpendingCluster:
        base_profile = self.CLUSTER_PROFILES[profile_key]
        
        top_items_counts = merged_df['type_name'].value_counts().head(5)
        keywords_str = ", ".join(top_items_counts.index.tolist()) if not top_items_counts.empty else "Nhiều mục khác nhau"
        top_cats_dict = {str(k): int(v) for k, v in top_items_counts.to_dict().items()}
        
        characteristics = {
            "averageAmount": float(round(merged_df['amount'].mean(), 0)),
            "totalAmount": float(round(merged_df['amount'].sum(), 0)),
            "transactionCount": int(len(merged_df)),
            "essentialRatio": float(round(merged_df['is_essential'].mean() * 100, 1)),
            "topCategories": top_cats_dict
        }
        
        rich_description = (
            f"{base_profile['description_base']}\n\n"
            f"🛒 **Gồm các mục:** {keywords_str}.\n\n" 
            f"💡 **Lời khuyên:** {base_profile['advice']}"
        )

        return SpendingCluster(
            cluster_id=cluster_index,
            cluster_name=base_profile['name'],
            description=rich_description, 
            characteristics=characteristics,
            transaction_ids=merged_df['id'].tolist(),
            percentage=round(len(merged_df) / len(full_df) * 100, 1)
        )

    def cluster_spending(self, user_id: str, transactions: List[SpendingItem], n_clusters: int = None) -> ClusteringResponse:
        df = self._extract_features(transactions)
        
        if df.empty or len(df) < 5:
            return ClusteringResponse(
                success=False, user_id=user_id, clusters=[], user_profile={}, 
                recommendations=["Bạn cần nhập ít nhất 5 giao dịch chi tiêu để hệ thống có đủ dữ liệu phân tích."], 
                message="Dữ liệu chưa đủ"
            )

        n_clusters_calc = max(3, min(6, len(df) // 5))
        
        X_features = df[['log_amount', 'is_weekend', 'is_essential', 'is_entertainment', 'is_investment']].values
        X = self.scaler.fit_transform(X_features)
        
        kmeans = KMeans(n_clusters=n_clusters_calc, random_state=42, n_init=10)
        df['temp_cluster_id'] = kmeans.fit_predict(X)

        merged_groups = {}
        for cid in range(n_clusters_calc):
            segment = df[df['temp_cluster_id'] == cid]
            if segment.empty: continue
            
            p_key = self._get_profile_key_strategy(segment, df)
            merged_groups.setdefault(p_key, []).append(segment)

        final_clusters = []
        for i, (key, segments) in enumerate(merged_groups.items()):
            merged_df = pd.concat(segments)
            final_clusters.append(self._build_merged_cluster_response(key, merged_df, df, i))

        final_clusters.sort(key=lambda x: x.characteristics['totalAmount'], reverse=True)

        return ClusteringResponse(
            success=True, user_id=user_id,
            clusters=final_clusters,
            user_profile=self._build_user_profile(df, final_clusters),
            recommendations=self._generate_recommendations(df, final_clusters),
            message="Phân tích thành công"
        )

    def _determine_spending_style(self, df: pd.DataFrame) -> str:
        total_tx = len(df)
        avg_amt = df['amount'].mean()
        
        invest_ratio = df['is_investment'].mean()
        essential_ratio = df['is_essential'].mean()
        ent_ratio = df['is_entertainment'].mean()
        weekend_ratio = df['is_weekend'].mean()
        
        if invest_ratio > 0.35:
            return "🐺 Sói Già Phố Wall (Nhà đầu tư)"
        
        if essential_ratio > 0.70:
            return "🛡️ Người Quản Gia Thận Trọng"
        
        if ent_ratio > 0.5:
            return "🔥 Tín Đồ Trải Nghiệm (YOLO)"
        
        if weekend_ratio > 0.6:
            return "🎉 Dân Chơi Cuối Tuần"
            
        if total_tx > 40 and avg_amt < 100000: 
            return "🐜 Kiến Tha Lâu (Chi tiêu lặt vặt)"
            
        return "⚖️ Người Cân Bằng Tài Chính"

    def _calculate_financial_health_score(self, df: pd.DataFrame) -> int:
        score = 80 
        total = df['amount'].sum()
        if total == 0: return 50

        ess_pct = df[df['is_essential']==1]['amount'].sum() / total
        ent_pct = df[df['is_entertainment']==1]['amount'].sum() / total
        inv_pct = df[df['is_investment']==1]['amount'].sum() / total

        if ess_pct > 0.6: score -= 10
        if ess_pct > 0.75: score -= 10

        if ent_pct > 0.3: score -= 10
        if ent_pct > 0.5: score -= 15

        if inv_pct > 0.1: score += 5
        if inv_pct > 0.2: score += 10

        return max(10, min(100, score))

    def _build_user_profile(self, df: pd.DataFrame, clusters: List[SpendingCluster]) -> Dict[str, Any]:
        total_spent = float(df['amount'].sum())
        dominant = clusters[0] if clusters else None
        
        return {
            "totalSpent": float(round(total_spent, 0)),
            "averageTransaction": float(round(df['amount'].mean(), 0)),
            "transactionCount": int(len(df)),
            "financialHealthScore": self._calculate_financial_health_score(df),
            "topCategories": {str(k): float(v) for k, v in df.groupby('type_name')['amount'].sum().nlargest(5).to_dict().items()},
            "dominantBehavior": {
                "name": dominant.cluster_name if dominant else "Chưa xác định",
                "percentage": float(round(dominant.characteristics['totalAmount'] / total_spent * 100, 1)) if dominant and total_spent > 0 else 0
            },
            "spendingStyle": self._determine_spending_style(df)
        }

    def _generate_recommendations(self, df: pd.DataFrame, clusters: List[SpendingCluster]) -> List[str]:
        recs = []
        total_spent = df['amount'].sum()
        
        if total_spent <= 0: 
            return ["Dữ liệu trống hoặc không hợp lệ. Hãy nhập giao dịch để nhận tư vấn."]

        ess_df = df[df['is_essential'] == 1]
        ent_df = df[df['is_entertainment'] == 1]
        inv_df = df[df['is_investment'] == 1]

        ess_val = ess_df['amount'].sum()
        ent_val = ent_df['amount'].sum()
        inv_val = inv_df['amount'].sum()

        ess_pct = (ess_val / total_spent) * 100
        ent_pct = (ent_val / total_spent) * 100
        inv_pct = (inv_val / total_spent) * 100

        display_pct = round(ess_pct, 1)

        if ess_pct > 75:
            recs.append(
                f"🛑 **Báo động đỏ:** Chi phí thiết yếu đang vượt quá xa mức an toàn 50%.\n"
                f"- Hành động ngay: Cần rà soát lớn về tiền thuê nhà hoặc các khoản vay cố định.\n"
                f"- Cắt giảm: Tạm dừng toàn bộ các dịch vụ định kỳ chưa cần thiết."
            )
        elif ess_pct > 60:
            recs.append(
                f"🏠 **Cảnh báo chi phí cố định ({display_pct}%):** Bạn đã vượt mức khuyến nghị 50%.\n"
                f"- Lời khuyên: Hãy thử cắt giảm các gói đăng ký dịch vụ (Netflix, Spotify...) hoặc tiền điện nước."
            )
        elif ess_pct > 50:
            recs.append(
                f"⚠️ **Lưu ý nhỏ:** Chi phí thiết yếu ({display_pct}%) đang hơi cao so với mức chuẩn 50%. "
                f"Hãy để ý chi tiêu nhé."
            )

        if ent_pct > 50:
             recs.append(f"💸 **Cân đối lại hưởng thụ:** Hơn một nửa thu nhập ({int(ent_pct)}%) đang dùng cho vui chơi/mua sắm. Hãy cẩn thận, niềm vui ngắn hạn có thể ảnh hưởng đến an toàn tài chính dài hạn.")
        elif ent_pct > 35:
            recs.append(f"⚠️ **Kiểm soát chi tiêu:** Khoản chi cho sở thích đang ở mức {int(ent_pct)}% (Lý tưởng < 30%). Hãy áp dụng quy tắc chờ 24h trước khi chốt đơn các món đồ không quá cần thiết.")
        elif ent_pct < 5 and total_spent > 5000000:
            recs.append(f"🧘 **Chăm sóc bản thân:** Bạn chi rất ít cho bản thân ({int(ent_pct)}%). Một khoản nhỏ để giải trí là khoản đầu tư xứng đáng để tái tạo sức lao động.")

        if inv_pct == 0:
            recs.append("🛑 **Thiếu quỹ dự phòng:** Bạn chưa có khoản nào dành cho tiết kiệm/đầu tư. Hãy bắt đầu trích ít nhất 5-10% thu nhập ngay khi nhận lương.")
        elif inv_pct < 15:
            recs.append(f"📉 **Tăng tốc tích lũy:** Mức tiết kiệm {int(inv_pct)}% là khởi đầu tốt, nhưng hãy cố gắng đẩy lên 20% để đạt tự do tài chính sớm hơn.")

        start_month_amt = df[df['day_of_month'] <= 5]['amount'].sum()
        if (start_month_amt / total_spent) > 0.45:
            recs.append("🗓️ **Hiệu ứng đầu tháng:** Gần 50% tiền của bạn ra đi ngay tuần đầu tiên. Hãy chia nhỏ ngân sách theo tuần để tránh 'cháy túi' vào cuối tháng.")

        weekend_amt = df[df['is_weekend'] == 1]['amount'].sum()
        if (weekend_amt / total_spent) > 0.55:
            recs.append("🎉 **Chi tiêu cuối tuần:** Hơn 50% ngân sách được dùng vào T7-CN. Hãy thử đặt hạn mức cụ thể cho mỗi cuối tuần (ví dụ: tối đa 1-2 triệu).")

        night_rows = df[df['hour'].isin([22, 23, 0, 1, 2, 3, 4])]
        night_amt = night_rows['amount'].sum()
        if night_amt > 0 and (night_amt / total_spent) > 0.15:
            recs.append(f"🦉 **Mua sắm về đêm:** Bạn hay chi tiêu lúc đêm khuya ({int(night_amt/total_spent*100)}% tổng chi). Đây thường là chi tiêu cảm xúc, hãy hạn chế mở app mua sắm sau 10h tối.")

        food_amt = df[df['type_name'].astype(str).str.contains('Ăn|Uống|Food|Drink|Cafe', case=False, na=False)]['amount'].sum()
        if food_amt > 0 and (food_amt / total_spent) > 0.40:
             recs.append(f"🍜 **Ăn uống quá đà:** Chi phí ăn uống chiếm tới {int(food_amt/total_spent*100)}%. Nấu ăn tại nhà hoặc giảm tần suất ăn ngoài sang chảnh sẽ giúp bạn tiết kiệm đáng kể.")

        debt_amt = df[df['type_name'].astype(str).str.contains('Trả nợ|Lãi|Vay', case=False, na=False)]['amount'].sum()
        if debt_amt > 0 and (debt_amt / total_spent) > 0.25:
             recs.append(f"💳 **Gánh nặng nợ nần:** 1/4 dòng tiền của bạn đang dùng để trả nợ. Hãy ưu tiên xử lý dứt điểm các khoản lãi suất cao.")

        micro_cluster = next((c for c in clusters if "Nhỏ Lẻ" in c.cluster_name), None)
        if micro_cluster and micro_cluster.percentage > 30:
            avg_daily_micro = micro_cluster.characteristics['totalAmount']
            yearly_loss = avg_daily_micro * 12 
            yearly_str = "{:,.0f}".format(yearly_loss).replace(",", ".")
            recs.append(f"☕ **Hiệu ứng Latte Factor:** Các khoản chi vặt chiếm {micro_cluster.percentage}% số giao dịch. Nếu xu hướng này kéo dài cả năm, bạn có thể mất khoảng **{yearly_str} VNĐ** cho những thứ không thực sự cần thiết.")

        std_dev = df['amount'].std()
        mean_val = df['amount'].mean()
        if len(df) > 5 and std_dev > mean_val * 3:
            recs.append("📊 **Chi tiêu thất thường:** Có sự chênh lệch rất lớn giữa các khoản chi. Hãy cố gắng chia nhỏ các khoản chi lớn để dòng tiền ổn định hơn.")

        top_cat = df.groupby('type_name')['amount'].sum().nlargest(1)
        if not top_cat.empty:
            cat_name = top_cat.index[0]
            cat_val = top_cat.values[0]
            if (cat_val / total_spent) > 0.45:
                recs.append(f"⚠️ **Mất cân đối danh mục:** Riêng mục '{cat_name}' đã ngốn tới {int(cat_val/total_spent*100)}% tổng tiền. Đây là nơi đầu tiên bạn cần tối ưu.")

        if len(recs) == 0:
            recs.append("🌟 **Quản lý tài chính xuất sắc:** Hồ sơ của bạn cho thấy sự cân bằng tốt giữa các nhóm chi tiêu. Hãy tiếp tục duy trì kỷ luật này!")

        return recs 

kmeans_service = KMeansService()