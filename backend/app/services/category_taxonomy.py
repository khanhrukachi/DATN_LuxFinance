"""Category hierarchy support shared by the analysis services.

The preferred input is a stable category id plus its parent id. Legacy numeric
``type`` values are resolved only when the caller sends ``category_catalog``;
the service never assumes that a numeric index has the same meaning across app
versions.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Any, Dict, Iterable, List, Mapping, Optional, Set


PARENT_CATEGORIES: Dict[str, Dict[str, str]] = {
    "income": {"label": "Thu nhập", "class": "income"},
    "expense_living": {
        "label": "Chi tiêu sinh hoạt",
        "class": "living_expense",
    },
    "expense_fixed": {
        "label": "Chi tiêu cố định",
        "class": "fixed_expense",
    },
    "expense_unexpected": {
        "label": "Chi tiêu phát sinh",
        "class": "unexpected_expense",
    },
    "investment_saving": {
        "label": "Đầu tư và tiết kiệm",
        "class": "investment_saving",
    },
    "loan_borrow": {
        "label": "Vay, cho vay và trả nợ",
        "class": "debt_activity",
    },
}

CHILD_PARENT: Dict[str, str] = {
    "eating": "expense_living",
    "move": "expense_living",
    "market": "expense_living",
    "telephone_fee": "expense_living",
    "rent_house": "expense_fixed",
    "water_money": "expense_fixed",
    "electricity_bill": "expense_fixed",
    "internet_money": "expense_fixed",
    "tv_money": "expense_fixed",
    "vehicle_maintenance": "expense_unexpected",
    "physical_examination": "expense_unexpected",
    "repair_and_decorate_the_house": "expense_unexpected",
    "housewares": "expense_unexpected",
    "personal_belongings": "expense_unexpected",
    "pet": "expense_unexpected",
    "other_costs": "expense_unexpected",
    "sport": "expense_unexpected",
    "fun_play": "expense_unexpected",
    "beautify": "expense_unexpected",
    "online_services": "expense_unexpected",
    "gifts_donations": "expense_unexpected",
    "gas_money": "expense_unexpected",
    "invest": "investment_saving",
    "education": "investment_saving",
    "insurance": "investment_saving",
    "saving": "investment_saving",
    "borrow": "loan_borrow",
    "loan": "loan_borrow",
    "pay": "loan_borrow",
    "pay_interest": "loan_borrow",
    "debt_collection": "loan_borrow",
    "salary": "income",
    "revenue": "income",
    "other_income": "income",
    "money_transferred_to": "income",
}

ROLE_BY_CATEGORY: Dict[str, str] = {
    "invest": "investment_contribution",
    "saving": "savings_transfer",
    "borrow": "borrowed_principal",
    "loan": "lending_principal",
    "pay": "debt_repayment",
    "pay_interest": "debt_interest",
    "debt_collection": "debt_collection",
    "earn_profit": "investment_return",
    "education": "education_expense",
    "insurance": "insurance_expense",
    "rent_house": "housing_bill",
    "water_money": "utility_bill",
    "electricity_bill": "utility_bill",
    "internet_money": "utility_bill",
    "tv_money": "utility_bill",
    "telephone_fee": "utility_bill",
    "other_costs": "unexpected_expense",
    # Salary is normally received once per month. Keep it distinct from
    # transaction-by-transaction or business income so forecast code can use a
    # monthly cadence instead of extrapolating it as a daily flow.
    "salary": "fixed_monthly_income",
    "revenue": "business_income",
    "other_income": "other_income",
    "money_transferred_to": "transfer_receipt",
}

ROLE_CLASS: Dict[str, str] = {
    "living_expense": "living_expense",
    "fixed_expense": "fixed_expense",
    "unexpected_expense": "unexpected_expense",
    "investment_saving": "investment_saving",
    "debt_activity": "debt_activity",
    "investment_contribution": "investment",
    "savings_transfer": "saving",
    "borrowed_principal": "borrowing",
    "lending_principal": "lending",
    "debt_repayment": "debt_repayment",
    "debt_interest": "debt_cost",
    "debt_collection": "debt_collection",
    "investment_return": "investment_return",
    "education_expense": "education",
    "insurance_expense": "insurance",
    "housing_bill": "fixed_cost",
    "utility_bill": "fixed_cost",
    "fixed_monthly_income": "fixed_income",
    "regular_income": "income",
    "business_income": "income",
    "other_income": "income",
    "transfer_receipt": "transfer", 
}

ALIASES: Dict[str, str] = {
    "an_uong": "eating", "di_chuyen": "move", "di_lai": "move",
    "tien_nha": "rent_house", "thue_nha": "rent_house",
    "tien_dien": "electricity_bill", "dien": "electricity_bill",
    "tien_nuoc": "water_money", "mua_sam": "shopping",
    "giai_tri": "fun_play", "vui_choi": "fun_play",
    "hoc_phi": "education", "hoc_tap": "education",
    "y_te": "physical_examination", "kham_benh": "physical_examination",
    "tiet_kiem": "saving", "dau_tu": "invest", "tra_no": "pay",
    "tra_lai": "pay_interest", "vay_tien": "borrow", "cho_vay": "loan",
}

LABELS: Dict[str, str] = {
    "eating": "Ăn uống", "move": "Di chuyển", "market": "Đi chợ",
    "telephone_fee": "Điện thoại", "rent_house": "Tiền nhà",
    "water_money": "Tiền nước", "electricity_bill": "Tiền điện",
    "internet_money": "Internet", "tv_money": "Truyền hình",
    "vehicle_maintenance": "Bảo dưỡng xe", "physical_examination": "Y tế",
    "repair_and_decorate_the_house": "Sửa chữa nhà", "housewares": "Đồ gia dụng",
    "personal_belongings": "Đồ cá nhân", "pet": "Thú cưng",
    "other_costs": "Chi phí khác", "sport": "Thể thao",
    "fun_play": "Vui chơi", "beautify": "Làm đẹp",
    "online_services": "Dịch vụ trực tuyến", "gifts_donations": "Quà tặng",
    "gas_money": "Xăng, nhiên liệu", "invest": "Đầu tư", "saving": "Tiết kiệm",
    "education": "Giáo dục", "insurance": "Bảo hiểm", "borrow": "Vay tiền",
    "loan": "Cho vay", "pay": "Trả nợ", "pay_interest": "Trả lãi",
    "debt_collection": "Thu hồi nợ",
    "salary": "Lương", "revenue": "Doanh thu", "other_income": "Thu nhập khác",
    "money_transferred_to": "Tiền nhận về",
}


class CategoryCatalog(dict):
    """Internal indexed catalog so a request's listType is parsed only once."""


