"""Bilingual helpers for the deterministic LuxFinance Q&A pipeline.

English is normalized into the same canonical Vietnamese intent vocabulary used
by the existing query engine. The engine still calculates answers from the
user's transactions; only the question phrasing and response presentation are
localized here.
"""
from __future__ import annotations

import re
from datetime import date
from typing import Any, Mapping


EN_CATEGORY_LABELS = {
    "expense": "Expenses", "income": "Income", "expense_living": "Living expenses",
    "expense_fixed": "Fixed expenses", "expense_unexpected": "Unexpected expenses",
    "investment_saving": "Investment and savings", "loan_borrow": "Loans and debt",
    "eating": "Food and drinks", "move": "Transportation", "market": "Groceries",
    "telephone_fee": "Phone bill", "rent_house": "Rent", "water_money": "Water bill",
    "electricity_bill": "Electricity bill", "internet_money": "Internet bill",
    "tv_money": "TV bill", "vehicle_maintenance": "Vehicle maintenance",
    "physical_examination": "Healthcare", "repair_and_decorate_the_house": "Home repairs",
    "housewares": "Household items", "personal_belongings": "Personal items",
    "pet": "Pets", "other_costs": "Other expenses", "sport": "Sports",
    "fun_play": "Entertainment", "beautify": "Beauty and personal care",
    "online_services": "Online services", "gifts_donations": "Gifts and donations",
    "gas_money": "Fuel", "invest": "Investment", "saving": "Savings",
    "education": "Education", "insurance": "Insurance", "borrow": "Borrowed money",
    "loan": "Lending", "pay": "Debt repayment", "pay_interest": "Interest payment",
    "debt_collection": "Debt collection", "earn_profit": "Investment returns",
    "salary": "Salary", "revenue": "Revenue", "other_income": "Other income",
    "money_transferred_to": "Incoming transfer",
}

EN_CATEGORY_ALIASES = {
    "food and drinks": "eating", "food": "eating", "dining": "eating",
    "transportation": "move", "transport": "move", "travel to work": "move",
    "groceries": "market", "phone bill": "telephone_fee", "rent": "rent_house",
    "house rent": "rent_house", "water bill": "water_money", "electricity": "electricity_bill",
    "electric bill": "electricity_bill", "internet": "internet_money", "tv bill": "tv_money",
    "vehicle maintenance": "vehicle_maintenance", "medical": "physical_examination",
    "healthcare": "physical_examination", "home repairs": "repair_and_decorate_the_house",
    "household items": "housewares", "personal items": "personal_belongings",
    "pets": "pet", "other expenses": "other_costs", "entertainment": "fun_play",
    "beauty": "beautify", "personal care": "beautify", "gifts": "gifts_donations",
    "fuel": "gas_money", "investments": "invest", "savings": "saving",
    "education": "education", "insurance": "insurance", "borrowed money": "borrow",
    "debt repayment": "pay", "interest payment": "pay_interest",
    "debt collection": "debt_collection", "salary": "salary", "wages": "salary",
    "revenue": "revenue", "other income": "other_income",
    "living expenses": "expense_living", "fixed expenses": "expense_fixed",
    "unexpected expenses": "expense_unexpected", "investment and savings": "investment_saving",
    "utilities": "expense_fixed", "housing": "rent_house",
}

