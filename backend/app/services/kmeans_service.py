from .admin_evaluation_capture import record_analysis
import numpy as np
import pandas as pd
from typing import List, Dict, Any, Optional
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import silhouette_score
from collections import Counter
from datetime import datetime
from types import SimpleNamespace
import unicodedata
import math

from app.schemas.spending import SpendingItem
from app.schemas.response import ClusteringResponse, SpendingCluster
from app.config import settings
from .category_taxonomy import build_catalog, resolve_category_metadata, summarize_category_hierarchy


def _field(obj, *names, default=None):
    for name in names:
        value = obj.get(name) if isinstance(obj, dict) else getattr(obj, name, None)
        if value is not None:
            return value
    return default

def _normalize_transactions(transactions, reference_date=None, category_catalog=None):
    """Preserve clock time, Vietnam timezone, signed money and explicit transfer flags.
    No category-ID mapping is guessed: the application owns that mapping.
    Returns normalized objects plus diagnostics; does not mutate caller records.
    """
    category_catalog = build_catalog(category_catalog)
    cutoff = pd.Timestamp(reference_date) if reference_date is not None else pd.Timestamp.now(tz='Asia/Ho_Chi_Minh')
    if cutoff.tzinfo is not None:
        cutoff = cutoff.tz_convert('Asia/Ho_Chi_Minh').tz_localize(None)
    cutoff = cutoff.normalize() + pd.Timedelta(days=1)
    result, seen = [], set()
    diagnostics = {'invalid': 0, 'duplicates': 0, 'future': 0, 'transfers': 0}
    for index, tx in enumerate(transactions or []):
        try:
            raw_money = _field(tx, 'money', 'amount')
            if isinstance(raw_money, bool):
                raise ValueError('Invalid money')
            money = float(raw_money)
            if not math.isfinite(money) or money == 0:
                raise ValueError('Invalid money')
            dt = pd.Timestamp(_field(tx, 'date_time', 'dateTime', 'date'))
            if pd.isna(dt):
                raise ValueError('Invalid date')
            if dt.tzinfo is not None:
                dt = dt.tz_convert('Asia/Ho_Chi_Minh').tz_localize(None)
            if dt >= cutoff:
                diagnostics['future'] += 1
                continue
            if _field(tx,'is_transfer','isTransfer',default=False) is True:
                diagnostics['transfers'] += 1
                continue
            exp, inc = _field(tx,'is_expense','isExpense'), _field(tx,'is_income','isIncome')
            if exp is True and inc is True:
                raise ValueError('Conflicting flags')
            if exp is True:
                money = -abs(money)
            elif inc is True:
                money = abs(money)
            tid = str(_field(tx,'id',default='') or '')
            if tid and tid in seen:
                diagnostics['duplicates'] += 1
                continue
            if tid:
                seen.add(tid)
            raw_type = _field(tx,'type',default=-1)
            try:
                type_id = int(raw_type)
            except (TypeError, ValueError):
                type_id = -1
            category = resolve_category_metadata(tx, category_catalog)
            result.append(SimpleNamespace(id=tid or f'generated-{index}', money=money,
                type=type_id, type_name=str(category['category_name'] or 'other'),
                category_id=category['category_id'],
                parent_category_id=category['parent_category_id'],
                category_group_id=category['category_group_id'],
                category_group_name=category['category_group_name'],
                category_path_ids=category['category_path_ids'],
                category_path=category['category_path'],
                category_level=category['category_level'],
                is_parent_category=category['is_parent_category'],
                financial_role=category['financial_role'],
                category_class=category['category_class'],
                is_essential=category['is_essential'],
                is_consumption_expense=category['is_consumption_expense'],
                date_time=dt.to_pydatetime(), note=str(_field(tx,'note',default='') or ''),
                merchant=str(_field(tx,'merchant','payee',default='') or ''),
                source=str(_field(tx,'source',default='') or ''),
                user_confirmed=_field(tx,'user_confirmed','userConfirmed',default=None),
                classification_confidence=_field(tx,'classification_confidence','classificationConfidence','confidence',default=None),
                payment_method=str(_field(tx,'payment_method','paymentMethod',default='') or ''),
                chat_intent=str(_field(tx,'chat_intent','chatIntent',default='') or ''),
                recurrence_id=str(_field(tx,'recurrence_id','recurrenceId',default='') or ''),
                is_expense=money<0, is_income=money>0,
                planned=_field(tx,'planned','isPlanned',default=False) is True))
        except (TypeError, ValueError, OverflowError):
            diagnostics['invalid'] += 1
    return sorted(result, key=lambda t:t.date_time), diagnostics