def normalize_key(value: Any) -> str:
    value = str(value or "").strip().lower().replace("đ", "d")
    value = "".join(c for c in unicodedata.normalize("NFD", value)
                    if unicodedata.category(c) != "Mn")
    value = re.sub(r"[\s&-]+", "_", value).strip("_")
    return ALIASES.get(value, value)


def _get(obj: Any, *keys: str, default: Any = None) -> Any:
    for key in keys:
        value = obj.get(key) if isinstance(obj, Mapping) else getattr(obj, key, None)
        if value is not None:
            return value
    return default


def build_catalog(catalog: Any) -> Dict[str, Dict[str, Any]]:
    """Index listType-like category catalog by stable id and numeric list index."""
    if isinstance(catalog, CategoryCatalog):
        return catalog
    if catalog is None:
        return {}
    if isinstance(catalog, Mapping):
        items: Iterable[Any] = catalog.values()
    elif isinstance(catalog, (list, tuple)):
        items = catalog
    else:
        raise ValueError("category_catalog phải là danh sách hoặc object.")

    result: Dict[str, Dict[str, Any]] = CategoryCatalog()
    for position, raw in enumerate(items):
        if not isinstance(raw, Mapping):
            continue
        item = dict(raw)
        category_id = item.get("id", item.get("category_id", item.get("title")))
        if category_id is not None and str(category_id).strip():
            item["_stable_id"] = str(category_id).strip()
            result[item["_stable_id"]] = item
        index = item.get("index", item.get("type_index", item.get("typeIndex", position)))
        try:
            result[f"index:{int(index)}"] = item
        except (TypeError, ValueError):
            pass
    return result