_EN_TO_VI = [
    (r"\bcan i afford to pay\b|\bdo i have enough money to pay\b|\bwill i have enough money to pay\b", "toi co du tien tra"),
    (r"\bhow much is left in my budget for\b|\bhow much budget do i have left for\b", "ngan sach con bao nhieu cho"),
    (r"\bdid i go over budget\b|\bdid i exceed my budget\b|\bam i over budget\b", "toi co vuot ngan sach khong"),
    (r"\bwhat is my total income and spending\b|\bwhat is my total income and expenses\b", "tong thu chi cua toi"),
    (r"\bcan i afford to pay rent\b|\bwill i be able to pay rent\b", "toi co du tien tra tien nha"),
    (r"\bat the end of this month\b|\bby the end of this month\b", "cuoi thang nay"),
    (r"\bwhat was the total cash flow for\b", "tong dong tien cua"),
    (r"\bwhat was the total income for\b", "tong thu nhap cua"),
    (r"\bwhich category did i spend the most on\b|\bwhich category did i spend most on\b", "danh muc nao chi nhieu nhat"),
    (r"\bwhich category does (.+?) belong to\b", r"\1 thuoc danh muc nao"),
    (r"\bwhat category is (.+?)\b", r"\1 thuoc danh muc nao"),
    (r"\bwere there any unusual transactions\b|\bwere there unusual transactions\b", "co giao dich bat thuong nao"),
    (r"\banalyze my spending habits\b|\banalyse my spending habits\b", "phan tich thoi quen chi tieu cua toi"),
    (r"\bforecast my spending for the next (\d{1,2}) days\b", r"du bao chi tieu \1 ngay toi"),
    (r"\bfor the next (\d{1,2}) days\b", r"trong \1 ngay toi"),
    (r"\bhow much (?:money )?(?:did i|have i|do i) spend(?:ed)? on\b", "toi da chi bao nhieu cho"),
    (r"\bhow much (?:money )?(?:did i|have i|do i) spend\b", "toi da chi bao nhieu"),
    (r"\bhow much (?:did i|have i) earn(?:ed)?\b", "toi da thu nhap bao nhieu"),
    (r"\bhow much (?:did i|have i) receive(?:d)?\b", "toi da nhan bao nhieu"),
    (r"\bwhat is my (?:total )?cash flow\b", "tong dong tien cua toi"),
    (r"\btotal (?:cash flow|income and expenses|income and spending)\b", "tong thu chi"),
    (r"\btotal (?:expenses|spending|expenditure)\b", "tong chi tieu"),
    (r"\btotal income\b", "tong thu nhap"),
    (r"\bspending by (?:parent )?categor(?:y|ies)\b", "chi tieu theo danh muc"),
    (r"\b(?:parent )?categor(?:y|ies)\b", "danh muc"),
    (r"\btransactions?\b", "giao dich"),
    (r"\bhow many times\b", "bao nhieu lan"),
    (r"\bwhat category does\b", "danh muc nao cua"),
    (r"\bwhich category\b", "danh muc nao"),
    (r"\bdid i spend the most on\b|\bdo i spend the most on\b", "toi chi nhieu nhat cho"),
    (r"\bbelong to what category\b", "thuoc danh muc nao"),
    (r"\bmost (?:money )?spent on\b", "chi nhieu nhat vao"),
    (r"\bspend the most\b", "chi nhieu nhat"),
    (r"\bwhich category spends the most\b", "danh muc nao chi nhieu nhat"),
    (r"\bhow much budget (?:is )?(?:left|remaining)\b", "ngan sach con bao nhieu"),
    (r"\bbudget (?:remaining|left)\b", "ngan sach con lai"),
    (r"\b(?:am i|did i) (?:over|exceed) (?:my )?budget\b", "toi co vuot ngan sach khong"),
    (r"\bbudget\b", "ngan sach"), (r"\bspending\b", "chi tieu"),
    (r"\bexpenses?\b", "chi tieu"), (r"\bspend\b", "chi tieu"), (r"\bspent\b", "chi"),
    (r"\bincome\b", "thu nhap"), (r"\bsalary\b", "luong"),
    (r"\bcash flow\b", "dong tien"), (r"\bnet cash flow\b", "dong tien rong"),
    (r"\bcompare\b", "so sanh"), (r"\bcomparison\b", "so sanh"),
    (r"\bversus\b|\bvs\.?\b", "so voi"),
    (r"\baverage\b|\bon average\b", "trung binh"),
    (r"\bshare\b|\bpercentage of\b", "ty trong"),
    (r"\b(?:list|show|display)\b", "liet ke"),
    (r"\b(?:how many|number of)\b", "bao nhieu"),
    (r"\b(?:how much|what is|what was|tell me)\b", "bao nhieu"),
    (r"\b(?:this|current) month\b", "thang nay"), (r"\blast month\b", "thang truoc"),
    (r"\bmonth to date\b", "thang nay"),
    (r"\bthis week\b", "tuan nay"), (r"\blast week\b", "tuan truoc"),
    (r"\bthis year\b|\byear to date\b", "nam nay"), (r"\blast year\b", "nam ngoai"),
    (r"\btoday\b", "hom nay"), (r"\byesterday\b", "hom qua"),
    (r"\bnext month\b", "thang sau"), (r"\bnext week\b", "tuan sau"),
    (r"\bwith\b", "voi"), (r"\bfor\b", "cho"),
    (r"\bby\b", "theo"), (r"\bmy\b", "toi"), (r"\bthe\b", ""), (r"\bin\b", ""),
    (r"\b(?:last|past)\s+(\d{1,3})\s+days\b", r"\1 ngay qua"),
    (r"\bforecast\b|\bpredict(?:ion)?\b", "du bao"),
    (r"\bunusual transactions?\b|\banomal(?:y|ies)\b", "giao dich bat thuong"),
    (r"\bspending habits?\b|\bbehavior(?:al)? analysis\b|\bbehaviour(?:al)? analysis\b", "phan tich thoi quen chi tieu"),
    (r"\bfinancial (?:overview|analysis|health)\b", "tong quan tai chinh"),
    (r"\bafford(?:able|ability)?\b", "du tien thanh toan"),
    (r"\bbased on\b", "dua tren"),
    (r"\banaly[sz]e\b|\banalysis\b", "phan tich"),
    (r"\bwhat about\b|\btell me about\b", "phan tich"),
    (r"\brecommend(?:ation|ations)?\b|\badvice\b", "goi y"),
    (r"\bincrease\b|\bincreased\b", "tang"), (r"\bdecrease\b|\bdecreased\b", "giam"),
    (r"\bmore than\b", "nhieu hon"), (r"\bless than\b", "it hon"),
    (r"\ball time\b|\bentire history\b", "toan bo lich su"),
]


