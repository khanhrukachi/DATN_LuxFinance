"""Unified personal-finance reporting, cash-flow Q&A, and recommendations.

Place this module beside category_taxonomy.py, kmeans_service.py and
lstm_service.py (normally ``app/services``). It exposes deterministic Python
methods for Flutter/FastAPI to call; it does not implement a chat UI or an LLM.

Public methods:
    generate_report(..., period="week" | "month" | "year")
    answer_question(..., question="...")
    build_recommendations(...)

Amounts are VND. A cash-availability answer requires a current available
balance and a rent amount (or an observed rent transaction); estimated salary
is never counted as confirmed cash.
"""

from __future__ import annotations

import calendar
import json
import re
import statistics
import unicodedata
from collections import defaultdict
from datetime import date, datetime, timedelta
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple
from zoneinfo import ZoneInfo

import pandas as pd

try:  # Intended installation: app/services/financial_insights_service.py
    from .category_taxonomy import (
        CHILD_PARENT,
        LABELS,
        PARENT_CATEGORIES,
        ROLE_BY_CATEGORY,
        build_catalog,
        category_scope_ids,
        normalize_key,
        resolve_category_metadata,
        summarize_category_hierarchy,
    )
    from .kmeans_service import KMeansService, _normalize_transactions
    from .lstm_service import LSTMService
except ImportError:  # Allows importing as a flat module in small test harnesses.
    from category_taxonomy import (
        CHILD_PARENT,
        LABELS,
        PARENT_CATEGORIES,
        ROLE_BY_CATEGORY,
        build_catalog,
        category_scope_ids,
        normalize_key,
        resolve_category_metadata,
        summarize_category_hierarchy,
    )
    from kmeans_service import KMeansService, _normalize_transactions
    from lstm_service import LSTMService


def _get(obj: Any, *keys: str, default: Any = None) -> Any:
    for key in keys:
        value = obj.get(key) if isinstance(obj, Mapping) else getattr(obj, key, None)
        if value is not None:
            return value
    return default