def resolve_category_metadata(transaction: Any, category_catalog: Any = None) -> Dict[str, Any]:
    """Resolve stable category and hierarchy metadata without guessing indices."""
    catalog = build_catalog(category_catalog)
    raw_type = _get(transaction, "type", "type_id", "typeId")
    explicit_id = _get(transaction, "category_id", "categoryId", "category_key", "categoryKey")
    raw_name = _get(transaction, "type_name", "typeName", "category_name", "categoryName",
                    "category_title", "categoryTitle", "category", default="")
    name_key = normalize_key(raw_name)

    item = None
    if explicit_id is not None:
        item = catalog.get(str(explicit_id))
    if item is None and raw_type is not None:
        try:
            item = catalog.get(f"index:{int(raw_type)}")
        except (TypeError, ValueError):
            item = catalog.get(str(raw_type))
    if item is None and name_key:
        item = catalog.get(name_key)
        if item is None:
            item = next((candidate for candidate in catalog.values()
                         if normalize_key(candidate.get("title", candidate.get("name", ""))) == name_key), None)

    raw_id = explicit_id
    if raw_id is None and item is not None:
        raw_id = item.get("_stable_id", item.get("id", item.get("category_id", item.get("title"))))
    if raw_id is None:
        # A key-like category name is stable enough for legacy records; a numeric
        # list index by itself is intentionally left unresolved.
        raw_id = name_key if name_key and not name_key.isdigit() else None
    category_id = str(raw_id).strip() if raw_id is not None else ""
    category_id = normalize_key(category_id) if category_id else ""

    parent_id = _get(transaction, "parent_category_id", "parentCategoryId", "parent_id", "parentId")
    if parent_id is None and item is not None:
        parent_id = item.get("parent", item.get("parent_id", item.get("parentId")))
    parent_id = normalize_key(parent_id) if parent_id else CHILD_PARENT.get(category_id, "")

    is_parent = _get(transaction, "is_parent_category", "isParentCategory", "isParent")
    if is_parent is None and item is not None:
        is_parent = item.get("isParent", item.get("is_parent", False))
    is_parent = is_parent is True or str(is_parent).lower() == "true"

    group_id = _get(transaction, "category_group_id", "categoryGroupId", "group_id", "groupId")
    if group_id is None and item is not None:
        group_id = item.get("categoryGroupId", item.get("category_group_id", item.get("groupId")))
    if group_id is None:
        group_id = category_id if is_parent and category_id in PARENT_CATEGORIES else parent_id
    group_id = normalize_key(group_id) if group_id else ""
    if category_id in PARENT_CATEGORIES and is_parent:
        group_id = category_id
    if not group_id:
        group_id = CHILD_PARENT.get(category_id, "")

    parent_item = catalog.get(group_id) if group_id else None
    group_info = PARENT_CATEGORIES.get(group_id, {})
    declared_group_name = _get(transaction, "category_group_name", "categoryGroupName", "group_name", "groupName")
    if declared_group_name is None and parent_item is not None:
        declared_group_name = parent_item.get("name", parent_item.get("title"))
    if declared_group_name and normalize_key(declared_group_name) != group_id:
        group_name = str(declared_group_name)
    else:
        group_name = str(group_info.get("label") or declared_group_name or group_id or "Chưa phân loại")

    title = _get(transaction, "category_name", "categoryName", "type_name", "typeName",
                  "category_title", "categoryTitle", "category")
    if (title is None or str(title).strip().isdigit()) and item is not None:
        title = item.get("name", item.get("title"))
    if not title:
        title = LABELS.get(category_id, category_id or "Chưa phân loại")
    title = str(title)

    role = _get(transaction, "financial_role", "financialRole", "category_role", "categoryRole")
    if role is None and item is not None:
        role = item.get("financialRole", item.get("financial_role",
                        item.get("categoryRole", item.get("category_role"))))
    if role is None:
        role = ROLE_BY_CATEGORY.get(category_id)
    if role is None:
        role = group_info.get("class", "unclassified")
    role = normalize_key(role)
    declared_class = _get(transaction, "category_class", "categoryClass", "expense_class", "expenseClass")
    if declared_class is None and item is not None:
        declared_class = item.get("categoryClass", item.get("category_class", item.get("financialClass")))
    classification = normalize_key(declared_class) if declared_class else ROLE_CLASS.get(role, "unclassified")
    if classification == "unclassified" and group_info:
        classification = group_info["class"]

    level = _get(transaction, "category_level", "categoryLevel", "level")
    if level is None and item is not None:
        level = item.get("level")
    try:
        level = int(level) if level is not None else (1 if is_parent else 2 if parent_id else None)
    except (TypeError, ValueError):
        level = None

    explicit_path = _get(transaction, "category_path", "categoryPath")
    if isinstance(explicit_path, (list, tuple)):
        path_ids = [normalize_key(x) for x in explicit_path if str(x).strip()]
    elif item is not None:
        path_ids = [category_id] if category_id else []
        current = item
        visited = set(path_ids)
        while current is not None:
            ancestor = current.get("parent", current.get("parent_id", current.get("parentId")))
            ancestor = normalize_key(ancestor) if ancestor else ""
            if not ancestor or ancestor in visited:
                break
            path_ids.append(ancestor)
            visited.add(ancestor)
            current = catalog.get(ancestor)
        path_ids.reverse()
    else:
        path_ids = [x for x in (parent_id, group_id, category_id) if x]
        path_ids = list(dict.fromkeys(path_ids))
    category_label = LABELS.get(category_id, title)
    group_label = group_name
    return {
        "category_id": category_id,
        "category_name": title,
        "parent_category_id": parent_id or "",
        "category_group_id": group_id or "unclassified",
        "category_group_name": group_label,
        "category_path_ids": path_ids,
        "category_path": [group_label, category_label] if group_id and category_id != group_id else [category_label],
        "category_level": level,
        "is_parent_category": bool(is_parent),
        "financial_role": role,
        "category_class": classification,
        "income_cadence": "monthly" if role == "fixed_monthly_income" else None,
        "is_fixed_income": role == "fixed_monthly_income",
        "expected_income_events_per_month": 1 if role == "fixed_monthly_income" else None,
        "is_essential": classification in ("living_expense", "fixed_expense", "consumption", "fixed_cost"),
        "is_consumption_expense": classification in ("living_expense", "fixed_expense", "unexpected_expense", "consumption", "fixed_cost", "education", "insurance"),
    }