def detect_language(question: str) -> str:
    """Return ``en`` for English wording, otherwise ``vi`` (Vietnamese default)."""
    text = str(question or "").lower()
    if re.search(r"[à-ỹđ]", text):
        return "vi"
    english_markers = r"\b(what|how|when|where|which|show|list|compare|spent|spend|income|expense|budget|month|week|year|today|yesterday|forecast|predict|anomaly|behavior|behaviour|category|transaction|money|cash|salary|average|most|least|hello|hi|thanks|afford|recommendation|analyze|analyse|debt|loan|borrow|repay|owe|lent|paid|pay|overdue|remaining|enough|utilities)\b"
    return "en" if re.search(english_markers, text) else "vi"


def normalize_english_question(question: str) -> str:
    """Map English question phrases to intent words already understood by LuxFinance."""
    text = str(question or "").strip().lower()
    # Month names are converted before the generic word replacements.
    months = {"january": 1, "february": 2, "march": 3, "april": 4, "may": 5,
              "june": 6, "july": 7, "august": 8, "september": 9,
              "october": 10, "november": 11, "december": 12}
    for name, number in months.items():
        text = re.sub(rf"\b{ name }\b", f"thang {number}", text)
    text = re.sub(r"\bthang\s+(1[0-2]|0?[1-9])\s+(20\d{2})\b", r"thang \1 nam \2", text)
    for pattern, replacement in _EN_TO_VI:
        text = re.sub(pattern, replacement, text, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", text).strip()


def canonicalize_english_categories(question: str) -> str:
    """Resolve common English category names to stable LuxFinance IDs."""
    text = str(question or "").lower()
    for phrase, category_id in sorted(EN_CATEGORY_ALIASES.items(), key=lambda item: -len(item[0])):
        text = re.sub(r"(?<![a-z0-9_])" + re.escape(phrase) + r"(?![a-z0-9_])", category_id, text)
    return text


def normalize_english_debt_question(question: str) -> str:
    """Normalize English debt-ledger queries while preserving contact names and IDs."""
    text = str(question or "").strip().lower()
    months = {"january": 1, "february": 2, "march": 3, "april": 4, "may": 5,
              "june": 6, "july": 7, "august": 8, "september": 9,
              "october": 10, "november": 11, "december": 12}
    for name, number in months.items():
        text = re.sub(rf"\b{name}\b", f"thang {number}", text)
    text = re.sub(r"\bthang\s+(1[0-2]|0?[1-9])\s+(20\d{2})\b", r"thang \1 nam \2", text)
    replacements = [
        (r"\bwhat is the difference between borrowing and lending\b|\bwhat is the difference between a loan and a debt\b", "vay va cho vay khac nhau la gi"),
        (r"\bhow much do i owe(?: to)?\b", "toi no"),
        (r"\bhow much does (.+?) owe me\b", r"\1 no toi"),
        (r"\bhow much does (.+?) owe\b", r"\1 no"),
        (r"\bhow much have i paid back to\b|\bhow much have i paid to\b", "toi da tra cho"),
        (r"\bhow much did i pay(?: back)? to\b", "toi da tra cho"),
        (r"\bhow much did (.+?) pay me\b", r"\1 da tra toi"),
        (r"\bhow much did i lend\b", "toi cho vay"),
        (r"\bhow much have i collected from\s+(.+)", r"toi da thu hoi tu \1"),
        (r"\bhow much has (.+?) paid me\b", r"\1 da tra toi"),
        (r"\bwho do i owe\b", "toi no ai"), (r"\bwho owes me\b", "ai no toi"),
        (r"\bhow many (?:debts|loans|payments)\b", "bao nhieu khoan no"),
        (r"\bhow many times have i paid\b", "toi da tra bao nhieu lan"),
        (r"\bwhen is (?:the )?(?:loan|debt) due\b", "khoan no khi nao den han"),
        (r"\bwhat (?:debts|loans) are overdue\b", "khoan no qua han nao"),
        (r"\bwhat (?:debts|loans) are due\b", "khoan no den han nao"),
        (r"\bwhich (?:debts|loans) have i fully repaid\b", "khoan no da tat toan"),
        (r"\b(?:list|show) (?:all )?(?:my )?(?:debts|loans)\b", "liet ke tat ca khoan no"),
        (r"\bpayment history\b|\brepayment history\b", "lich su thanh toan"),
        (r"\blast payment\b|\bmost recent payment\b", "lan thanh toan gan nhat"),
        (r"\bnet debt\b", "no rong"), (r"\bcompare\b|\bcomparison\b", "so sanh"),
        (r"\bborrowed\b|\bborrow\b", "vay"), (r"\blent\b|\blend\b", "cho vay"),
        (r"\bloan\b|\bdebt\b", "khoan no"), (r"\bowe\b|\bowes\b", "no"),
        (r"\brepay(?:ment)?\b|\bpaid back\b", "tra no"),
        (r"\bpaid\b|\bpayment\b", "thanh toan"),
        (r"\boverdue\b", "qua han"), (r"\bdue date\b|\bdue\b", "han tra"),
        (r"\binterest rate\b|\binterest\b", "lai suat"),
        (r"\bhow much\b", "bao nhieu"), (r"\bhow many\b", "bao nhieu"),
        (r"\bthis month\b", "thang nay"), (r"\blast month\b", "thang truoc"),
        (r"\bthis week\b", "tuan nay"), (r"\blast week\b", "tuan truoc"),
        (r"\bthis year\b", "nam nay"), (r"\blast year\b", "nam truoc"),
        (r"\bthis year\b", "nam nay"), (r"\blast year\b", "nam truoc"),
        (r"\btoday\b", "hom nay"), (r"\byesterday\b", "hom qua"),
        (r"\bnext month\b", "thang sau"),
        (r"\bto me\b|\bme\b", "toi"), (r"\bmy\b", "toi"),
        (r"\bwhat\b", "nao"), (r"\bwhich\b", "nao"),
    ]
    for pattern, replacement in replacements:
        text = re.sub(pattern, replacement, text)
    return re.sub(r"\s+", " ", text).strip()


def english_debt_answer(result: Mapping[str, Any]) -> str:
    intent = str(result.get("intent") or "")
    evidence = result.get("evidence") or {}
    stats = evidence
    money = _money
    if intent == "debt_definition":
        return "Borrowing is money you owe; lending is money someone owes you. Remaining debt equals the principal minus recorded payments. A debt is settled when its remaining balance is zero. Overdue status is based on the due date recorded in your ledger."
    if intent == "debt_summary":
        return (f"You owe {money(stats.get('borrowRemaining'))}; you are owed {money(stats.get('lendRemaining'))}. "
                f"There are {stats.get('recordCount', 0)} matching debt record(s). Principal: {money(stats.get('principal'))}; "
                f"paid: {money(stats.get('paid'))}; remaining: {money(stats.get('remaining'))}.")
    if intent == "debt_people":
        rows = evidence.get("contacts") or []
        if not rows:
            return "No matching contacts have an outstanding balance."
        return "Outstanding balances by contact:\n" + "\n".join(f"• {r.get('name')}: payable {money(r.get('borrowRemaining'))}; receivable {money(r.get('lendRemaining'))}." for r in rows)
    if intent == "debt_count":
        return f"There are {evidence.get('recordCount', 0)} matching debt record(s) across {evidence.get('contactCount', 0)} contact(s)."
    if intent == "debt_net":
        return f"Payable: {money(evidence.get('borrowRemaining'))}; receivable: {money(evidence.get('lendRemaining'))}; net debt (payable minus receivable): {money(evidence.get('borrowRemaining', 0) - evidence.get('lendRemaining', 0))}."
    if intent == "debt_payment_count":
        return f"There are {evidence.get('paymentCount', 0)} recorded payment(s), totaling {money(evidence.get('totalPaid'))}."
    if intent == "debt_last_payment":
        rows = evidence.get("payments") or []
        if not rows:
            return "No matching payment was recorded."
        row = rows[0]
        return f"Most recent recorded payment: {row.get('contactName', 'Contact')}, {money(row.get('amount'))}, on {str(row.get('date', ''))[:10]} ."
    if intent == "debt_payments":
        rows = evidence.get("payments") or []
        lines = [f"{len(rows)} payment(s) were recorded. Paid on borrowed debts: {money(evidence.get('paidBorrow'))}; collected on loans: {money(evidence.get('collectedLend'))}."]
        lines.extend(f"• {str(r.get('date', ''))[:10]} — {r.get('contactName')}: {money(r.get('amount'))}" for r in rows[:20])
        return "\n".join(lines)
    if intent == "debt_due_dates":
        rows = evidence.get("debts") or []
        if not rows:
            return "No outstanding debt matched the requested due-date conditions."
        lines = [f"{r.get('contactName')}: {'pay' if r.get('direction') == 'borrow' else 'collect'} {money(r.get('remaining'))}; due {str(r.get('dueDate') or 'date not set')[:10]}" for r in rows[:20]]
        lines.append("Due dates are taken from the ledger; they are not predicted by a model.")
        return "\n".join(lines)
    if intent == "debt_affordability":
        if evidence.get("availableBalance") is not None:
            return f"Available wallet balance: {money(evidence.get('availableBalance'))}; amount due: {money(evidence.get('payableDue'))}; shortfall: {money(evidence.get('shortfall'))}."
        return "I can’t check this without the available wallet balance."
    if intent == "debt_ranking":
        contacts = evidence.get("contacts") or []
        if contacts:
            row = contacts[0]
            return f"Highest matching outstanding balance: {row.get('name')}, {money(row.get('remaining'))}."
        rows = evidence.get("debts") or []
        if rows:
            return f"Largest or highest-priority matching debt: {rows[0].get('contactName')}, {money(rows[0].get('remaining'))}."
        return "No outstanding debt matched the ranking request."
    if intent == "debt_settlement_status":
        return f"Remaining balance: {money(evidence.get('remaining'))}."
    messages = {
        "debt_comparison_clarification": "Would you like to compare payments by payment date or outstanding balances as of specific dates? Please specify the comparison periods.",
        "debt_read_only": "Debt Q&A is read-only. Add, edit, delete, or record a payment in the Debt Ledger screen.",
        "debt_contact_clarification": "More than one contact matches. Please provide the full name or contact ID.",
        "debt_contact_not_found": "That contact was not found in your debt ledger. Check the name or contact ID.",
        "debt_not_found": "That debt record was not found in the requested scope.",
        "debt_data_invalid": "Some debt records are invalid, so the totals may be incomplete. Please review the Debt Ledger.",
        "debt_interest_unsupported": "The ledger stores principal and payments, but not interest terms, so interest cannot be calculated accurately.",
        "debt_forecast_unsupported": "There is no repayment schedule or commitment in the ledger to forecast a payoff date.",
        "debt_future_balance": "A future debt balance cannot be determined without a repayment plan. You can ask which debts are due during that period.",
        "debt_period_clarification": "The date or period is invalid. Use a date such as dd/MM/yyyy or specify a month and year.",
    }
    return messages.get(intent, "I processed your debt question. The supporting records and figures are available in the response details.")


def _date_range(period: Mapping[str, Any] | None) -> str:
    period = period or {}
    start, end = period.get("startDate"), period.get("endDate")
    if start and end:
        return f"from {date.fromisoformat(str(start)[:10]):%b %d, %Y} to {date.fromisoformat(str(end)[:10]):%b %d, %Y}"
    if period.get("month"):
        return str(period["month"])
    return "the selected period"


def _money(value: Any) -> str:
    try:
        return f"{float(value or 0):,.0f} VND"
    except (TypeError, ValueError):
        return "0 VND"


def _label(row: Mapping[str, Any]) -> str:
    cid = str(row.get("categoryId") or row.get("category_id") or row.get("id") or "")
    return EN_CATEGORY_LABELS.get(cid, str(row.get("categoryName") or row.get("name") or cid.replace("_", " ").title()))


def english_answer(result: dict[str, Any]) -> str:
    """Render English text from structured evidence; never translate user data."""
    intent = str(result.get("intent") or "")
    evidence = result.get("evidence") or {}
    period = _date_range(result.get("period"))
    categories = evidence.get("categories") or evidence.get("topCategories") or []
    if intent == "greeting":
        return "Hello! Ask me about your income, expenses, categories, budgets, forecasts, or unusual transactions."
    if intent in {"out_of_scope", "unsupported_or_ambiguous"}:
        return "I can answer questions about your personal finances. Include the category or merchant and the time period, for example: “How much did I spend this month?”"
    if intent in {"period_clarification", "budget_period_clarification", "forecast_period_clarification", "anomaly_period_clarification"}:
        return "I can’t calculate this yet because the requested period is invalid, has not happened, or is not supported. Please choose a period with recorded data."
    if intent in {"category_summary", "category_average", "transaction_details"}:
        direction = evidence.get("direction", "expense")
        amount = evidence.get("amount", evidence.get("expense", evidence.get("income", 0)))
        scope = ", ".join(EN_CATEGORY_LABELS.get(str(x), str(x).replace("_", " ").title()) for x in evidence.get("matchedCategories", []))
        scope = scope or ("income and expenses" if direction == "both" else "income" if direction == "income" else "expenses")
        count = evidence.get("transactionCount", evidence.get("matchedTransactionCount", 0))
        if intent == "transaction_details":
            rows = evidence.get("transactions") or []
            if not rows:
                return f"No recorded transactions matched {scope} for {period}."
            lines = [f"Transactions for {scope} ({period}):"]
            lines.extend(f"• {str(row.get('dateTime', ''))[:16].replace('T', ' ')} — {_label(row)} — {_money(row.get('money'))} — {row.get('note') or 'No note'}" for row in rows)
            return "\n".join(lines)
        verb = "income" if direction == "income" else "cash flow" if direction == "both" else "spending"
        answer = f"For {scope}, total {verb} {period}: {_money(amount)} across {count} recorded transaction(s)."
        if intent == "category_average":
            answer += f" Average per transaction: {_money(evidence.get('averageTransaction'))}; average per calendar day: {_money(evidence.get('averageDay'))}."
        if not count:
            answer = f"No recorded transactions matched {scope} for {period}."
        return answer
    if intent == "cashflow_by_category_or_merchant":
        count = evidence.get("transactionCount", 0)
        amount = evidence.get("amount", 0)
        direction = evidence.get("direction", "expense")
        names = [EN_CATEGORY_LABELS.get(str(cid), str(cid).replace("_", " ").title())
                 for cid in evidence.get("matchedCategories", [])]
        if not names:
            names = [str(name) for name in evidence.get("categoryNames", [])]
        scope = ", ".join(dict.fromkeys(names)) or "the requested category or merchant"
        if not count:
            return f"No matching {direction} transactions were recorded for {scope} during {period}."
        label = "income" if direction == "income" else "expenses"
        return f"From {period}, you recorded {_money(amount)} in {label} for {scope} across {count} transaction(s)."
    if intent in {"period_comparison", "category_comparison", "spending_period_comparison", "income_period_comparison"}:
        current, previous = evidence.get("current") or {}, evidence.get("previous") or {}
        if current or previous:
            current_amount = current.get("amount", current.get("expense", current.get("income", 0)))
            previous_amount = previous.get("amount", previous.get("expense", previous.get("income", 0)))
            change = evidence.get("change", float(current_amount or 0) - float(previous_amount or 0))
            pct = evidence.get("changePercent")
            phrase = "increased" if change > 0 else "decreased" if change < 0 else "did not change"
            answer = f"Current period: {_money(current_amount)}; previous period: {_money(previous_amount)}. Spending {phrase} by {_money(abs(change))}"
            if pct is not None:
                answer += f" ({abs(float(pct)):.1f}%)."
            else:
                answer += "; the previous period was zero, so a percentage change cannot be calculated."
            if categories:
                answer += "\n" + "\n".join(f"• {_label(row)}: {_money(row.get('currentAmount'))} vs {_money(row.get('previousAmount'))}." for row in categories)
            return answer
        if categories:
            lines = [f"Comparison for {period}:"]
            lines.extend(f"• {_label(row)}: {_money(row.get('amount'))} across {row.get('transactionCount', 0)} transaction(s)." for row in categories)
            change = evidence.get("change")
            if change is not None:
                lines.append(f"Change: {_money(abs(change))} {'higher' if change > 0 else 'lower' if change < 0 else 'unchanged'}. ")
            return "\n".join(lines)
    if intent == "budget_status":
        budgets = evidence.get("budgets") or []
        if not budgets:
            return "No budget data was provided, so I can’t determine the remaining amount or whether a limit was exceeded."
        lines = [f"Budget status for {period}:"]
        for row in budgets:
            name = _label(row) if row.get("categoryId") or row.get("category_id") else (row.get("budgetName") or "Budget")
            remaining = row.get("remaining", 0)
            if row.get("overBudget"):
                lines.append(f"• {name}: over budget by {_money(abs(remaining))}; spent {_money(row.get('spent'))} of {_money(row.get('limit'))}.")
            else:
                lines.append(f"• {name}: {_money(remaining)} remaining; spent {_money(row.get('spent'))} of {_money(row.get('limit'))}.")
        return "\n".join(lines)
    if intent == "period_summary":
        return (f"For {period}: income {_money(evidence.get('cashInflow'))}, expenses {_money(evidence.get('cashOutflow'))}, "
                f"net cash flow {_money(evidence.get('netCashFlow'))}.")
    if intent == "top_spending_categories":
        if not categories:
            return "No recorded expenses were found for this period."
        return "Top spending categories:\n" + "\n".join(f"• {_label(row)}: {_money(row.get('amount'))} ({row.get('transactionCount', row.get('count', 0))} transaction(s))." for row in categories[:5])
    if intent == "category_definition":
        rows = evidence.get("categories") or []
        if not rows:
            return "No matching category was found in the current category list."
        return "Categories:\n" + "\n".join(f"• {_label(row)}" + (f" — under {EN_CATEGORY_LABELS.get(str(row.get('parentId')), str(row.get('parentId')).replace('_', ' ').title())}" if row.get("parentId") else "") for row in rows)
    if intent == "spending_forecast":
        if evidence.get("predictedExpense") is not None:
            return f"Forecast for the next {evidence.get('forecastDays', 7)} day(s): estimated expenses {_money(evidence.get('predictedExpense'))} and income {_money(evidence.get('predictedIncome'))}."
        return "There is not enough recorded history to produce a reliable forecast yet."
    if intent == "anomaly_analysis":
        rows = evidence.get("anomalies") or []
        if rows:
            return f"{len(rows)} transaction(s) need review:\n" + "\n".join(f"• {_label(row) if row.get('categoryId') or row.get('category_id') else 'Transaction'}: {_money(abs(row.get('money', 0)))} — flagged as unusual; review its context." for row in rows[:5])
        return "No unusual transaction was detected for this period." if evidence.get("modelReady") else "No rule-based warning was found, but there is not enough data for the model to determine whether spending is normal."
    if intent == "behavior_analysis":
        clusters = evidence.get("clusters") or []
        if not clusters:
            return "There is not enough recorded spending to identify a behavior pattern yet."
        lines = [f"Spending behavior analysis for {period}:"]
        for row in clusters[:5]:
            chars = row.get("characteristics", {})
            name = row.get("cluster_name") or row.get("clusterName") or row.get("profile") or "Spending pattern"
            name = {
                "🔥 Khoản Chi Trọng Yếu": "High-impact expenses",
                "🏠 Sinh Hoạt Phí Cốt Lõi": "Core living expenses",
                "🥂 Phong Cách Sống & Hưởng Thụ": "Lifestyle and entertainment",
                "☕ Chi Tiêu Nhỏ Lẻ (Latte Factor)": "Frequent small purchases",
                "🌱 Tích Lũy & Phát Triển": "Saving and investment",
                "🧾 Quản lý vay và trả nợ": "Borrowing and debt payments",
                "🧩 Chi Phí Phát Sinh Khác": "Mixed or unexpected expenses",
            }.get(name, name)
            lines.append(f"• {name}: {chars.get('transactionCount', 0)} transaction(s), total {_money(chars.get('totalAmount', 0))}.")
        return "\n".join(lines)
    if intent == "financial_overview":
        current = evidence.get("current") or {}
        previous = evidence.get("previous") or {}
        lines = [f"Financial overview for {period}:", f"• Income: {_money(current.get('income'))}; expenses: {_money(current.get('expense'))}; net: {_money(current.get('net'))}."]
        if previous:
            lines.append(f"• Previous period: income {_money(previous.get('income'))}; expenses {_money(previous.get('expense'))}; net {_money(previous.get('net'))}.")
        if categories:
            lines.extend(f"• {_label(row)}: {_money(row.get('amount'))} ({row.get('sharePercent', 0)}% of spending)." for row in categories[:5])
        for row in evidence.get("budgets", []):
            name = _label(row) if row.get("categoryId") or row.get("category_id") else row.get("budgetName", "Budget")
            lines.append(f"• Budget {name}: spent {_money(row.get('spent'))} of {_money(row.get('limit'))}; remaining {_money(row.get('remaining'))}.")
        return "\n".join(lines)
    if intent == "affordability_check":
        if evidence.get("estimatedBalanceAfterRent") is not None:
            return (f"Based on the available balance and confirmed/projected items, the estimated balance after this payment is "
                    f"{_money(evidence.get('estimatedBalanceAfterRent'))}. The amount checked was {_money(evidence.get('rentAmount'))}.")
        return "I can’t determine affordability without the current available balance and the amount due."
    if intent == "next_salary_date":
        candidate = evidence.get("recommendedDate") or evidence.get("nextMonthDueDate")
        if candidate:
            return f"Based on the recorded salary history, the next salary date is estimated to be {candidate}. This is an estimate, not confirmed income."
        return "There is not enough consistent salary history to estimate the next salary date."
    if intent == "financial_recommendations":
        rows = evidence.get("recommendations") or []
        if rows:
            lines = ["Items to review based on your recorded data:"]
            for row in rows[:5]:
                kind = row.get("type") or row.get("id", "")
                details = row.get("evidence") or {}
                if kind == "savings_target":
                    lines.append(f"• Savings target: consider setting aside up to {_money(details.get('proposedAmount'))}, based on recorded income and expenses. Confirm upcoming bills first.")
                elif kind == "optional_spending_review":
                    lines.append(f"• Flexible spending: recorded total {_money(details.get('amount'))}; a possible 10% reduction is {_money(details.get('candidateReduction'))}. Keep essential costs and debt obligations covered.")
                else:
                    lines.append("• Review this item using the supporting figures and transaction details before acting.")
            return "\n".join(lines)
        return "There is not enough evidence in the current data to make a recommendation."
    if intent == "clarification":
        return "Please check the requested amount or time period and try again."
    # The structured evidence remains available to clients even when a specialized
    # English renderer is not needed for a less common response type.
    return "I processed your finance question. The supporting figures and matched records are available in the response details."


def localize_result(result: dict[str, Any], language: str) -> dict[str, Any]:
    result["language"] = language
    if language == "en":
        result["answer"] = english_answer(result)
        if result.get("supportedExamples"):
            result["supportedExamples"] = [
                "How much did I spend on food this month?",
                "What were my total expenses this week?",
                "How much did I spend on electricity from 01/10/2026 to 08/10/2026?",
                "How much salary did I receive this month?",
                "Did I exceed my food budget this month?",
                "Can I afford to pay rent at the end of this month?",
                "Which category did I spend the most on this month?",
                "Did my spending increase or decrease compared with last month?",
                "When am I likely to receive my salary next month?",
            ]
        warning_map = (
            ("Kết quả chỉ dựa trên lịch sử đã cung cấp; dữ liệu có thể chưa đầy đủ.", "This result uses only the history provided, which may be incomplete."),
            ("Kết quả dựa trên giao dịch đã ghi nhận; lịch sử có thể chưa đầy đủ.", "This result uses recorded transactions only; your history may be incomplete."),
            ("Đây là số dự báo từ lịch sử cá nhân; không tính là giao dịch hoặc thu nhập đã xác nhận.", "This is a forecast based on your history, not a confirmed transaction or income."),
            ("Hãy kiểm tra bối cảnh giao dịch; kết quả không tự động xóa hay sửa khoản chi.", "Review the transaction context; this result does not automatically delete or change any transaction."),
            ("So sánh cùng số ngày đã diễn ra.", "The comparison uses the same number of elapsed days."),
            ("Hai kỳ có thể có độ dài khác nhau.", "The two periods may have different lengths."),
            ("Chênh lệch thu chi không phải số dư tài khoản hoặc khoản tiết kiệm đã xác nhận.", "Net cash flow is not the same as a confirmed account balance or savings amount."),
            ("Tháng đang diễn ra so sánh cùng số ngày; tháng đã kết thúc so sánh cả tháng.", "An ongoing month is compared using the same elapsed days; completed months use full-month totals."),
            ("Các tổng chỉ phản ánh giao dịch đã ghi nhận.", "Totals reflect recorded transactions only."),
        )
        result["warnings"] = [next((en for vi, en in warning_map if vi in str(w)),
                                   "Please review the supporting data and limitations for this result.")
                              for w in result.get("warnings", [])]
    return result