def _plain(value: Any) -> Any:
    """Convert Pydantic/model responses into ordinary JSON-compatible values."""
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, Mapping):
        return {str(k): _plain(v) for k, v in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [_plain(v) for v in value]
    if hasattr(value, "model_dump"):
        return _plain(value.model_dump())
    if hasattr(value, "dict") and callable(value.dict):
        return _plain(value.dict())
    if hasattr(value, "__dict__"):
        return _plain(vars(value))
    return value


def _norm_text(value: Any) -> str:
    text = str(value or "").strip().lower().replace("đ", "d")
    text = "".join(c for c in unicodedata.normalize("NFD", text)
                   if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


@lru_cache(maxsize=1)
def _load_question_categories() -> Dict[str, str]:
    """Read only category IDs and their immediate parent IDs."""
    path = Path(__file__).with_name("financial_qa_category_aliases.json")
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {str(row["category_id"]): str(row.get("parent_category_id", ""))
            for row in data.get("categories", []) if row.get("category_id")}


class FinancialInsightsService:
    """Compose category taxonomy, K-Means and LSTM outputs for app features."""

    PERIOD_WORDS = {
        "week": ("tuan", "weekly", "week"),
        "month": ("thang", "monthly", "month"),
        "year": ("nam", "yearly", "annual", "year"),
    }
    OPTIONAL_CATEGORY_IDS = {
        "fun_play", "shopping", "beautify", "online_services", "gifts_donations",
        "travel", "sport",
    }

    def __init__(self, kmeans_service: Any = None, lstm_service: Any = None):
        self.kmeans = kmeans_service or KMeansService()
        self.lstm = lstm_service or LSTMService()

    @staticmethod
    def _reference_day(reference_date: Any = None) -> date:
        if reference_date is None:
            return datetime.now(ZoneInfo("Asia/Ho_Chi_Minh")).date()
        ts = pd.Timestamp(reference_date)
        if ts.tzinfo is not None:
            ts = ts.tz_convert("Asia/Ho_Chi_Minh").tz_localize(None)
        return ts.date()

    @staticmethod
    def _period_bounds(
        period: str, today: date, year: Optional[int], month: Optional[int],
        start_date: Any = None, end_date: Any = None,
    ) -> Tuple[date, date]:
        if start_date is not None or end_date is not None:
            if start_date is None or end_date is None:
                raise ValueError("Cần truyền đồng thời start_date và end_date.")
            start, end = pd.Timestamp(start_date).date(), pd.Timestamp(end_date).date()
            if end < start or (end - start).days > 366:
                raise ValueError("Khoảng ngày không hợp lệ hoặc dài hơn 367 ngày.")
            return start, end
        if period == "week":
            end = today
            return end - timedelta(days=today.weekday()), end
        if period == "month":
            yy, mm = int(year or today.year), int(month or today.month)
            last = calendar.monthrange(yy, mm)[1]
            start, last_day = date(yy, mm, 1), date(yy, mm, last)
            return start, min(last_day, today) if (yy, mm) == (today.year, today.month) else last_day
        if period == "year":
            yy = int(year or today.year)
            start, end = date(yy, 1, 1), date(yy, 12, 31)
            return start, min(end, today) if yy == today.year else end
        raise ValueError("period chỉ nhận week, month hoặc year.")

    def _normalized(
        self, transactions: Sequence[Any], reference_date: date,
        category_catalog: Any = None,
    ) -> Tuple[List[Any], Dict[str, Any]]:
        return _normalize_transactions(
            list(transactions or []), reference_date=reference_date,
            category_catalog=category_catalog,
        )

    @staticmethod
    def _within(items: Iterable[Any], start: date, end: date) -> List[Any]:
        return [t for t in items if start <= t.date_time.date() <= end]

    @staticmethod
    def _cashflow_totals(items: Sequence[Any]) -> Dict[str, float]:
        inflow = sum(float(t.money) for t in items if float(t.money) > 0)
        outflow = sum(abs(float(t.money)) for t in items if float(t.money) < 0)
        # Borrowing, debt collection, transfers and investment return are cash
        # inflows but not operating income; retain both measures for clarity.
        operating_income = sum(float(t.money) for t in items
                               if float(t.money) > 0 and t.financial_role in {
                                   "fixed_monthly_income", "regular_income", "business_income", "other_income"
                               })
        consumption = sum(abs(float(t.money)) for t in items
                          if float(t.money) < 0 and bool(getattr(t, "is_consumption_expense", False)))
        return {
            "cashInflow": round(inflow), "cashOutflow": round(outflow),
            "netCashFlow": round(inflow - outflow),
            "operatingIncome": round(operating_income),
            "consumptionExpense": round(consumption),
        }

    @staticmethod
    def _daily_series(items: Sequence[Any], start: date, end: date) -> List[Dict[str, Any]]:
        totals: Dict[date, Dict[str, float]] = defaultdict(lambda: {"income": 0.0, "expense": 0.0})
        for t in items:
            key = t.date_time.date()
            if float(t.money) > 0:
                totals[key]["income"] += float(t.money)
            elif float(t.money) < 0:
                totals[key]["expense"] += abs(float(t.money))
        rows, cursor = [], start
        while cursor <= end:
            values = totals[cursor]
            rows.append({"date": cursor.isoformat(), "income": round(values["income"]),
                         "expense": round(values["expense"])})
            cursor += timedelta(days=1)
        return rows

    @staticmethod
    def _category_rows(items: Sequence[Any]) -> List[Dict[str, Any]]:
        groups: Dict[Tuple[str, str, str, str], Dict[str, Any]] = {}
        for t in items:
            if float(t.money) >= 0:
                continue
            key = (str(t.category_group_id), str(t.category_group_name),
                   str(t.category_id), str(t.type_name))
            row = groups.setdefault(key, {
                "categoryGroupId": key[0], "categoryGroupName": key[1],
                "categoryId": key[2], "categoryName": key[3],
                "transactionCount": 0, "amount": 0,
            })
            row["transactionCount"] += 1
            row["amount"] += abs(float(t.money))
        return sorted(({**v, "amount": round(v["amount"])} for v in groups.values()),
                      key=lambda x: x["amount"], reverse=True)

    def _run_lstm(
        self, user_id: str, transactions: Sequence[Any], days: int,
        today: date, context: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        if not transactions:
            return {"available": False, "message": "Chưa có giao dịch để dự báo.", "summary": {}}
        try:
            response = self.lstm.predict_trend(
                user_id, list(transactions), prediction_days=max(1, min(30, int(days))),
                year=today.year, month=today.month,
                advisor_context={**(context or {}), "reference_date": today.isoformat()},
                forecast_mode="rolling",
            )
            data = _plain(response)
            return {"available": bool(data.get("success")),
                    "message": data.get("message", ""),
                    "summary": data.get("summary", {}) or {}}
        except Exception as exc:
            # Keep reporting usable if optional model dependencies are missing.
            return {"available": False, "message": f"Không lấy được dự báo: {exc}", "summary": {}}

    def generate_report(
        self, user_id: str, transactions: Sequence[Any], period: str = "month", *,
        reference_date: Any = None, year: Optional[int] = None, month: Optional[int] = None,
        start_date: Any = None, end_date: Any = None, category_catalog: Any = None,
        include_models: bool = True, advisor_context: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Return actual cash-flow summaries for a week/month/year plus model insights."""
        today = self._reference_day(reference_date)
        start, end = self._period_bounds(period, today, year, month, start_date, end_date)
        normalized, diagnostics = self._normalized(transactions, today, category_catalog)
        selected = self._within(normalized, start, end)
        totals = self._cashflow_totals(selected)
        hierarchy = summarize_category_hierarchy(selected)
        days = (end - start).days + 1
        result: Dict[str, Any] = {
            "success": True, "userId": user_id, "period": period,
            "startDate": start.isoformat(), "endDate": end.isoformat(),
            "currency": "VND", "transactionCount": len(selected),
            "totals": totals, "daily": self._daily_series(selected, start, end),
            "topCategories": self._category_rows(selected)[:10],
            "categoryAnalysis": hierarchy,
            "dataQuality": {
                "invalidTransactions": diagnostics.get("invalid", 0),
                "duplicatesRemoved": diagnostics.get("duplicates", 0),
                "futureTransactionsIgnored": diagnostics.get("future", 0),
                "transfersIgnored": diagnostics.get("transfers", 0),
                "unclassifiedTransactions": hierarchy.get("unclassifiedTransactionCount", 0),
            },
            "note": "Số liệu trong báo cáo là giao dịch đã ghi nhận; ngày không có giao dịch không chứng minh rằng không phát sinh chi.",
        }
        result["textSummary"] = (
            f"Từ {start.strftime('%d/%m/%Y')} đến {end.strftime('%d/%m/%Y')}, "
            f"bạn đã ghi nhận {totals['cashInflow']:,.0f}đ tiền vào và "
            f"{totals['cashOutflow']:,.0f}đ tiền ra; dòng tiền ròng là "
            f"{totals['netCashFlow']:,.0f}đ qua {len(selected)} giao dịch."
        )
        if include_models:
            # K-Means input is limited to the selected report period. It declines
            # gracefully when fewer than ten expense transactions are available.
            try:
                cluster_response = self.kmeans.cluster_spending(
                    user_id, selected, reference_date=today,
                    category_catalog=category_catalog,
                )
                result["behaviorAnalysis"] = _plain(cluster_response)
            except Exception as exc:
                result["behaviorAnalysis"] = {"success": False, "message": str(exc), "clusters": []}

            # Forecasting is useful only for the current month; it must not be
            # presented as a forecast of a past weekly/yearly reporting window.
            if period == "month" and (start.year, start.month) == (today.year, today.month):
                month_end = date(today.year, today.month,
                                 calendar.monthrange(today.year, today.month)[1])
                remaining_days = max(1, min(30, (month_end - today).days))
                forecast = self._run_lstm(user_id, normalized, remaining_days, today, advisor_context)
                result["forecast"] = forecast
                summary = forecast.get("summary", {})
                result["smartRecommendations"] = summary.get("smartRecommendations", [])
                result["recommendationSources"] = ["kmeans", "lstm_forecast", "budget", "isolation_forest"]
            else:
                result["forecast"] = {
                    "available": False,
                    "message": "Dự báo hiện được gắn với tháng hiện tại; kỳ báo cáo này chỉ tổng hợp giao dịch thực tế.",
                    "summary": {},
                }
        return result

    def _select_period_from_question(self, question: str, today: date) -> Tuple[date, date, str]:
        text = _norm_text(question)
        date_text = str(question).lower().replace("đ", "d")
        date_text = "".join(c for c in unicodedata.normalize("NFD", date_text)
                            if unicodedata.category(c) != "Mn")
        comparison_question = any(x in text for x in ("tang khong", "giam khong", "tang hay giam",
                                                       "so voi thang truoc", "increase", "decrease"))
        if comparison_question:
            if any(x in text for x in ("tuan", "weekly", "week")):
                start = today - timedelta(days=today.weekday())
                return start, today, "week"
            if any(x in text for x in ("nam", "yearly", "year")):
                return date(today.year, 1, 1), today, "year"
            return date(today.year, today.month, 1), today, "month"
        # Exact-day phrases have priority over month/week defaults.
        if "hom kia" in text:
            d = today - timedelta(days=2)
            return d, d, "day"
        if "hom qua" in text or "yesterday" in text:
            d = today - timedelta(days=1)
            return d, d, "day"
        if "hom nay" in text or "today" in text:
            return today, today, "day"
        day_window = re.search(r"\b(\d{1,3})\s+ngay\s+(?:qua|gan day|tro lai)\b", text)
        if day_window:
            count = max(1, min(366, int(day_window.group(1))))
            return today - timedelta(days=count - 1), today, "custom_days"
        explicit_month = re.search(r"\bthang\s+(1[0-2]|0?[1-9])(?:\s+nam\s+(\d{4}))?\b", text)
        if explicit_month and not any(x in text for x in ("thang nay", "thang truoc")):
            mm = int(explicit_month.group(1))
            yy = int(explicit_month.group(2) or today.year)
            last = calendar.monthrange(yy, mm)[1]
            end = date(yy, mm, last)
            if (yy, mm) == (today.year, today.month):
                end = today
            return date(yy, mm, 1), end, "month"
        explicit_year = re.search(r"\b(?:nam|year)\s+(20\d{2})\b", text)
        explicit_dates = re.search(
            r"\b(?:tu|from)\s+(\d{1,2})[/-](\d{1,2})(?:[/-](\d{4}))?\s+"
            r"(?:den|toi|to)\s+(\d{1,2})[/-](\d{1,2})(?:[/-](\d{4}))?\b", date_text)
        if explicit_dates:
            d1, m1, y1, d2, m2, y2 = explicit_dates.groups()
            start = date(int(y1 or y2 or today.year), int(m1), int(d1))
            end = date(int(y2 or y1 or today.year), int(m2), int(d2))
            if end < start:
                raise ValueError("Ngày kết thúc phải bằng hoặc sau ngày bắt đầu.")
            return start, end, "custom_range"
        if explicit_year and not any(x in text for x in ("nam nay", "nam ngoai")):
            yy = int(explicit_year.group(1))
            end = min(date(yy, 12, 31), today) if yy == today.year else date(yy, 12, 31)
            return date(yy, 1, 1), end, "year"
        if any(x in text for x in ("thang truoc", "last month")):
            last_day = date(today.year, today.month, 1) - timedelta(days=1)
            return date(last_day.year, last_day.month, 1), last_day, "month"
        if any(x in text for x in ("nam nay", "this year", "year to date")):
            return date(today.year, 1, 1), today, "year"
        if any(x in text for x in ("tuan nay", "this week")):
            return today - timedelta(days=today.weekday()), today, "week"
        if any(x in text for x in ("thang nay", "this month")):
            return date(today.year, today.month, 1), today, "month"
        if any(x in text for x in ("nam ngoai", "last year")):
            return date(today.year - 1, 1, 1), date(today.year - 1, 12, 31), "year"
        if any(x in text for x in ("tuan truoc", "last week")):
            end = today - timedelta(days=today.weekday() + 1)
            return end - timedelta(days=6), end, "week"
        return date(today.year, today.month, 1), today, "month"

    @staticmethod
    def _phrase_spans(text: str, phrase: str) -> List[Tuple[int, int]]:
        if not phrase:
            return []
        pattern = r"(?<![a-z0-9])" + re.escape(phrase) + r"(?![a-z0-9])"
        return [(m.start(), m.end()) for m in re.finditer(pattern, text)]

    def _query_category_targets(self, query: str, category_catalog: Any = None) -> List[str]:
        """Resolve every taxonomy category/group phrase found in a question.

        Only explicit parent and child IDs are matched. Longer IDs win
        when their normalized text overlaps with a shorter ID.
        """
        text = _norm_text(query)
        phrase_targets: Dict[str, set] = defaultdict(set)
        ids = set(PARENT_CATEGORIES) | set(CHILD_PARENT) | set(CHILD_PARENT.values())
        ids.update(_load_question_categories())
        # Dynamic catalog contributes explicit IDs only, never synonyms or notes.
        try:
            catalog = build_catalog(category_catalog)
        except (TypeError, ValueError):
            catalog = {}
        for item in catalog.values():
            category_id = str(item.get("_stable_id", item.get("id", item.get("title", ""))) or "")
            if category_id:
                ids.add(category_id)
        for category_id in sorted(ids):
            phrase_targets[category_id].add(_norm_text(category_id))

        candidates = []
        for target, phrases in phrase_targets.items():
            for phrase in phrases:
                for start, end in self._phrase_spans(text, phrase):
                    candidates.append((end - start, start, end, target))
        candidates.sort(key=lambda item: (-item[0], item[1]))
        accepted_spans: List[Tuple[int, int]] = []
        targets: List[str] = []
        for _, start, end, target in candidates:
            if any(start < used_end and end > used_start for used_start, used_end in accepted_spans):
                continue
            accepted_spans.append((start, end))
            if target not in targets:
                targets.append(target)
        return targets

    def _category_query_match(
        self, query: str, tx: Any, category_catalog: Any = None,
        targets: Optional[Sequence[str]] = None,
    ) -> bool:
        targets = list(targets) if targets is not None else self._query_category_targets(query, category_catalog)
        category_id = normalize_key(getattr(tx, "category_id", ""))
        category_group_id = normalize_key(getattr(tx, "category_group_id", ""))
        path = {normalize_key(value) for value in getattr(tx, "category_path_ids", []) or []}
        # Older records may not carry category_path_ids; taxonomy can derive it.
        if not path:
            meta = resolve_category_metadata(tx, category_catalog)
            path = {normalize_key(value) for value in meta.get("category_path_ids", [])}
            category_id = category_id or meta.get("category_id", "")
            category_group_id = category_group_id or meta.get("category_group_id", "")
        if not targets:
            return False
        for target in targets:
            if target in PARENT_CATEGORIES:
                if target == category_group_id or target in path:
                    return True
                continue
            if target == category_id or target in path:
                return True
        return False

    def _answer_budget_question(
        self, question: str, transactions: Sequence[Any], today: date,
        category_catalog: Any, context: Optional[Dict[str, Any]],
    ) -> Optional[Dict[str, Any]]:
        text = _norm_text(question)
        if not any(word in text for word in ("ngan sach", "han muc", "vuot muc", "con bao nhieu", "budget")):
            return None
        budgets = list((context or {}).get("budgets") or [])
        if not budgets:
            return {
                "success": True, "intent": "budget_status",
                "answer": "Chưa có dữ liệu ngân sách trong yêu cầu nên mình chưa thể kết luận khoản này còn bao nhiêu hoặc đã vượt hạn mức.",
                "needsInput": ["budgets"], "evidence": {},
            }
        targets = self._query_category_targets(question, category_catalog)
        current = [b for b in budgets if int(b.get("year", today.year)) == today.year
                   and int(b.get("month", today.month)) == today.month
                   and b.get("isActive", True) is not False]
        if targets:
            filtered = []
            for b in current:
                meta = resolve_category_metadata(b, category_catalog)
                budget_id = meta.get("category_id", "")
                group_id = meta.get("category_group_id", "")
                path = set(meta.get("category_path_ids", []))
                if any(t == budget_id or t == group_id or t in path for t in targets):
                    filtered.append(b)
            current = filtered
        if not current:
            return {
                "success": True, "intent": "budget_status",
                "answer": "Không tìm thấy ngân sách đang hoạt động phù hợp với danh mục/kỳ hỏi.",
                "needsInput": [], "evidence": {"month": today.strftime("%m/%Y"), "matchedBudgets": 0},
            }
        rows = []
        for budget in current:
            meta = resolve_category_metadata(budget, category_catalog)
            limit = float(budget.get("limit", budget.get("limitMoney", 0)) or 0)
            if budget.get("spent") is not None:
                spent = float(budget["spent"])
                source = "provided_budget_spent"
            else:
                category_id = meta.get("category_id", "")
                scope = category_scope_ids(budget, category_catalog)
                matching = [t for t in transactions if t.date_time.year == today.year
                            and t.date_time.month == today.month and float(t.money) < 0
                            and ((category_id and category_id in set(getattr(t, "category_path_ids", [])))
                                 or (not category_id and self._category_query_match(
                                     question, t, category_catalog, targets)))]
                if category_id and not matching and scope:
                    matching = [t for t in transactions if t.date_time.year == today.year
                                and t.date_time.month == today.month and float(t.money) < 0
                                and bool(scope.intersection(set(getattr(t, "category_path_ids", []))))]
                spent = sum(abs(float(t.money)) for t in matching)
                source = "summed_recorded_transactions"
            category_id = str(meta.get('category_id') or '')
            label = LABELS.get(category_id, PARENT_CATEGORIES.get(category_id, {}).get('label', ''))
            catalog_items = build_catalog(category_catalog)
            catalog_item = catalog_items.get(category_id, {})
            display = catalog_item.get('display_name') or catalog_item.get('label')
            if display and str(display) != category_id:
                label = str(display)
            label = label or str(meta.get('category_name') or category_id or 'Danh mục chưa xác định')
            budget_name = str(budget.get('name') or budget.get('budgetName') or label)
            rows.append({
                "budgetId": str(budget.get("id", "")),
                "categoryId": meta.get("category_id"),
                "category": label, "budgetName": budget_name,
                "limit": round(limit), "spent": round(spent),
                "remaining": round(limit - spent), "overBudget": spent > limit,
                "spentSource": source,
            })
        if len(rows) == 1:
            row = rows[0]
            if row["overBudget"]:
                sentence = f"Ngân sách {row['budgetName']} đã vượt hạn mức {abs(row['remaining']):,.0f}đ (đã chi {row['spent']:,.0f}đ trên {row['limit']:,.0f}đ)."
            else:
                sentence = f"Ngân sách {row['budgetName']} còn {row['remaining']:,.0f}đ trong hạn mức {row['limit']:,.0f}đ (đã ghi nhận {row['spent']:,.0f}đ)."
        else:
            sentence = "Có " + str(len(rows)) + " ngân sách phù hợp: " + "; ".join(
                f"{r['budgetName']} {'vượt' if r['overBudget'] else 'còn'} {abs(r['remaining']):,.0f}đ"
                for r in rows) + "."
        return {"success": True, "intent": "budget_status", "answer": sentence,
                "period": {"type": "month", "month": today.strftime("%m/%Y")},
                "evidence": {"budgets": rows}, "needsInput": []}

    def _rent_estimate(self, transactions: Sequence[Any], today: date,
                       category_catalog: Any = None) -> Tuple[Optional[float], str]:
        resolved = []
        # Prefer the last three calendar months and use the median to reduce
        # distortion from a one-off payment or duplicate entry.
        cutoff = today - timedelta(days=93)
        for t in transactions:
            if t.date_time.date() < cutoff or float(t.money) >= 0:
                continue
            meta = resolve_category_metadata(t, category_catalog)
            if (meta.get("category_id") == "rent_house"
                    or meta.get("parent_category_id") == "expense_fixed"
                    and any(term in _norm_text(getattr(t, "type_name", ""))
                            for term in ("rent", "thue nha", "tien nha"))):
                resolved.append(abs(float(t.money)))
        if not resolved:
            return None, "missing_rent_amount"
        return float(statistics.median(resolved)), "estimated_from_recent_rent_transactions"

    def _affordability_answer(
        self, user_id: str, normalized: Sequence[Any], question: str, today: date,
        category_catalog: Any, advisor_context: Optional[Dict[str, Any]],
    ) -> Dict[str, Any]:
        context = dict(advisor_context or {})
        balance = context.get("available_balance", context.get("current_balance"))
        rent_amount = context.get("target_amount", context.get("rent_amount"))
        rent_source = "provided_by_user"
        targets = self._query_category_targets(question, category_catalog)
        obligation_label = "tiền nhà" if "rent_house" in targets or context.get("rent_amount") is not None else "khoản này"
        if rent_amount is None:
            amount_text = str(question).lower().replace("đ", "d")
            amount_text = "".join(c for c in unicodedata.normalize("NFD", amount_text)
                                  if unicodedata.category(c) != "Mn")
            amount_match = re.search(
                r"\b(\d+(?:[.,]\d+)?)\s*(trieu|tr|m|nghin|ngan|k|dong|d)\b",
                amount_text,
            )
            if amount_match:
                amount = float(amount_match.group(1).replace(",", "."))
                unit = amount_match.group(2)
                multiplier = 1_000_000 if unit in ("trieu", "tr", "m") else 1_000 if unit in ("nghin", "ngan", "k") else 1
                rent_amount, rent_source = amount * multiplier, "parsed_from_question"
            elif any(t in targets for t in ("rent_house", "expense_fixed")):
                rent_amount, rent_source = self._rent_estimate(normalized, today, category_catalog)
        if balance is None:
            return {
                "success": True, "intent": "affordability_check", "answer":
                "Chưa thể kết luận bạn có đủ tiền cho khoản này vì chưa có số dư khả dụng hiện tại.",
                "needsInput": ["available_balance"], "evidence": {"rentAmount": rent_amount,
                "rentAmountSource": rent_source},
            }
        if rent_amount is None:
            return {
                "success": True, "intent": "affordability_check", "answer":
                "Mình chưa xác định được số tiền cần thanh toán. Hãy cung cấp target_amount hoặc nêu rõ số tiền trong câu hỏi.",
                "needsInput": ["rent_amount"], "evidence": {"availableBalance": float(balance)},
            }

        balance = float(balance)
        rent_amount = float(rent_amount)
        days_left = (date(today.year, today.month,
                          calendar.monthrange(today.year, today.month)[1]) - today).days
        horizon = min(30, max(0, days_left))
        advisor = {}
        try:
            if horizon == 0:
                raise StopIteration("Đã đến ngày cuối tháng; dùng số dư tại thời điểm hỏi.")
            advisor_context_full = {
                **context, "reference_date": today.isoformat(), "horizon_days": horizon,
                "available_balance": balance,
                "category_catalog": category_catalog,
            }
            advisor = _plain(self.lstm.build_advisor(user_id, list(normalized), advisor_context_full))
        except StopIteration:
            advisor = {"warnings": [], "timeline": []}
        except Exception as exc:
            advisor = {"warnings": [f"Không tạo được lịch dòng tiền: {exc}"], "timeline": []}

        timeline = advisor.get("timeline", []) or []
        projected = timeline[-1].get("projectedBalance") if timeline else balance
        # If the user's event list already includes the rent bill, it is already
        # subtracted by the advisor and must not be deducted twice.
        normalized_rent_words = ("rent", "thue nha", "tien nha")
        rent_already_reserved = any(
            event.get("confirmed") is True
            and event.get("kind") == "expense"
            and any(word in _norm_text(event.get("title", "")) for word in normalized_rent_words)
            for row in timeline for event in row.get("events", [])
        )
        after_rent = float(projected if projected is not None else balance)
        if not rent_already_reserved:
            after_rent -= rent_amount
        enough = after_rent >= 0
        answer = (f"Theo số dư hiện tại và các khoản đã xác nhận/dự báo đến cuối tháng, "
                  f"bạn {'có thể' if enough else 'có nguy cơ không thể'} dành khoảng "
                  f"{rent_amount:,.0f}đ cho {obligation_label}. Sau khoản này, dòng tiền ước tính còn "
                  f"{after_rent:,.0f}đ.")
        salary_suggestions = advisor.get("salaryRecommendations", []) or []
        if salary_suggestions:
            answer += " Lương dự kiến chưa xác nhận không được tính vào số dư này."
        return {
            "success": True, "intent": "affordability_check", "answer": answer,
            "needsInput": [], "evidence": {
                "availableBalance": round(balance), "estimatedBalanceBeforeRent": round(float(projected or balance)),
                "rentAmount": round(rent_amount), "rentAmountSource": rent_source,
                "rentAlreadyReserved": rent_already_reserved,
                "estimatedBalanceAfterRent": round(after_rent), "horizonDays": horizon,
                "firstShortfallDate": advisor.get("firstShortfallDate"),
                "forecastMethod": "personal_advisor_cashflow_projection" if timeline else "current balance only",
                "warnings": advisor.get("warnings", []),
                "estimatedSalaryCountedAsConfirmed": False,
            },
        }

    def _monthly_comparison(self, normalized, question, today, catalog, targets, diagnostics):
        text = _norm_text(question)
        current_start = date(today.year, today.month, 1)
        previous_end = current_start - timedelta(days=1)
        previous_start = date(previous_end.year, previous_end.month, 1)
        same_days = any(w in text for w in ("cung so ngay", "cung ky", "same days", "month to date"))
        if same_days:
            previous_end = date(previous_end.year, previous_end.month,
                                min(today.day, previous_end.day))
        direction = "income" if any(w in text for w in
            ("thu nhap", "tong thu", "tien vao", "luong", "income", "salary")) or "income" in targets else "expense"
        if any(w in text for w in ("chi tieu", "tong chi", "chi ra", "expense", "spending")):
            direction = "expense"
        incoming = direction == "income"
        def select(start, end):
            return [t for t in self._within(normalized, start, end)
                    if (t.money > 0 if incoming else t.money < 0)
                    and (not targets or self._category_query_match(question, t, catalog, targets))]
        current = select(current_start, today)
        previous = select(previous_start, previous_end)
        current_amount = sum(abs(float(t.money)) for t in current)
        previous_amount = sum(abs(float(t.money)) for t in previous)
        delta = current_amount - previous_amount
        pct = round(delta / previous_amount * 100, 1) if previous_amount else None
        by_parent = any(w in text for w in ("danh muc cha", "nhom cha", "parent"))
        grouped = any(w in text for w in ("tung danh muc", "cac danh muc", "theo danh muc", "danh muc cha", "by category", "each category", "parent"))
        rows = {}
        for period, txs in (("current", current), ("previous", previous)):
            for tx in txs:
                cid = (getattr(tx, "parent_category_id", "") or getattr(tx, "category_group_id", "")
                       or getattr(tx, "category_id", "") or "unclassified") if by_parent else (getattr(tx, "category_id", "") or "unclassified")
                label = LABELS.get(cid, PARENT_CATEGORIES.get(cid, {}).get("label", cid))
                row = rows.setdefault(cid, {"categoryId": cid, "categoryName": label,
                    "currentAmount": 0, "previousAmount": 0, "currentCount": 0, "previousCount": 0})
                row[period + "Amount"] += abs(float(tx.money))
                row[period + "Count"] += 1
        for row in rows.values():
            row["change"] = row["currentAmount"] - row["previousAmount"]
            row["changePercent"] = round(row["change"] / row["previousAmount"] * 100, 1) if row["previousAmount"] else None
        ordered = sorted(rows.values(), key=lambda row: (-row["currentAmount"], row["categoryId"]))
        label = "Thu nhập" if incoming else "Chi tiêu"
        if targets:
            label += " / " + ", ".join(LABELS.get(t, PARENT_CATEGORIES.get(t, {}).get("label", t)) for t in targets)
        lines = [f"{label}: tháng {today:%m/%Y} đã ghi nhận {current_amount:,.0f}đ; tháng {previous_start:%m/%Y} ghi nhận {previous_amount:,.0f}đ."]
        def change_sentence(value, percent):
            wording = "tăng" if value > 0 else "giảm" if value < 0 else "không đổi"
            return f"{wording} {abs(value):,.0f}đ" + (f" ({abs(percent):.1f}%)" if percent is not None else "; kỳ trước bằng 0 nên không tính tỷ lệ %")
        lines.append(change_sentence(delta, pct) + ".")
        if grouped or len(targets) > 1:
            for row in ordered:
                lines.append(f"• {row['categoryName']}: {row['currentAmount']:,.0f}đ so với {row['previousAmount']:,.0f}đ; " + change_sentence(row['change'], row['changePercent']) + ".")
        warning = (f"Tháng này tính từ {current_start:%d/%m} đến {today:%d/%m}; tháng trước tính từ {previous_start:%d/%m} đến {previous_end:%d/%m}. "
                   "Các tổng chỉ phản ánh giao dịch đã ghi nhận.")
        if not same_days:
            warning += " Tháng này chưa kết thúc; có thể hỏi so sánh cùng số ngày để đối chiếu tiến độ."
        return {"success": True, "intent": "income_period_comparison" if incoming else "spending_period_comparison",
            "answer": "\n".join(lines), "warnings": [warning], "needsInput": [],
            "evidence": {"direction": direction, "matchedCategories": targets,
                "grouping": "parent" if by_parent else "child", "categories": ordered,
                "current": {"startDate": current_start.isoformat(), "endDate": today.isoformat(),
                            "amount": current_amount, direction: current_amount, "transactionCount": len(current)},
                "previous": {"startDate": previous_start.isoformat(), "endDate": previous_end.isoformat(),
                             "amount": previous_amount, direction: previous_amount, "transactionCount": len(previous)},
                "change": delta, "changePercent": pct, "comparisonMode": "same_days" if same_days else "recorded_month_totals",
                "invalidTransactions": diagnostics.get("invalid", 0)}}

    def answer_question(
        self, user_id: str, transactions: Sequence[Any], question: str, *,
        reference_date: Any = None, category_catalog: Any = None,
        advisor_context: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Answer supported cash-flow questions with transaction evidence.

        This is an intent/query handler, not open-ended natural-language AI.
        Unknown/underspecified questions return a clarification request.
        """
        if not question or not str(question).strip():
            raise ValueError("question không được để trống.")
        today = self._reference_day(reference_date)
        normalized, diagnostics = self._normalized(transactions, today, category_catalog)
        text = _norm_text(question)
        targets = self._query_category_targets(question, category_catalog)
        comparison = any(w in text for w in ("so sanh", "so voi", "tang hay giam", "tang khong", "giam khong", "compare", "comparison", "versus", "increase", "decrease"))
        monthly = any(w in text for w in ("thang", "month")) or not any(w in text for w in ("tuan", "week", "nam", "year", "ngay", "day"))
        if comparison and monthly:
            return self._monthly_comparison(normalized, question, today, category_catalog, targets, diagnostics)
        asks_affordability = (
            any(term in text for term in ("du tien", "con du", "co du de", "kha nang chi tra",
                                           "co the mua", "afford", "can i buy"))
            and any(term in text for term in ("tra", "mua", "thanh toan", "tien nha", "tien tro",
                                               "rent", "dien thoai", "xe", "khoan nay", "duoc khong"))
        ) or any(term in text for term in ("du tien tra tien nha", "du tien tra nha", "tra tien nha",
                                           "pay rent", "afford rent", "rent at the end"))
        asks_next_salary = any(x in text for x in ("thang sau", "ky toi", "next month")) and any(
            x in text for x in ("ngay nhan luong", "luong ve ngay nao", "luong khi nao", "nhan luong")
        )
        if asks_next_salary:
            try:
                advisor = _plain(self.lstm.build_advisor(
                    user_id, list(normalized), {**(advisor_context or {}),
                    "reference_date": today.isoformat(), "category_catalog": category_catalog}))
            except Exception as exc:
                advisor = {"salaryRecommendations": [], "warnings": [str(exc)]}
            candidates = advisor.get("salaryRecommendations", []) or []
            if candidates:
                candidate = candidates[0]
                return {"success": True, "intent": "next_salary_date",
                        "answer": (f"Dựa trên {candidate.get('sampleCount', candidate.get('basedOnMonths', 0))} kỳ đã ghi nhận, "
                                   f"ngày nhận lương tháng tới được ước tính là {candidate.get('recommendedDate', candidate.get('nextMonthDueDate', 'chưa xác định'))}. "
                                   "Đây là gợi ý cần xác nhận, chưa được tính là khoản thu chắc chắn."),
                        "evidence": candidate, "needsInput": [], "requiresConfirmation": True}
            return {"success": True, "intent": "next_salary_date",
                    "answer": "Chưa đủ lịch sử nhận lương ổn định để ước tính ngày kỳ tới.",
                    "evidence": {}, "needsInput": ["at_least_two_monthly_salary_records"]}
        if asks_affordability:
            return self._affordability_answer(user_id, normalized, question, today,
                                              category_catalog, advisor_context)

        start, end, period = self._select_period_from_question(question, today)
        selected = self._within(normalized, start, end)
        budget_answer = self._answer_budget_question(
            question, normalized, today, category_catalog, advisor_context)
        if budget_answer is not None:
            return budget_answer

        # Questions like "mình tiêu nhiều nhất vào đâu?" have no category term.
        if any(term in text for term in ("nhieu nhat vao dau", "tieu nhieu nhat", "khoan nao nhieu nhat",
                                         "top category", "most spending")):
            top = self._category_rows(selected)[:5]
            if not top:
                return {"success": True, "intent": "top_spending_categories",
                        "answer": "Chưa có giao dịch chi trong khoảng thời gian này.",
                        "evidence": {"categories": []}, "needsInput": []}
            answer = "Các khoản chi cao nhất là " + "; ".join(
                f"{row['categoryName']}: {row['amount']:,.0f}đ ({row['transactionCount']} giao dịch)"
                for row in top[:3]) + "."
            return {"success": True, "intent": "top_spending_categories", "answer": answer,
                    "period": {"type": period, "startDate": start.isoformat(), "endDate": end.isoformat()},
                    "evidence": {"categories": top}, "needsInput": []}

        # Ask for a category/merchant-specific outflow. Avoid answering an
        # unqualified "how much did I spend" with a guessed scope.
        direction_worded_income = any(w in text for w in ("thu nhap", "nhan duoc", "kiem duoc", "tien vao"))
        direction_worded_expense = any(w in text for w in ("chi", "tieu", "mua", "tra no", "dong phi"))
        income_targets = {"income", "salary", "revenue", "other_income", "money_transferred_to",
                          "borrow", "debt_collection", "earn_profit"}
        target_is_income = direction_worded_income or bool(set(targets).intersection(income_targets))
        if direction_worded_expense:
            target_is_income = False
        direction = "income" if target_is_income else "expense"
        candidates = [t for t in selected
                      if (float(t.money) > 0 if direction == "income" else float(t.money) < 0)
                      and self._category_query_match(question, t, category_catalog, targets)]
        if candidates:
            amount = sum(abs(float(t.money)) for t in candidates)
            category_names = sorted({str(t.type_name) for t in candidates})
            label = ", ".join(category_names[:3])
            verb = "thu nhận" if direction == "income" else "chi"
            return {
                "success": True, "intent": "cashflow_by_category_or_merchant",
                "answer": f"Từ {start.strftime('%d/%m/%Y')} đến {end.strftime('%d/%m/%Y')}, bạn đã ghi nhận {verb} {amount:,.0f}đ ở {label} ({len(candidates)} giao dịch).",
                "period": {"type": period, "startDate": start.isoformat(), "endDate": end.isoformat()},
                "evidence": {"amount": round(amount), "transactionCount": len(candidates),
                             "categoryNames": category_names, "transactionIds": [t.id for t in candidates],
                             "direction": direction,
                             "dataCompleteness": "recorded_transactions_only",
                             "invalidTransactions": diagnostics.get("invalid", 0)},
                "needsInput": [],
            }

        if targets and any(w in text for w in ("bao nhieu", "nhieu khong", "da chi", "tieu", "nhan duoc", "da nhan")):
            queried_labels = [LABELS.get(t, PARENT_CATEGORIES.get(t, {}).get("label", t.replace("_", " ")))
                             for t in targets]
            label = ", ".join(dict.fromkeys(queried_labels))
            return {
                "success": True, "intent": "cashflow_by_category_or_merchant",
                "answer": f"Không tìm thấy giao dịch phù hợp với {label} trong kỳ {start.strftime('%d/%m/%Y')}–{end.strftime('%d/%m/%Y')}. Điều này chỉ có nghĩa là chưa có giao dịch được ghi nhận khớp; không khẳng định bạn không phát sinh khoản đó.",
                "period": {"type": period, "startDate": start.isoformat(), "endDate": end.isoformat()},
                "evidence": {"amount": 0, "transactionCount": 0, "matchedCategories": targets,
                             "dataCompleteness": "recorded_transactions_only"},
                "needsInput": [],
            }

        if any(term in text for term in ("tang khong", "giam khong", "tang hay giam", "so voi thang truoc",
                                         "increase", "decrease")):
            if period == "month":
                prev_end = start - timedelta(days=1)
                prev_start = date(prev_end.year, prev_end.month, 1)
            elif period == "week":
                prev_end = start - timedelta(days=1)
                prev_start = prev_end - timedelta(days=6)
            else:
                prev_start, prev_end = date(start.year - 1, 1, 1), date(start.year - 1, 12, 31)
            current_spend = self._cashflow_totals(selected)["cashOutflow"]
            previous_spend = self._cashflow_totals(self._within(normalized, prev_start, prev_end))["cashOutflow"]
            delta = current_spend - previous_spend
            pct = round(delta / previous_spend * 100, 1) if previous_spend else None
            if previous_spend == 0:
                conclusion = "Kỳ trước không có chi đã ghi nhận nên chưa tính được phần trăm thay đổi."
            else:
                conclusion = f"Chi {'tăng' if delta > 0 else 'giảm' if delta < 0 else 'không đổi'} {abs(delta):,.0f}đ ({abs(pct):.1f}%) so với kỳ trước."
            return {"success": True, "intent": "spending_period_comparison", "answer": conclusion,
                    "evidence": {"current": {"startDate": start.isoformat(), "endDate": end.isoformat(), "expense": current_spend},
                                 "previous": {"startDate": prev_start.isoformat(), "endDate": prev_end.isoformat(), "expense": previous_spend},
                                 "change": round(delta), "changePercent": pct,
                                 "warning": "So sánh chỉ đáng tin khi dữ liệu hai kỳ được nhập tương đối đầy đủ."},
                    "needsInput": []}

        if any(term in text for term in ("bao nhieu", "tong chi", "tong thu", "report", "bao cao",
                                         "tien vao", "tien ra", "dong tien")):
            report = self.generate_report(user_id, transactions, period,
                reference_date=today, start_date=start, end_date=end,
                category_catalog=category_catalog, include_models=False)
            totals = report["totals"]
            return {"success": True, "intent": "period_summary",
                    "answer": (f"Kỳ {start.strftime('%d/%m/%Y')}–{end.strftime('%d/%m/%Y')}: "
                               f"thu vào {totals['cashInflow']:,.0f}đ, chi ra {totals['cashOutflow']:,.0f}đ, "
                               f"dòng tiền ròng {totals['netCashFlow']:,.0f}đ."),
                    "period": {"type": period, "startDate": start.isoformat(), "endDate": end.isoformat()},
                    "evidence": totals, "needsInput": []}

        return {
            "success": True, "intent": "unsupported_or_ambiguous",
            "answer": "Mình chưa chắc bạn đang hỏi khoản nào hoặc khoảng thời gian nào nên chưa muốn đoán. Hãy nêu tên danh mục/địa điểm và kỳ cần xem; câu hỏi về khả năng thanh toán cần thêm số dư hiện tại và số tiền phải trả nếu lịch sử chưa có khoản đó.",
            "needsInput": ["clarify_category_merchant_or_question_intent"],
            "supportedExamples": [
                "Tháng này tôi đã tiêu bao nhiêu cho cà phê?",
                "Tuần này tổng chi của tôi là bao nhiêu?",
                "Từ 01/10/2026 đến 08/10/2026 tôi chi bao nhiêu cho tiền điện?",
                "Tôi đã nhận bao nhiêu tiền lương tháng này?",
                "Ăn uống tháng này có vượt ngân sách không?",
                "Cuối tháng tôi có đủ tiền trả tiền nhà không?",
                "Tháng này tôi tiêu nhiều nhất vào khoản nào?",
                "Chi tiêu tháng này tăng hay giảm so với tháng trước?",
                "Tháng sau tôi dự kiến nhận lương ngày nào?",
            ],
        }

    def build_recommendations(
        self, user_id: str, transactions: Sequence[Any], *,
        reference_date: Any = None, category_catalog: Any = None,
        budgets: Optional[Sequence[Mapping[str, Any]]] = None,
        advisor_context: Optional[Dict[str, Any]] = None,
        savings_rate: float = 0.10,
    ) -> Dict[str, Any]:
        """Combine learned clusters and LSTM insight with transparent proposals."""
        if not 0 <= float(savings_rate) <= 0.5:
            raise ValueError("savings_rate phải nằm trong khoảng 0..0.5.")
        today = self._reference_day(reference_date)
        normalized, diagnostics = self._normalized(transactions, today, category_catalog)
        month_start = date(today.year, today.month, 1)
        this_month = self._within(normalized, month_start, today)
        previous_month_end = month_start - timedelta(days=1)
        previous_month_start = date(previous_month_end.year, previous_month_end.month, 1)
        previous = self._within(normalized, previous_month_start, previous_month_end)
        try:
            cluster = _plain(self.kmeans.cluster_spending(
                user_id, this_month, reference_date=today, category_catalog=category_catalog))
        except Exception as exc:
            cluster = {"success": False, "message": str(exc), "clusters": [], "recommendations": []}
        forecast = self._run_lstm(user_id, normalized, 30, today, {
            **(advisor_context or {}), "budgets": list(budgets or []),
            "category_catalog": category_catalog,
        })
        suggestions: List[Dict[str, Any]] = []
        # Use LSTM's own integrated candidates (which already fuse K-Means,
        # anomaly, budgets and forecast) where available.
        summary = forecast.get("summary", {})
        for row in summary.get("smartRecommendations", []) or []:
            suggestions.append({"source": row.get("sources", []), **row})

        # Offer a savings target only when operating-income history exists.
        month_income = self._cashflow_totals(this_month)["operatingIncome"]
        prior_income = self._cashflow_totals(previous)["operatingIncome"]
        income_values = [x for x in (month_income, prior_income) if x > 0]
        if income_values:
            baseline_income = round(statistics.median(income_values))
            proposed = round(baseline_income * float(savings_rate))
            known_expenses = self._cashflow_totals(this_month)["cashOutflow"]
            available_estimate = max(0, baseline_income - known_expenses)
            target = min(proposed, available_estimate) if available_estimate else 0
            suggestions.append({
                "id": f"savings-target-{today:%Y-%m}", "type": "savings_target",
                "title": "Mục tiêu tiết kiệm tham khảo",
                "suggestion": (f"Có thể đặt mục tiêu tối đa khoảng {target:,.0f}đ cho tháng này "
                               f"(mức tham chiếu {savings_rate:.0%} của thu nhập điển hình). "
                               "Điều chỉnh sau khi tính các hóa đơn và khoản đến hạn chưa ghi nhận."),
                "evidence": {"incomeBaseline": baseline_income, "incomeSourceMonths": len(income_values),
                             "recordedOutflowThisMonth": known_expenses,
                             "proposedBeforeAffordabilityCap": proposed,
                             "proposedAmount": target,
                             "method": "median of current and previous month operating income; capped by recorded cashflow",
                             "notFinancialAdvice": True},
                "sources": ["recorded_transactions"], "requiresUserConfirmation": True,
            })

        optional = [t for t in this_month if float(t.money) < 0
                    and str(getattr(t, "category_id", "")) in self.OPTIONAL_CATEGORY_IDS]
        if optional:
            total_optional = sum(abs(float(t.money)) for t in optional)
            reduction = round(total_optional * 0.10)
            suggestions.append({
                "id": f"optional-spending-{today:%Y-%m}", "type": "optional_spending_review",
                "title": "Rà soát khoản chi linh hoạt",
                "suggestion": (f"Bạn đã ghi nhận {total_optional:,.0f}đ ở các danh mục có thể linh hoạt. "
                               f"Nếu phù hợp với nhu cầu của bạn, thử giảm khoảng 10% ({reduction:,.0f}đ) "
                               "trong kỳ tới; không cắt khoản thiết yếu hoặc nghĩa vụ nợ."),
                "evidence": {"amount": round(total_optional), "transactionCount": len(optional),
                             "candidateReduction": reduction, "categoryIds": sorted({t.category_id for t in optional})},
                "sources": ["category_taxonomy", "recorded_transactions"],
                "requiresUserConfirmation": True,
            })

        # Never present the forecast or a savings proposal as a guaranteed balance.
        return {
            "success": True, "userId": user_id, "analysisMonth": today.strftime("%m/%Y"),
            "recommendations": suggestions[:10],
            "behaviorAnalysis": cluster,
            "forecast": forecast,
            "diagnostics": {
                "kmeansReady": bool(cluster.get("success")),
                "lstmForecastAvailable": bool(forecast.get("available")),
                "savingsRate": float(savings_rate),
                "inputDiagnostics": diagnostics,
                "recommendationCount": len(suggestions[:10]),
                "limitations": [
                    "Thu nhập và chi phí chỉ dựa trên giao dịch đã nhập.",
                    "Mục tiêu tiết kiệm là đề xuất tham khảo, không tự chuyển tiền.",
                    "Dự báo thu nhập, đặc biệt ngày nhận lương, chưa phải khoản thu đã xác nhận.",
                ],
            },
        }


financial_insights_service = FinancialInsightsService()