def category_scope_ids(value: Any, category_catalog: Any = None) -> Set[str]:
    """Return selected category and descendants for parent-budget matching."""
    resolved = resolve_category_metadata(value, category_catalog)
    selected_id = resolved["category_id"]
    if not selected_id:
        return set()
    catalog = build_catalog(category_catalog)
    parent_by_id = {
        str(item.get("_stable_id")): normalize_key(item.get("parent", item.get("parent_id", item.get("parentId", ""))))
        for item in catalog.values() if item.get("_stable_id")
    }
    scope = {selected_id}
    if selected_id == "expense":
        scope.update(parent for parent in PARENT_CATEGORIES if parent != "income")
        scope.update(child for child, parent in CHILD_PARENT.items() if parent != "income")
    elif selected_id in PARENT_CATEGORIES:
        scope.update(child for child, parent in CHILD_PARENT.items() if parent == selected_id)
    changed = True
    while changed:
        changed = False
        for category_id, parent_id in parent_by_id.items():
            if parent_id in scope and category_id not in scope:
                scope.add(category_id)
                changed = True
    return scope


def summarize_category_hierarchy(transactions: Iterable[Any]) -> Dict[str, Any]:
    """Summarize observed cashflow by parent group and child category."""
    groups: Dict[str, Dict[str, Any]] = {}
    role_totals: Dict[str, Dict[str, float]] = {}
    unresolved = 0
    total_outflow = 0.0
    for tx in transactions or []:
        money = float(_get(tx, "money", default=0) or 0)
        if money == 0:
            continue
        group_id = str(_get(tx, "category_group_id", default="unclassified") or "unclassified")
        group_name = str(_get(tx, "category_group_name", default="Chưa phân loại") or "Chưa phân loại")
        category_id = str(_get(tx, "category_id", default="") or "")
        category_name = str(_get(tx, "category_name", "type_name", default="Chưa phân loại") or "Chưa phân loại")
        role = str(_get(tx, "financial_role", default="unclassified") or "unclassified")
        group = groups.setdefault(group_id, {"categoryGroupId": group_id, "categoryGroupName": group_name,
            "transactionCount": 0, "cashOutflow": 0.0, "cashInflow": 0.0, "categories": {}})
        group["transactionCount"] += 1
        if money < 0:
            group["cashOutflow"] += abs(money)
            total_outflow += abs(money)
        else:
            group["cashInflow"] += money
        child = group["categories"].setdefault(category_id or category_name,
            {"categoryId": category_id or None, "categoryName": category_name,
             "financialRole": role,
             "incomeCadence": "monthly" if role == "fixed_monthly_income" else None,
             "isFixedIncome": role == "fixed_monthly_income",
             "expectedEventsPerMonth": 1 if role == "fixed_monthly_income" else None,
             "transactionCount": 0, "cashOutflow": 0.0, "cashInflow": 0.0})
        child["transactionCount"] += 1
        child["cashOutflow"] += abs(money) if money < 0 else 0.0
        child["cashInflow"] += money if money > 0 else 0.0
        role_row = role_totals.setdefault(role, {
            "transactionCount": 0, "cashOutflow": 0.0, "cashInflow": 0.0,
            "incomeCadence": "monthly" if role == "fixed_monthly_income" else None,
            "isFixedIncome": role == "fixed_monthly_income",
            "expectedEventsPerMonth": 1 if role == "fixed_monthly_income" else None,
        })
        role_row["transactionCount"] += 1
        role_row["cashOutflow"] += abs(money) if money < 0 else 0.0
        role_row["cashInflow"] += money if money > 0 else 0.0
        if group_id == "unclassified":
            unresolved += 1

    ordered_groups = []
    for group in groups.values():
        group["cashOutflow"] = round(group["cashOutflow"], 2)
        group["cashInflow"] = round(group["cashInflow"], 2)
        group["outflowSharePercent"] = round(group["cashOutflow"] / total_outflow * 100, 2) if total_outflow else 0.0
        group["categories"] = sorted(group["categories"].values(), key=lambda row: row["cashOutflow"], reverse=True)
        for child in group["categories"]:
            child["cashOutflow"] = round(child["cashOutflow"], 2)
            child["cashInflow"] = round(child["cashInflow"], 2)
        ordered_groups.append(group)
    ordered_groups.sort(key=lambda row: row["cashOutflow"], reverse=True)
    return {
        "schemaVersion": "category_hierarchy_v1",
        "transactionCount": sum(group["transactionCount"] for group in ordered_groups),
        "cashOutflow": round(total_outflow, 2),
        "groups": ordered_groups,
        "financialRoles": {key: {**value,
            "cashOutflow": round(value["cashOutflow"], 2),
            "cashInflow": round(value["cashInflow"], 2)} for key, value in role_totals.items()},
        "unclassifiedTransactionCount": unresolved,
        "chatboxReadyFields": ["category_id", "parent_category_id", "category_group_id",
            "category_path", "financial_role", "merchant", "note", "date_time",
            "money", "is_expense", "is_income", "user_confirmed", "source",
            "chat_intent", "classification_confidence", "payment_method", "recurrence_id"],
    }
