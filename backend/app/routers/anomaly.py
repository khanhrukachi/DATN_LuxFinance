from fastapi import APIRouter, HTTPException
from datetime import datetime

from app.schemas.spending import AnomalyRequest, SpendingItem
from app.services.isolation_forest_service import isolation_forest_service

router = APIRouter(prefix="/detect", tags=["Anomaly Detection"])


# =====================================================
# =================== NORMAL API ======================
# =====================================================
@router.post("/anomaly")
async def detect_anomaly(request: AnomalyRequest):
    try:
        # ✅ CHỈ LẤY CHI TIÊU
        expense_transactions = [
            t for t in request.transactions if t.money < 0
        ]

        if not expense_transactions:
            return {
                "success": True,
                "anomalies": [],
                "message": "No expense transactions to analyze"
            }

        result = isolation_forest_service.detect_anomalies(
            user_id=request.user_id,
            transactions=expense_transactions,
            sensitivity=request.sensitivity
        )

        return result.model_dump(by_alias=True)

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Anomaly detection error: {str(e)}"
        )


# =====================================================
# =================== QUICK API =======================
# =====================================================
@router.post("/anomaly/quick")
async def quick_detect(user_id: str, transactions: list, sensitivity: float = 0.1):
    try:
        spending_items: list[SpendingItem] = []

        for t in transactions:
            try:
                # -------- Parse datetime --------
                dt = t.get("dateTime") or t.get("date_time")
                if isinstance(dt, str):
                    for fmt in (
                        "%Y-%m-%dT%H:%M:%S",
                        "%Y-%m-%d %H:%M:%S",
                        "%Y-%m-%d"
                    ):
                        try:
                            dt = datetime.strptime(dt, fmt)
                            break
                        except ValueError:
                            continue

                money = int(t.get("money", 0))

                # ❌ BỎ QUA THU NHẬP
                if money >= 0:
                    continue

                item = SpendingItem(
                    id=t.get("id", ""),
                    money=abs(money),   # ⚠️ MODEL HỌC ĐỘ LỚN CHI TIÊU
                    type=0,
                    typeName="Expense",
                    note=t.get("note"),
                    dateTime=dt,
                    image=t.get("image"),
                    location=t.get("location"),
                )

                spending_items.append(item)

            except Exception:
                continue

        if not spending_items:
            return {
                "success": True,
                "anomalies": [],
                "message": "No expense transactions to analyze"
            }

        result = isolation_forest_service.detect_anomalies(
            user_id=user_id,
            transactions=spending_items,
            sensitivity=sensitivity
        )

        return result

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Quick anomaly detection error: {str(e)}"
        )


# =====================================================
# ================= SEVERITY LEVELS ===================
# =====================================================
@router.get("/severity-levels")
async def get_severity_levels():
    return {
        "levels": [
            {"level": "high", "name": "Cao", "color": "#FF4444"},
            {"level": "medium", "name": "Trung bình", "color": "#FFAA00"},
            {"level": "low", "name": "Thấp", "color": "#44AA44"},
        ]
    }


# =====================================================
# =============== CHECK SINGLE TRAN ===================
# =====================================================
@router.post("/check-single")
async def check_single_transaction(user_id: str, transaction: dict, history: list):
    try:
        def parse_expense(t):
            money = int(t.get("money", 0))
            if money >= 0:
                return None

            dt = t.get("dateTime") or t.get("date_time")
            if isinstance(dt, str):
                for fmt in (
                    "%Y-%m-%dT%H:%M:%S",
                    "%Y-%m-%d %H:%M:%S",
                    "%Y-%m-%d"
                ):
                    try:
                        dt = datetime.strptime(dt, fmt)
                        break
                    except ValueError:
                        continue

            return SpendingItem(
                id=t.get("id", "check"),
                money=abs(money),
                type=0,
                typeName="Expense",
                note=t.get("note"),
                dateTime=dt,
                image=t.get("image"),
                location=t.get("location"),
            )

        history_items = list(
            filter(None, (parse_expense(t) for t in history))
        )

        target_item = parse_expense(transaction)

        if not target_item:
            return {
                "isAnomaly": False,
                "message": "Thu nhập không được kiểm tra bất thường"
            }

        history_items.append(target_item)

        result = isolation_forest_service.detect_anomalies(
            user_id=user_id,
            transactions=history_items,
            sensitivity=0.1
        )

        is_anomaly = any(
            a.transaction_id == target_item.id
            for a in result.anomalies
        )

        anomaly_info = next(
            (a for a in result.anomalies if a.transaction_id == target_item.id),
            None
        )

        return {
            "isAnomaly": is_anomaly,
            "transaction": transaction,
            "anomalyDetails": anomaly_info.dict() if anomaly_info else None,
            "message": "Giao dịch chi tiêu bất thường!"
            if is_anomaly else
            "Giao dịch bình thường"
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Check error: {str(e)}"
        )