def _category_key(name):
    def norm(v):
        return ''.join(c for c in unicodedata.normalize('NFD',str(v).lower().replace('đ','d'))
                       if unicodedata.category(c)!='Mn').replace('&',' ').replace('_',' ').strip()
    key = norm(name)
    aliases = {'an uong':'eating','di chuyen':'move','di lai':'move','thue nha':'rent_house',
        'tien nha':'rent_house','tien dien':'electricity_bill','dien':'electricity_bill',
        'mua sam':'shopping','giai tri':'fun_play','vui choi':'fun_play',
        'hoc phi':'education','hoc tap':'education','y te':'physical_examination',
        'kham benh':'physical_examination','tiet kiem':'saving','luong':'salary',
        'food':'eating','transport':'move','entertainment':'fun_play','rent':'rent_house'}
    if key in aliases:
        return aliases[key]
    for canonical, label in KMeansService.CATEGORY_TRANSLATIONS.items():
        if isinstance(canonical,str) and key in (norm(canonical),norm(label)):
            return canonical
    return str(name).strip() or 'other'


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

    # Interpretation thresholds are explicit heuristics, not model confidence.
    PROFILE_VERSION = 'evidence_v2'
    PROFILE_MIN_COUNT_SHARE = 0.60
    PROFILE_MIN_AMOUNT_SHARE = 0.60

    CLUSTER_PROFILES = {
        'fixed_obligations': {'name': 'Chi phí cố định', 'description_base': 'Phần lớn giao dịch và số tiền thuộc các danh mục chi phí cố định.'},
        'daily_essentials': {'name': 'Chi sinh hoạt', 'description_base': 'Phần lớn giao dịch và số tiền thuộc sinh hoạt hoặc nhu cầu thiết yếu đã phân loại.'},
        'lifestyle_entertainment': {'name': 'Vui chơi và dịch vụ cá nhân', 'description_base': 'Phần lớn giao dịch và số tiền thuộc các danh mục vui chơi, làm đẹp, thể thao hoặc dịch vụ cá nhân được nhận diện.'},
        'investment_future': {'name': 'Đầu tư', 'description_base': 'Phần lớn giao dịch và số tiền được ghi nhận là đóng góp đầu tư; không tự xác định hiệu quả hoặc lợi nhuận.'},
        'savings_contributions': {'name': 'Tiết kiệm', 'description_base': 'Phần lớn giao dịch và số tiền được ghi nhận là chuyển vào tiết kiệm.'},
        'education_development': {'name': 'Giáo dục', 'description_base': 'Phần lớn giao dịch và số tiền thuộc giáo dục; không gộp học phí thành khoản đầu tư tài chính.'},
        'insurance_protection': {'name': 'Bảo hiểm', 'description_base': 'Phần lớn giao dịch và số tiền thuộc bảo hiểm; chưa suy ra phạm vi hoặc mức độ bảo vệ.'},
        'debt_management': {'name': 'Dòng tiền vay và nợ', 'description_base': 'Phần lớn giao dịch và số tiền thuộc các vai trò vay/nợ đã ghi nhận; cần xem riêng gốc, lãi và cho vay.'},
        'high_value_outliers': {'name': 'Giao dịch giá trị cao', 'description_base': 'Trung vị số tiền của cụm cao so với phân bố giao dịch của chính người dùng trong phạm vi phân tích. Đây không phải kết luận bất thường.'},
        'micro_spending': {'name': 'Giao dịch giá trị thấp', 'description_base': 'Trung vị số tiền của cụm thấp so với phân bố giao dịch của chính người dùng. Không suy ra lãng phí hoặc tần suất chi dày đặc.'},
        'mixed_irregular': {'name': 'Giao dịch đa mục đích', 'description_base': 'Chưa có một nhóm mục đích chiếm đồng thời ít nhất 60% số giao dịch và 60% số tiền. Không mặc định là chi phí đột xuất.'},
    }

    def _profile_evidence(self, segment_df, full_df):
        """Explain clusters using observed purpose, robust amount and time summaries.

        Only reads fitted frames; it never changes features, assignments or K.
        Categories describe recorded purpose, not necessity, affordability or intent.
        """
        keys = segment_df['original_key'].astype(str)
        roles = segment_df['financial_role'].astype(str)
        def flag(name):
            return segment_df[name].fillna(0).astype(bool)
        masks = {
            'debt_management': flag('is_debt') | keys.isin(['borrow', 'loan', 'pay', 'pay_interest', 'debt_collection']) | roles.isin(['borrowed_principal', 'lending_principal', 'borrowing', 'lending', 'debt_repayment', 'debt_interest', 'debt_collection']),
            'savings_contributions': flag('is_saving') | keys.eq('saving'),
            'investment_future': flag('is_investment') | keys.eq('invest'),
            'education_development': keys.eq('education') | roles.eq('education_expense'),
            'insurance_protection': keys.eq('insurance') | roles.eq('insurance_expense'),
            'fixed_obligations': flag('is_fixed') | keys.isin(['rent_house', 'water_money', 'electricity_bill', 'internet_money', 'tv_money']),
            'lifestyle_entertainment': keys.isin(['fun_play', 'sport', 'beautify', 'online_services', 'travel']),
            'daily_essentials': flag('is_living') | flag('is_essential'),
        }
        # Count each transaction in at most one interpretation family.
        used = pd.Series(False, index=segment_df.index)
        shares = {}
        amount_total = float(segment_df['amount'].sum())
        for name, raw_mask in masks.items():
            mask = raw_mask & ~used
            used = used | mask
            shares[name] = {'transactionCount': int(mask.sum()),
                            'countShare': float(mask.mean()),
                            'amountShare': float(segment_df.loc[mask, 'amount'].sum() / amount_total) if amount_total else 0.0}
        dominant = next((key for key, value in shares.items()
                         if value['countShare'] >= self.PROFILE_MIN_COUNT_SHARE
                         and value['amountShare'] >= self.PROFILE_MIN_AMOUNT_SHARE), None)
        median = float(segment_df['amount'].median())
        overall_median = float(full_df['amount'].median())
        q25 = float(full_df['amount'].quantile(.25))
        q75 = float(full_df['amount'].quantile(.75))
        if median >= q75 and median >= 2 * max(overall_median, 1):
            amount_band = 'cao'
        elif median <= q25 and median <= .5 * max(overall_median, 1):
            amount_band = 'thấp'
        else:
            amount_band = 'trong khoảng phổ biến'
        if dominant is None:
            dominant = {'cao': 'high_value_outliers', 'thấp': 'micro_spending'}.get(amount_band, 'mixed_irregular')
        bands = pd.cut(segment_df['hour'], bins=[-1, 5, 11, 17, 23],
                       labels=['đêm (00–05h)', 'buổi sáng (06–11h)', 'buổi chiều (12–17h)', 'buổi tối (18–23h)'])
        time_counts = bands.value_counts()
        top_time = str(time_counts.index[0]) if len(time_counts) else 'nhiều khung giờ'
        top_time_share = float(time_counts.iloc[0] / len(segment_df)) if len(time_counts) else 0.0
        return {'profileKey': dominant, 'profileVersion': self.PROFILE_VERSION,
                'purposeShares': shares, 'unclassifiedPurposeCount': int((~used).sum()),
                'medianAmount': median, 'minimumAmount': float(segment_df['amount'].min()),
                'maximumAmount': float(segment_df['amount'].max()),
                'referenceMedianAmount': overall_median,
                'relativeAmountBand': amount_band,
                'dominantTimeBand': top_time if top_time_share >= .60 else 'nhiều khung giờ',
                'dominantTimeShare': top_time_share,
                'activeDays': int(segment_df['date'].nunique()),
                'weekendRatio': float(segment_df['is_weekend'].mean() * 100),
                'countThreshold': self.PROFILE_MIN_COUNT_SHARE,
                'amountThreshold': self.PROFILE_MIN_AMOUNT_SHARE,
                'meaning': 'rule_based_interpretation_not_ground_truth_or_model_confidence'}

    def _get_profile_key_strategy(self, segment_df: pd.DataFrame, full_df: pd.DataFrame) -> str:
        return self._profile_evidence(segment_df, full_df)['profileKey']

    def _build_merged_cluster_response(self, profile_key: str, merged_df: pd.DataFrame, full_df: pd.DataFrame, cluster_index: int) -> SpendingCluster:
        evidence = self._profile_evidence(merged_df, full_df)
        profile_key = evidence['profileKey']
        base_profile = self.CLUSTER_PROFILES[profile_key]
        category_counts = merged_df['type_name'].value_counts()
        top_cats_dict = {str(k): int(v) for k, v in category_counts.head(5).items()}
        category_amounts = merged_df.groupby('type_name')['amount'].sum().sort_values(ascending=False)
        top_by_amount = {str(k): float(v) for k, v in category_amounts.head(5).items()}
        names = list(top_cats_dict)
        # A single category label only when it dominates both count and cash.
        first = names[0] if names else 'Chưa rõ danh mục'
        total = float(merged_df['amount'].sum())
        single_dominates = (bool(names) and top_cats_dict[first] / len(merged_df) >= .60
                            and float(category_amounts.get(first, 0)) / max(total, 1) >= .60)
        label_categories = first if single_dominates else ' / '.join(names[:2])
        characteristics = {
            'averageAmount': float(round(merged_df['amount'].mean(), 0)),
            'totalAmount': float(round(total, 0)),
            'transactionCount': int(len(merged_df)),
            'essentialRatio': float(round(merged_df['is_essential'].mean() * 100, 1)),
            'livingRatio': float(round(merged_df['is_living'].mean() * 100, 1)),
            'fixedRatio': float(round(merged_df['is_fixed'].mean() * 100, 1)),
            'unexpectedRatio': float(round(merged_df['is_unexpected'].mean() * 100, 1)),
            'investmentRatio': float(round(merged_df['is_investment'].mean() * 100, 1)),
            'savingRatio': float(round(merged_df['is_saving'].mean() * 100, 1)),
            'debtRatio': float(round(merged_df['is_debt'].mean() * 100, 1)),
            'topCategories': top_cats_dict, 'topCategoriesByAmount': top_by_amount,
            'amountPercentage': round(total / max(float(full_df['amount'].sum()), 1) * 100, 1),
            'medianAmount': float(round(evidence['medianAmount'], 0)),
            'activeDays': evidence['activeDays'],
            'profileKey': profile_key, 'profileVersion': self.PROFILE_VERSION,
            'profileEvidence': evidence,
            'categoryGroups': {
                str(group_id): {'name': str(group['category_group_name'].iloc[0]),
                                'transactionCount': int(len(group)),
                                'cashOutflow': float(round(group['amount'].sum(), 0))}
                for group_id, group in merged_df.groupby('category_group_id')},
            'financialRoles': {str(role): int(count) for role, count in merged_df['financial_role'].value_counts().items()},
        }
        category_text = ', '.join(f'{name}: {count} GD' for name, count in top_cats_dict.items())
        purpose = evidence['purposeShares'].get(profile_key)
        basis = (f"Nhóm mục đích này chiếm {purpose['countShare'] * 100:.1f}% số giao dịch "
                 f"và {purpose['amountShare'] * 100:.1f}% số tiền trong cụm. " if purpose else '')
        sample_note = ' Cụm có dưới 3 giao dịch; diễn giải còn hạn chế.' if len(merged_df) < 3 else ''
        description = (
            f"{base_profile['description_base']} {basis}"
            f"{len(merged_df)} giao dịch trên {evidence['activeDays']} ngày có ghi nhận; "
            f"tổng {total:,.0f}đ, trung vị {evidence['medianAmount']:,.0f}đ/GD "
            f"(trung vị toàn bộ {evidence['referenceMedianAmount']:,.0f}đ/GD). "
            f"Danh mục theo số giao dịch: {category_text}. "
            f"Khung giờ: {evidence['dominantTimeBand']}. "
            'Tỷ trọng cụm tính theo số giao dịch; tỷ trọng tiền nằm ở amountPercentage. '
            'Nhãn là diễn giải theo quy tắc, không kết luận bất thường, lãng phí hay khả năng chi trả.'
            + sample_note)
        return SpendingCluster(cluster_id=cluster_index,
                               cluster_name=f"{base_profile['name']} · {label_categories}",
                               description=description, characteristics=characteristics,
                               transaction_ids=merged_df['id'].tolist(),
                               percentage=round(len(merged_df) / len(full_df) * 100, 1))

    def _disambiguate_cluster_names(self, clusters):
        """Preserve real K-Means groups; distinguish similar profiles honestly."""
        groups = {}
        for cluster in clusters:
            groups.setdefault(cluster.cluster_name, []).append(cluster)
        for same_name in groups.values():
            if len(same_name) <= 1:
                continue
            for cluster in same_name:
                evidence = cluster.characteristics['profileEvidence']
                cluster.cluster_name += f" · {evidence['dominantTimeBand']} · trung vị {evidence['medianAmount']:,.0f}đ"
        # Identical summaries are possible. An explicit run-local ID is honest;
        # inventing a different behavior would not be supported by the data.
        counts = Counter(cluster.cluster_name for cluster in clusters)
        for cluster in clusters:
            if counts[cluster.cluster_name] > 1:
                cluster.cluster_name += f' · cụm {cluster.cluster_id + 1}'
                cluster.description += ' Có cụm khác cùng tóm tắt; mã cụm chỉ phân biệt trong lần chạy này.'


    def __init__(self):
        self.scaler = StandardScaler()

    def _resolve_category_name(self, type_id, type_name):
        key = _category_key(type_name or 'other')
        return str(self.CATEGORY_TRANSLATIONS.get(key, type_name or 'Khác'))

    def _extract_features(self, transactions: List[SpendingItem]) -> pd.DataFrame:
        data = []
        for t in transactions:
            if t.money >= 0 or t.money == 0: continue 
            if not t.date_time: continue
            
            display_name = self._resolve_category_name(t.type, t.type_name)
            
            original_key = _category_key(getattr(t, 'category_id', '') or t.type_name or "other")
            category_class = str(getattr(t, 'category_class', 'unclassified'))
            financial_role = str(getattr(t, 'financial_role', 'unclassified'))

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
                'category_id': str(getattr(t, 'category_id', '') or original_key),
                'parent_category_id': str(getattr(t, 'parent_category_id', '') or ''),
                'category_group_id': str(getattr(t, 'category_group_id', 'unclassified')),
                'category_group_name': str(getattr(t, 'category_group_name', 'Chưa phân loại')),
                'category_class': category_class,
                'financial_role': financial_role,
                'is_essential': int(bool(getattr(t, 'is_essential', False))),
                'is_living': int(category_class == 'living_expense'),
                'is_fixed': int(category_class in ('fixed_expense', 'fixed_cost')),
                'is_unexpected': int(category_class == 'unexpected_expense'),
                'is_investment': int(financial_role == 'investment_contribution' or category_class == 'investment'),
                'is_saving': int(financial_role == 'savings_transfer' or category_class == 'saving'),
                'is_debt': int(category_class in ('debt', 'debt_repayment', 'debt_cost', 'borrowing', 'lending', 'debt_collection')),
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
        
        # The stable parent/role fields are the source of truth. Legacy category
        # name matching is only used when a transaction has no hierarchy metadata.
        has_hierarchy = df['category_group_id'] != 'unclassified'
        legacy_essential = (
            df['original_key'].isin(self.CATEGORY_GROUPS.get('essential', [])) & ~has_hierarchy
        ).astype(int)
        df['is_essential'] = np.maximum(df['is_essential'], legacy_essential)
        df['is_entertainment'] = (
            df['original_key'].isin(self.CATEGORY_GROUPS.get('entertainment', [])) & ~has_hierarchy
        ).astype(int)
        df['is_investment'] = np.maximum(
            df['is_investment'],
            (df['original_key'].eq('invest') & ~has_hierarchy).astype(int),
        )
        
        df['log_amount'] = np.log1p(df['amount'])

        # Cyclical time encoding: 23:00 and 00:00 / Sunday and Monday are close in time.
        df['hour_sin'] = np.sin(2 * np.pi * df['hour'] / 24.0)
        df['hour_cos'] = np.cos(2 * np.pi * df['hour'] / 24.0)
        df['weekday_sin'] = np.sin(2 * np.pi * df['weekday'] / 7.0)
        df['weekday_cos'] = np.cos(2 * np.pi * df['weekday'] / 7.0)

        # Relative spending features make clustering personalized to each user.
        user_avg = max(float(df['amount'].mean()), 1.0)
        df['amount_vs_user_avg'] = df['amount'] / user_avg

        category_avg = df.groupby('original_key')['amount'].transform('mean').replace(0, np.nan)
        df['amount_vs_category_avg'] = (df['amount'] / category_avg).replace([np.inf, -np.inf], np.nan).fillna(1.0)

        # Frequency/context features. Values are ratios so they remain comparable across users.
        category_counts = df.groupby('original_key')['id'].transform('count')
        df['category_frequency'] = category_counts / max(len(df), 1)
        daily_counts = df.groupby('date')['id'].transform('count')
        df['daily_frequency'] = daily_counts / max(float(daily_counts.max()), 1.0)

        return df



    def _select_optimal_k(self, X, requested_k=None):
        n, unique = len(X), len(np.unique(X, axis=0))
        if n < 3 or unique < 2:
            return 1, 0.0
        maximum = min(6, n - 1, unique, max(2, n // 8))
        if requested_k is not None:
            if isinstance(requested_k, bool) or int(requested_k) != float(requested_k) or int(requested_k) < 1:
                raise ValueError('n_clusters phải là số nguyên dương')
            choices = [min(int(requested_k), n - 1, unique)]
        else:
            choices = range(2, maximum + 1)
        best_k, best_score = 1, -1.0
        for k in choices:
            if k == 1:
                return 1, 0.0
            labels = KMeans(n_clusters=k, random_state=42, n_init=10).fit_predict(X)
            if not 1 < len(np.unique(labels)) < n:
                continue
            score = float(silhouette_score(X, labels, sample_size=min(n, 2000), random_state=42))
            if score > best_score:
                best_k, best_score = k, score
        return best_k, best_score if best_k > 1 else 0.0

    @record_analysis('K-Means')
    def cluster_spending(self, user_id: str, transactions: List[SpendingItem], n_clusters: int = None,
                         year: Optional[int] = None, month: Optional[int] = None,
                         reference_date=None, category_catalog=None) -> ClusteringResponse:
        normalized, diagnostics = _normalize_transactions(transactions, reference_date, category_catalog)
        if (year is None) != (month is None):
            raise ValueError('Phải truyền đồng thời year và month')
        if year is not None:
            if isinstance(year, bool) or isinstance(month, bool) or int(year)!=float(year) or int(month)!=float(month):
                raise ValueError('year/month phải là số nguyên')
            datetime(int(year), int(month), 1)
            normalized = [t for t in normalized if (t.date_time.year,t.date_time.month)==(int(year),int(month))]
        df = self._extract_features(normalized)

        # K-Means on very small samples is unstable. Keep a conservative minimum.
        if df.empty or len(df) < 10:
            return ClusteringResponse(
                success=False, user_id=user_id, clusters=[],
                user_profile={"categoryAnalysis": summarize_category_hierarchy(normalized),
                              "kMeans": {"modelReady": False, "minimumTransactions": 10,
                                         "sampleSize": int(len(df))}},
                recommendations=[
                    "Bạn cần ít nhất 10 giao dịch chi tiêu để hệ thống bắt đầu phân tích hành vi. "
                    "Từ 30 giao dịch trở lên, kết quả thường có ý nghĩa hơn."
                ],
                message="Dữ liệu chưa đủ"
            )

        feature_columns = [
            'log_amount',
            'hour_sin', 'hour_cos',
            'weekday_sin', 'weekday_cos',
            'is_weekend', 'is_start_month', 'is_end_month',
            'amount_vs_user_avg', 'amount_vs_category_avg',
            'category_frequency', 'daily_frequency',
            'is_essential', 'is_entertainment', 'is_investment',
            'is_living', 'is_fixed', 'is_unexpected', 'is_saving', 'is_debt',
        ]

        X_features = df[feature_columns].replace([np.inf, -np.inf], np.nan).fillna(0.0).values
        X = StandardScaler().fit_transform(X_features)

        best_k, silhouette = self._select_optimal_k(X, n_clusters)
        kmeans = KMeans(n_clusters=best_k, random_state=42, n_init=10)
        df['temp_cluster_id'] = kmeans.fit_predict(X)

        # IMPORTANT: keep every K-Means cluster. We interpret it, but do not merge it
        # back into hand-written groups, otherwise useful behavior patterns are lost.
        final_clusters = []
        for cid in range(best_k):
            segment = df[df['temp_cluster_id'] == cid].copy()
            if segment.empty:
                continue
            profile_key = self._get_profile_key_strategy(segment, df)
            final_clusters.append(
                self._build_merged_cluster_response(profile_key, segment, df, cid)
            )

        self._disambiguate_cluster_names(final_clusters)
        final_clusters.sort(
            key=lambda x: x.characteristics['totalAmount'], reverse=True
        )

        user_profile = self._build_user_profile(df, final_clusters)
        user_profile['categoryAnalysis'] = summarize_category_hierarchy(normalized)
        user_profile['profileInterpretation'] = {
            'version': self.PROFILE_VERSION,
            'method': 'purpose_count_and_amount_shares_then_relative_median',
            'countThreshold': self.PROFILE_MIN_COUNT_SHARE,
            'amountThreshold': self.PROFILE_MIN_AMOUNT_SHARE,
            'meaning': 'descriptive_heuristic_not_verified_behavior',
            'clusterIdsStableAcrossRuns': False,
        }
        # Add ML diagnostics without changing the response schema.
        user_profile['kMeans'] = {
            'optimalK': int(best_k),
            'silhouetteScore': float(round(silhouette, 4)),
            'sampleSize': int(len(df)),
            'featureCount': int(len(feature_columns)),
            'analysisMode': 'personalized_per_user',
            'scope': f'{int(month):02d}/{int(year)}' if year is not None else 'provided_history',
            'inputDiagnostics': diagnostics,
            'silhouetteMeaning': 'cluster_separation_not_accuracy',
            'scoreAvailable': best_k > 1
        }

        return ClusteringResponse(
            success=True,
            user_id=user_id,
            clusters=final_clusters,
            user_profile=user_profile,
            recommendations=self._generate_recommendations(df, final_clusters),
            message="Phân tích thành công"
        )

    def _determine_spending_style(self, df: pd.DataFrame) -> str:
        evidence = self._profile_evidence(df, df)
        key = evidence['profileKey']
        if key in ('mixed_irregular', 'high_value_outliers', 'micro_spending'):
            return 'Giao dịch gồm nhiều mục đích; chưa có nhóm chi phối rõ'
        value = evidence['purposeShares'][key]
        return (f"{self.CLUSTER_PROFILES[key]['name']}: "
                f"{value['countShare'] * 100:.1f}% số giao dịch, "
                f"{value['amountShare'] * 100:.1f}% dòng tiền chi ra")

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
            "financialHealthScoreMeaning": "legacy_heuristic_not_financial_health_assessment",
            "topCategories": {str(k): float(v) for k, v in df.groupby('type_name')['amount'].sum().nlargest(5).to_dict().items()},
            "dominantBehavior": {
                "name": dominant.cluster_name if dominant else "Chưa xác định",
                "percentage": float(round(dominant.characteristics['totalAmount'] / total_spent * 100, 1)) if dominant and total_spent > 0 else 0
            },
            "spendingStyle": self._determine_spending_style(df)
        }

    def _generate_recommendations(self, df, clusters):
        total = float(df['amount'].sum())
        if total <= 0:
            return ['Chưa có dữ liệu chi tiêu hợp lệ để gợi ý.']
        recs = []
        group_totals = (df.groupby(['category_group_id', 'category_group_name'], dropna=False)['amount']
                        .agg(['sum', 'count']).sort_values('sum', ascending=False))
        for (group_id, group_name), row in group_totals.iterrows():
            if group_id == 'unclassified':
                continue
            share = float(row['sum']) / total * 100
            if group_id == 'expense_unexpected' and share >= 20:
                advice = 'Tách khoản đột xuất cần thiết khỏi khoản có thể trì hoãn; chỉ lập quỹ dự phòng theo khả năng thực tế.'
            elif group_id == 'expense_fixed':
                advice = 'Rà soát hóa đơn định kỳ và hạn thanh toán; chỉ đổi gói khi dữ liệu cho thấy có lựa chọn phù hợp.'
            elif group_id == 'investment_saving':
                advice = 'Đây là dòng tiền dành cho tiết kiệm/đầu tư; không xem khoản này là tiêu dùng lãng phí.'
            elif group_id == 'loan_borrow':
                advice = 'Phân biệt tiền vay, cho vay, thu hồi nợ và trả nợ; không gộp tiền vay vào thu nhập thường xuyên.'
            elif group_id == 'expense_living':
                advice = 'Theo dõi từng danh mục con để tìm khoản có thể tối ưu mà không cắt nhu cầu thiết yếu.'
            else:
                advice = 'Xem lại các danh mục con và đối chiếu với kế hoạch đã ghi nhận.'
            recs.append(f'{group_name}: {int(row["count"])} giao dịch, {row["sum"]:,.0f}đ '
                        f'({share:.1f}% dòng tiền chi ra). {advice}')
        for cluster in sorted(clusters, key=lambda c:c.characteristics['totalAmount'], reverse=True)[:3]:
            stats = cluster.characteristics
            names = ', '.join(list(stats['topCategories'])[:2])
            share = float(stats['totalAmount']) / total * 100
            group_ids = set(stats.get('categoryGroups', {}))
            if group_ids == {'investment_saving'}:
                advice = 'Đối chiếu với mục tiêu tiết kiệm/đầu tư đã chọn; không mặc định đây là khoản tiêu dùng cần cắt.'
            elif group_ids == {'loan_borrow'}:
                advice = 'Theo dõi riêng tiền vay, cho vay, trả gốc và trả lãi; không gộp thành chi phí sinh hoạt.'
            elif stats['essentialRatio'] >= 60:
                advice = 'Ưu tiên giữ các khoản thiết yếu; kiểm tra khoản phát sinh hoặc ghi sai trước khi điều chỉnh.'
            else:
                advice = 'Đối chiếu nhóm này với ngân sách và kế hoạch; chỉ hoãn khoản chưa cần thiết khi phù hợp.'
            recs.append(f"Nhóm {names}: {stats['transactionCount']} giao dịch, "
                        f"tổng {stats['totalAmount']:,.0f}đ ({share:.1f}% tổng chi đã ghi nhận). "
                        + advice)
        if len(df) < 30:
            recs.append('Số giao dịch còn ít; các nhóm có thể thay đổi khi cập nhật thêm dữ liệu.')
        recs.append('Tỷ trọng trên được tính theo tổng chi, không phải thu nhập. Chưa thể kết luận mức tiết kiệm từ dữ liệu chi riêng lẻ.')
        return recs

kmeans_service = KMeansService()
