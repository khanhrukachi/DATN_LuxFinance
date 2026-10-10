"""Chat intent adapter. It does not train a language model or save transactions."""
from __future__ import annotations

import re
import math
import threading
import unicodedata
from datetime import date, datetime
from functools import lru_cache
from typing import Any
from zoneinfo import ZoneInfo


def folded(value: Any) -> str:
    return ''.join(c for c in unicodedata.normalize('NFD', str(value).lower().replace('đ', 'd'))
                   if unicodedata.category(c) != 'Mn')


def plain(value: Any) -> Any:
    """Serialize Pydantic v1/v2, numpy scalars and dates without invalid JSON."""
    if value is None or isinstance(value, (str, bool, int)):
        return value
    if isinstance(value, float):
        return value if math.isfinite(value) else None
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    if hasattr(value, 'model_dump'):
        return plain(value.model_dump(by_alias=False))
    if hasattr(value, 'dict') and callable(value.dict):
        return plain(value.dict())
    if isinstance(value, dict):
        return {str(k): plain(v) for k, v in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [plain(v) for v in value]
    if hasattr(value, 'tolist'):
        return plain(value.tolist())
    if hasattr(value, 'item'):
        return plain(value.item())
    if hasattr(value, '__dict__'):
        return plain(vars(value))
    raise TypeError(f'Unsupported response value: {type(value).__name__}')


class ChatAIService:
    def __init__(self, finance=None, anomaly=None, category_labels=None, parent_categories=None):
        if finance is None:
            from .financial_insights_service import financial_insights_service
            finance = financial_insights_service
        if anomaly is None:
            from .isolation_forest_service import isolation_forest_service
            anomaly = isolation_forest_service
        if category_labels is None or parent_categories is None:
            from .category_taxonomy import LABELS, PARENT_CATEGORIES
            category_labels = LABELS if category_labels is None else category_labels
            parent_categories = PARENT_CATEGORIES if parent_categories is None else parent_categories
        self.finance, self.anomaly = finance, anomaly
        self.labels, self.parents = category_labels, parent_categories
        self._lock = threading.RLock()
        from .chat_query_engine import ChatQueryEngine
        self.query_engine = ChatQueryEngine(finance)

    def canonical_question(self, question: str, catalog: list[dict]) -> str:
        """Translate canonical display labels to IDs; retain parent/child structure.

        No synonym list is added to training data. The app supplies its current
        display labels, and the existing taxonomy supplies canonical VN labels.
        """
        phrases: dict[str, set[str]] = {}
        for cid, label in self.labels.items():
            phrases.setdefault(folded(label), set()).add(cid)
        for cid, meta in self.parents.items():
            label = meta.get('label', '') if isinstance(meta, dict) else ''
            if label:
                phrases.setdefault(folded(label), set()).add(cid)
        ids = set(self.labels) | set(self.parents)
        for item in catalog:
            cid = str(item.get('id') or item.get('title') or '').strip()
            if not cid:
                continue
            ids.add(cid)
            for key in ('display_name', 'label', 'name'):
                label = item.get(key)
                if label and label != cid:
                    phrases.setdefault(folded(label), set()).add(cid)
        for cid in ids:
            phrases.setdefault(folded(cid), set()).add(cid)
        # Recognize shortened canonical labels only when they identify one category.
        # This does not add synonym arrays to the dataset.
        stop = {'tien', 'chi', 'thu', 'phi', 'va', 'khac', 'danh', 'muc', 'money', 'fee', 'other'}
        short = {}
        for phrase, targets in list(phrases.items()):
            for word in phrase.split():
                if len(word) >= 3 and word not in stop and '_' not in word:
                    short.setdefault(word, set()).update(targets)
        for word, targets in short.items():
            if len(targets) == 1:
                phrases.setdefault(word, set()).update(targets)
        from .category_taxonomy import normalize_key
        for word in folded(question).split():
            cid = normalize_key(word)
            if cid in ids and cid != word:
                phrases.setdefault(word, set()).add(cid)
        text = folded(question)
        candidates = []
        for phrase, targets in phrases.items():
            if not phrase or len(targets) != 1:
                continue  # Ambiguous labels are never silently mapped.
            for match in re.finditer(r'(?<![a-z0-9_])' + re.escape(phrase) + r'(?![a-z0-9_])', text):
                candidates.append((match.start(), match.end(), next(iter(targets))))
        spans = []
        for start, end, cid in sorted(candidates, key=lambda v: -(v[1] - v[0])):
            if not any(start < b and end > a for a, b, _ in spans):
                spans.append((start, end, cid))
        for start, end, cid in sorted(spans, reverse=True):
            text = text[:start] + cid + text[end:]
        return text

    def answer(self, **kwargs) -> dict:
        try:
            result = self._answer(**kwargs)
        except ValueError as exc:
            result = dict(success=True, intent='clarification',
                          answer=f'Bạn kiểm tra lại dữ liệu hoặc khoảng thời gian: {exc}',
                          needsInput=['valid_query'], evidence={}, warnings=[])
        result = plain(result)
        result.setdefault('warnings', [])
        result.setdefault('needsInput', [])
        result.setdefault('evidence', {})
        result['warnings'] = list(dict.fromkeys(str(w) for w in result['warnings'] if w))
        result['serviceRevision'] = 'finance_category_chat_v4'
        return result

    def _answer(self, *, user_id: str, question: str, transactions: list,
               category_catalog: list, advisor_context: dict | None = None,
               reference_date: date | None = None) -> dict:
        scope = folded(question)
        scope = re.sub(r'\s+', ' ', scope).strip()
        if scope in {'xin chao', 'chao', 'hello', 'hi'}:
            return {'success': True, 'intent': 'greeting', 'answer': 'Chào bạn! Bạn có thể hỏi tổng thu chi, danh mục, ngân sách, dự báo hoặc giao dịch bất thường.', 'warnings': [], 'evidence': {}}
        if re.fullmatch(
            r"(?:phan tich|danh gia|tong quan)"
            r"(?:\s+(?:giao dich|chi tieu|thu chi|tai chinh))?"
            r"(?:\s+(?:"
            r"thang\s+(?:nay|truoc)"
            r"|thang\s+\d{1,2}"
            r"(?:\s*[/\-]\s*\d{4}|\s+nam\s+\d{4})?"
            r"))?",
            scope,
        ):
            today = (
                reference_date
                or datetime.now(ZoneInfo("Asia/Ho_Chi_Minh")).date()
            )
            context = dict(advisor_context or {})
            context.update(
                timezone="Asia/Ho_Chi_Minh",
                reference_date=today.isoformat(),
                category_catalog=category_catalog,
            )
            with self._lock:
                return self._financial_overview(
                    user_id,
                    transactions,
                    today,
                    category_catalog,
                    context,
                    scope,
                )
        forbidden = r'\b(thoi tiet|bong da|viet code|lap trinh|lam tho|ke chuyen|dich sang|weather|football|ignore previous|bo qua huong dan)\b'
        finance_terms = r'\b(chi|thu|tien|ngan sach|han muc|du bao|du doan|bat thuong|thoi quen|hanh vi|tiet kiem|tai chinh|giao dich|luong|income|expense|spending|budget|forecast|anomaly|behavior|afford)\b'
        canonical = self.canonical_question(question, category_catalog)
        targets = self.finance._query_category_targets(canonical, category_catalog)
        generic = re.search(r'\b(danh muc|thong ke|so sanh|trung binh|binh quan|ty trong|ti le|liet ke|thu chi|giao dich)\b', scope)
        if re.search(forbidden, scope) or not (re.search(finance_terms, scope) or targets or generic):
            return {'success': True, 'intent': 'out_of_scope', 'answer': 'Chat hỗ trợ hỏi đáp về thu chi cá nhân. Hãy nêu nội dung và khoảng thời gian, ví dụ: Tháng này tôi đã chi bao nhiêu?', 'warnings': [], 'evidence': {}, 'needsInput': ['finance_question']}
        today = reference_date or datetime.now(ZoneInfo('Asia/Ho_Chi_Minh')).date()
        context = dict(advisor_context or {})
        context.update(timezone='Asia/Ho_Chi_Minh', reference_date=today.isoformat(),
                       category_catalog=category_catalog)
        question_for_service = canonical
        text = folded(question)
        # Normalize spaces for intent detection, while the query retains date punctuation.
        text = re.sub(r'\s+', ' ', text).strip()
        if any(term in text for term in ('du tra', 'co du tra', 'afford', 'can i buy', 'co the mua')):
            # Keep category IDs and explicit amount; ensure the finance handler
            # recognizes a payment-capacity question rather than a category total.
            question_for_service = 'Co du tien de thanh toan ' + question_for_service
        if 'how much' in text and not any(term in text for term in ('afford', 'can i buy')):
            question_for_service = 'Bao nhieu ' + question_for_service
        # Deterministic totals stay independent of the optional ML model lock.
        direct = self.query_engine.answer(question_for_service, transactions, today, category_catalog, context)
        if direct is not None:
            if context.get('history_complete') is not True:
                direct.setdefault('warnings', []).append('Kết quả chỉ dựa trên lịch sử đã cung cấp; dữ liệu có thể chưa đầy đủ.')
            return direct
        with self._lock:
            is_comparison = any(w in text for w in ('so sanh', 'so voi', 'tang hay giam', 'compare', 'comparison'))
            overview_request = bool(re.search(r'\b(phan tich|tong quan|danh gia|bao cao|overview|analysis|analyse|analyze)\b', text) and re.search(r'\b(chi tieu|thu chi|thu nhap|tai chinh|tong chi|tong thu|spending|expense|income|finance|financial)\b', text))
            if overview_request or any(w in text for w in ('danh gia tai chinh', 'phan tich tai chinh', 'suc khoe tai chinh', 'bao cao tai chinh', 'financial health', 'financial overview', 'phan tich sau', 'phan tich thu chi', 'danh gia thu chi', 'tong quan thu chi')):
                result = self._financial_overview(user_id, transactions, today, category_catalog, context, text)
            elif is_comparison and any(w in text for w in ('thang', 'month')):
                result = self.finance.answer_question(
                    user_id, transactions, question_for_service, reference_date=today,
                    category_catalog=category_catalog, advisor_context=context)
            elif any(w in text for w in ('bat thuong', 'anomaly', 'anomalies', 'giao dich la')):
                result = self._anomalies(user_id, transactions, question_for_service, today, category_catalog)
            elif any(w in text for w in ('du bao', 'du doan', 'forecast', 'predict')):
                result = self._forecast(user_id, transactions, question_for_service, today, context)
            elif any(w in text for w in ('thoi quen', 'hanh vi', 'phan cum', 'behavior', 'behaviour', 'cluster')):
                result = self._behavior(user_id, transactions, question_for_service, today, category_catalog)
            elif any(w in text for w in ('goi y', 'tu van', 'nen tiet kiem', 'recommendation', 'advise')):
                result = self._recommendations(user_id, transactions, today, category_catalog, context)
            else:
                if any(w in text for w in ('ngan sach', 'han muc', 'vuot muc', 'budget')):
                    start, _, _ = self.finance._select_period_from_question(question_for_service, today)
                    if (start.year, start.month) != (today.year, today.month):
                        return dict(success=True, intent='budget_period_clarification',
                                    answer='Hỏi ngân sách trong chat hiện hỗ trợ tháng này. Hãy dùng màn hình Ngân sách để chọn tháng khác.',
                                    needsInput=['current_month_budget'], evidence={}, warnings=[])
                result = self.finance.answer_question(
                    user_id, transactions, question_for_service, reference_date=today,
                    category_catalog=category_catalog, advisor_context=context)
        result = plain(result)
        result.setdefault('success', True)
        result.setdefault('intent', 'finance_question')
        result.setdefault('answer', 'Chưa có kết quả phân tích.')
        result.setdefault('evidence', {})
        result.setdefault('needsInput', [])
        result.setdefault('warnings', [])
        result['serviceRevision'] = 'finance_deep_v3'
        result['question'] = question
        result['submittedTransactionCount'] = len(transactions)
        result['warnings'].extend(result.get('evidence', {}).get('warnings', []) or [])
        if context.get('history_complete') is not True:
            result['warnings'].append('Kết quả dựa trên giao dịch đã ghi nhận; lịch sử có thể chưa đầy đủ.')
        return result

    def _financial_overview(self, uid, txs, today, catalog, context, question=''):
        from datetime import timedelta
        from .category_taxonomy import LABELS
        normalized, diagnostics = self.finance._normalized(txs, today, catalog)
        import calendar
        actual_today = today
        requested = re.search(r'\b(?:thang|month)\s+(\d{1,2})(?:\s*[/\-]\s*(\d{4})|\s+(?:nam|year)\s+(\d{4}))?', question)
        if requested:
            month = int(requested.group(1))
            year = int(requested.group(2) or requested.group(3) or today.year)
            if not 1 <= month <= 12 or not 1 <= year <= 9999:
                return dict(success=True, intent='period_clarification', answer='Tháng phải từ 1 đến 12 và năm phải hợp lệ.', evidence={}, needsInput=['valid_month'])
            start = date(year, month, 1)
        else:
            start, _, _ = self.query_engine.period(question, today)
            start = start.replace(day=1)
        if start > actual_today:
            return dict(success=True, intent='period_clarification', answer='Tháng này chưa diễn ra; chưa có thu chi thực tế để phân tích. Bạn có thể hỏi dự báo riêng.', evidence={}, needsInput=['recorded_month'])
        today = min(actual_today, date(start.year, start.month, calendar.monthrange(start.year, start.month)[1]))
        previous_last = start - timedelta(days=1)
        previous_start = previous_last.replace(day=1)
        previous_end = previous_last if today.day == calendar.monthrange(today.year, today.month)[1] else previous_last.replace(day=min(today.day, previous_last.day))
        current = self.finance._within(normalized, start, today)
        previous = self.finance._within(normalized, previous_start, previous_end)
        def totals(items):
            income = sum(float(t.money) for t in items if t.money > 0)
            expense = sum(abs(float(t.money)) for t in items if t.money < 0)
            return dict(income=round(income), expense=round(expense), net=round(income-expense),
                        transactionCount=len(items), surplusRate=round((income-expense)/income*100, 1) if income else None)
        now, before = totals(current), totals(previous)
        groups = {}
        for t in current:
            if t.money >= 0:
                continue
            cid = getattr(t, 'category_id', '') or 'unclassified'
            item = groups.setdefault(cid, dict(categoryId=cid, categoryName=LABELS.get(cid, cid), amount=0, count=0))
            item['amount'] += abs(float(t.money))
            item['count'] += 1
        categories = sorted(groups.values(), key=lambda r: -r['amount'])
        for row in categories:
            row['amount'] = round(row['amount'])
            row['sharePercent'] = round(row['amount']/now['expense']*100, 1) if now['expense'] else 0
        comparison_label = 'tháng trước' if today.day == calendar.monthrange(today.year, today.month)[1] else 'cùng số ngày tháng trước'
        lines = [f"Đánh giá tài chính từ {start:%d/%m/%Y} đến {today:%d/%m/%Y}:",
                 f"• Thu nhập: {now['income']:,.0f}đ; chi tiêu: {now['expense']:,.0f}đ; chênh lệch: {now['net']:,.0f}đ."]
        if now['surplusRate'] is not None:
            lines.append(f"• Tỷ lệ dư thu chi: {now['surplusRate']}% thu nhập đã ghi nhận.")
        if now['net'] < 0:
            lines.append(f"• Chi vượt thu {abs(now['net']):,.0f}đ. Kiểm tra các khoản lớn trước khi cam kết khoản chi mới.")
        if previous:
            for field, label in [('income', 'Thu nhập'), ('expense', 'Chi tiêu')]:
                delta = now[field]-before[field]
                percent = f" ({abs(delta)/before[field]*100:.1f}%)" if before[field] else ' (kỳ trước bằng 0, không tính tỷ lệ)'
                lines.append(f"• {label} {'tăng' if delta > 0 else 'giảm' if delta < 0 else 'không đổi'} {abs(delta):,.0f}đ{percent} so với {comparison_label}.")
        else:
            lines.append('• Chưa có giao dịch cùng kỳ tháng trước để so sánh.')
        for row in categories[:5]:
            lines.append(f"• {row['categoryName']}: {row['amount']:,.0f}đ, chiếm {row['sharePercent']}% tổng chi, {row['count']} giao dịch.")
        budget = self.finance._answer_budget_question('ngan sach', normalized, today, catalog, context)
        budgets = (budget or {}).get('evidence', {}).get('budgets', [])
        for row in budgets:
            limit = row['limit']
            used = row['spent']/limit*100 if limit > 0 else None
            if row['overBudget'] or (used is not None and used >= 80):
                lines.append(f"• Ngân sách {row['budgetName']}: đã chi {row['spent']:,.0f}đ / {limit:,.0f}đ; " +
                             (f"vượt {abs(row['remaining']):,.0f}đ." if row['overBudget'] else f"còn {row['remaining']:,.0f}đ, cần theo dõi."))
        if not current:
            lines.append('• Chưa có giao dịch trong tháng được hỏi; chưa đủ căn cứ đánh giá.')
        return dict(success=True, intent='financial_overview', answer='\n'.join(lines),
                    evidence=dict(current=dict(now, startDate=start.isoformat(), endDate=today.isoformat(), amount=now['expense']),
                                  previous=dict(before, startDate=previous_start.isoformat(), endDate=previous_end.isoformat(), amount=before['expense']),
                                  topCategories=categories, budgets=budgets, diagnostics=diagnostics),
                    warnings=['Chênh lệch thu chi không phải số dư tài khoản hoặc khoản tiết kiệm đã xác nhận.',
                              'Tháng đang diễn ra so sánh cùng số ngày; tháng đã kết thúc so sánh cả tháng.'])

    def _behavior(self, uid, txs, question, today, catalog):
        start, end, _ = self.query_engine.period(question, today)
        normalized, _ = self.finance._normalized(txs, today, catalog)
        selected = self.finance._within(normalized, start, end)
        targets = self.finance._query_category_targets(question, catalog)
        if targets:
            selected = [t for t in selected if self.finance._category_query_match(question, t, catalog, targets)]
        data = plain(self.finance.kmeans.cluster_spending(
            uid, selected, reference_date=today, category_catalog=catalog))
        clusters = data.get('clusters', [])
        ok = data.get('success', False)
        lines = [f'Phân tích thói quen từ {start:%d/%m/%Y} đến {end:%d/%m/%Y}:']
        for row in clusters[:5]:
            chars = row.get('characteristics', {})
            lines.append(f"• {row.get('cluster_name', row.get('clusterName', 'Nhóm'))}: "
                         f"{chars.get('transactionCount', 0)} giao dịch, "
                         f"tổng {chars.get('totalAmount', 0):,.0f}đ.")
        if not ok or not clusters:
            lines = [data.get('message') or 'Chưa đủ giao dịch chi để phân tích thói quen.']
        return dict(success=True, intent='behavior_analysis', answer='\n'.join(lines),
                    period={'startDate': start.isoformat(), 'endDate': end.isoformat()},
                    evidence={'modelReady': bool(ok and clusters), 'clusters': clusters},
                    warnings=['Cụm mô tả các giao dịch; không tự kết luận bạn chi tiêu lãng phí.'])

    def _anomalies(self, uid, txs, question, today, catalog):
        start, end, period = self.query_engine.period(question, today)
        if period != 'month':
            return dict(success=True, intent='anomaly_period_clarification',
                        answer='Phát hiện bất thường hiện phân tích theo tháng. Hãy nêu tháng cần xem, ví dụ: “Chi tiêu tháng này có bất thường không?”.',
                        needsInput=['analysis_month'], evidence={})
        data = plain(self.anomaly.detect_anomalies(
            user_id=uid, transactions=txs, year=start.year, month=start.month,
            reference_date=today, category_catalog=catalog))
        rows = data.get('anomalies', [])
        targets = self.finance._query_category_targets(question, catalog)
        if targets:
            normalized, _ = self.finance._normalized(txs, today, catalog)
            ids = {t.id for t in normalized if self.finance._category_query_match(question, t, catalog, targets)}
            rows = [r for r in rows if str(r.get('transaction_id', r.get('transactionId', r.get('id', '')))) in ids]
        ready = data.get('statistics', {}).get('modelReady', False)
        if not data.get('success'):
            answer = '; '.join(data.get('alerts') or [data.get('message') or 'Chưa đủ dữ liệu để phân tích.'])
        elif rows:
            answer = f'Có {len(rows)} giao dịch cần kiểm tra trong tháng {start:%m/%Y}:\n' + '\n'.join(
                f"• {r.get('type_name', r.get('typeName', 'Khoản chi'))}: "
                f"{abs(r.get('money', 0)):,.0f}đ. {r.get('anomaly_reason', r.get('anomalyReason', ''))}"
                for r in rows[:5])
        elif not ready:
            answer = 'Chưa phát hiện dấu hiệu theo quy tắc, nhưng chưa đủ dữ liệu để mô hình kết luận chi tiêu bình thường.'
        else:
            answer = 'Chưa phát hiện giao dịch bất thường theo mô hình và quy tắc trong tháng này.'
        return dict(success=True, intent='anomaly_analysis', answer=answer,
                    period={'startDate': start.isoformat(), 'endDate': end.isoformat()},
                    evidence={'modelReady': ready, 'anomaliesDetected': len(rows),
                              'transactionCount': data.get('total_transactions', 0), 'anomalies': rows[:5]},
                    warnings=['Hãy kiểm tra bối cảnh giao dịch; kết quả không tự động xóa hay sửa khoản chi.'])

    def _forecast(self, uid, txs, text, today, context):
        days_match = re.search(r'\b(\d{1,2})\s*(?:ngay|days?)\b', text)
        days = int(days_match.group(1)) if days_match else 7
        if not 1 <= days <= 30:
            raise ValueError('Số ngày dự báo phải nằm trong 1..30.')
        forecast_year = forecast_month = None
        mode = 'rolling'
        month_match = re.search(r'\b(?:thang|month)\s+(\d{1,2})(?:\s*[/\-]\s*(\d{4})|\s+(?:nam|year)\s+(\d{4}))?', text)
        if 'thang sau' in text or 'next month' in text:
            forecast_month = today.month % 12 + 1
            forecast_year = today.year + (today.month == 12)
            mode = 'month'
        elif month_match:
            forecast_month = int(month_match.group(1))
            forecast_year = int(month_match.group(2) or month_match.group(3) or today.year)
            mode = 'month'
        elif 'thang nay' in text or 'this month' in text:
            forecast_year, forecast_month = today.year, today.month
            mode = 'month'
        elif any(term in text for term in ('thang truoc','last month','hom qua','tuan truoc','nam ngoai')):
            return dict(success=True, intent='forecast_period_clarification', answer='Kỳ này đã diễn ra. Hãy hỏi tổng chi thực tế hoặc chọn kỳ dự báo tương lai.', evidence={}, needsInput=['future_period'])
        if mode == 'month':
            import calendar
            first = date(forecast_year, forecast_month, 1)
            last = date(forecast_year, forecast_month, calendar.monthrange(forecast_year,forecast_month)[1])
            if last <= today:
                return dict(success=True,intent='forecast_period_clarification',answer='Tháng này đã kết thúc; hãy xem thống kê thực tế.',evidence={},needsInput=['future_period'])
            if not days_match:
                days = min(30,(last-max(first,today)).days + (1 if first>today else 0))
        normalized, _ = self.finance._normalized(txs, today, context.get('category_catalog'))
        targets = self.finance._query_category_targets(text, context.get('category_catalog'))
        if targets:
            normalized = [t for t in normalized if self.finance._category_query_match(text, t, context.get('category_catalog'), targets)]
        data = plain(self.finance.lstm.predict_trend(uid, normalized, prediction_days=days,
                                                   year=forecast_year, month=forecast_month, advisor_context=context, forecast_mode=mode))
        rows = data.get('predictions', [])
        if not data.get('success') or not rows or data.get('summary', {}).get('forecastAvailable') is False:
            return dict(success=True, intent='spending_forecast',
                        answer=data.get('message') or 'Chưa đủ dữ liệu để dự báo.',
                        evidence={'modelReady': False}, needsInput=['more_transaction_history'])
        expense = sum(float(r.get('predicted_expense', r.get('predictedExpense', 0)) or 0) for r in rows)
        income = sum(float(r.get('predicted_income', r.get('predictedIncome', 0)) or 0) for r in rows)
        summary = data.get('summary', {})
        method = summary.get('forecastMethod') or summary.get('method') or summary.get('model') or 'lstm_or_baseline'
        return dict(success=True, intent='spending_forecast',
                    answer=f'Trong khoảng dự báo gồm {len(rows)} ngày, chi ra ước tính {expense:,.0f}đ, thu vào ước tính {income:,.0f}đ.',
                    evidence={'predictedExpense': round(expense), 'predictedIncome': round(income),
                              'matchedCategories': targets, 'forecastDays': len(rows), 'forecastMethod': method, 'daily': rows, 'forecastMode': mode,
                              'analysisMonth': f'{forecast_month:02d}/{forecast_year}' if mode == 'month' else None},
                    warnings=['Đây là số dự báo từ lịch sử cá nhân; không tính là giao dịch hoặc thu nhập đã xác nhận.',
                              *summary.get('warnings', []),
                              *(['Dự báo tháng giới hạn 30 ngày; xem từng ngày để biết chính xác khoảng được dự báo.'] if mode == 'month' else [])])

    def _recommendations(self, uid, txs, today, catalog, context):
        data = plain(self.finance.build_recommendations(
            uid, txs, reference_date=today, category_catalog=catalog,
            budgets=context.get('budgets', []), advisor_context=context))
        rows = data.get('recommendations', [])
        answer = '\n'.join(f"• {r.get('title', 'Việc cần chú ý')}: "
                           f"{r.get('suggestion') or r.get('reason') or ''}" for r in rows[:5])
        return dict(success=True, intent='financial_recommendations',
                    answer=answer or 'Chưa có đề xuất đủ căn cứ từ dữ liệu hiện tại.',
                    evidence={'recommendations': rows[:5]},
                    warnings=data.get('diagnostics', {}).get('limitations', []))


@lru_cache(maxsize=1)
def get_chat_ai_service() -> ChatAIService:
    return ChatAIService()
