from fastapi import APIRouter, HTTPException
from typing import Optional, List
from datetime import datetime

from app.schemas.spending import ClusteringRequest, SpendingItem
from app.services.kmeans_service import kmeans_service

router = APIRouter(prefix="/cluster", tags=["Clustering"])


# =====================================================
# =============== CLUSTER BEHAVIOR ====================
# =====================================================
@router.post("/behavior")
async def cluster_behavior(request: ClusteringRequest):
    try:
        result = kmeans_service.cluster_spending(
            user_id=request.user_id,
            transactions=request.transactions,
            n_clusters=request.n_clusters
        )
        return result.model_dump(by_alias=True)

    except Exception as e:
        import traceback
        error_detail = f"Clustering error: {str(e)}\n{traceback.format_exc()}"
        print(error_detail)
        raise HTTPException(status_code=500, detail=error_detail)


# =====================================================
# =============== QUICK CLUSTER =======================
# =====================================================
@router.post("/behavior/quick")
async def quick_cluster(
    user_id: str,
    transactions: List[dict],
    n_clusters: Optional[int] = None
):
    try:
        spending_items: List[SpendingItem] = []

        for t in transactions:
            try:
                # ---------- Parse datetime ----------
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

                if not isinstance(dt, datetime):
                    continue

                spending_items.append(
                    SpendingItem(
                        id=str(t.get("id", "")),
                        money=int(t.get("money", 0)),
                        type=int(t.get("type", 0)),
                        typeName=t.get("typeName") or t.get("type_name", "Other"),
                        note=t.get("note"),
                        dateTime=dt,
                        image=t.get("image"),
                        location=t.get("location")
                    )
                )

            except Exception:
                continue

        if not spending_items:
            return {
                "success": False,
                "message": "No valid transactions provided"
            }

        return kmeans_service.cluster_spending(
            user_id=user_id,
            transactions=spending_items,
            n_clusters=n_clusters
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Quick clustering error: {str(e)}"
        )


@router.get("/profiles")
async def get_cluster_profiles():
    return {
        "profiles": [

            # ===============================
            # CHI TIÊU THƯỜNG XUYÊN – NHỎ
            # ===============================
            {
                "key": "high_freq_low_amount",
                "name": "Chi tiêu thường xuyên",
                "description": "Nhiều khoản chi nhỏ, lặp lại hằng ngày",
                "categories": [
                    "eating",
                    "move",
                    "water_money",
                    "electricity_bill",
                    "gas_money",
                    "internet_money",
                    "telephone_fee",
                    "parking"
                ],
                "moneyPattern": "smaller",
                "timePatterns": {
                    "dayOfWeek": ["monday", "tuesday", "wednesday", "thursday", "friday"],
                    "month": "all"
                },
                "riskLevel": "Thấp",
                "iconSuggestion": "eat",
                "suggestions": [
                    "Theo dõi tổng chi vì các khoản nhỏ dễ cộng dồn",
                    "Đặt ngân sách ngày cho sinh hoạt"
                ]
            },

            # ===============================
            # CHI TIÊU LỚN – KHÔNG THƯỜNG XUYÊN
            # ===============================
            {
                "key": "low_freq_high_amount",
                "name": "Chi tiêu lớn định kỳ",
                "description": "Ít giao dịch nhưng giá trị mỗi lần cao",
                "categories": [
                    "rent_house",
                    "education",
                    "repair_and_decorate_the_house",
                    "vehicle_maintenance",
                    "physical_examination",
                    "insurance"
                ],
                "moneyPattern": "bigger",
                "timePatterns": {
                    "dayOfWeek": "all",
                    "month": "exactly"
                },
                "riskLevel": "Cao",
                "iconSuggestion": "house",
                "suggestions": [
                    "Nên lập quỹ dự phòng cho chi tiêu lớn",
                    "Phân bổ chi phí theo tháng để tránh áp lực tài chính"
                ]
            },

            # ===============================
            # CHI TIÊU GIẢI TRÍ
            # ===============================
            {
                "key": "entertainment_spending",
                "name": "Chi tiêu giải trí",
                "description": "Chi tiêu cho vui chơi, mua sắm, thư giãn",
                "categories": [
                    "sport",
                    "fun_play",
                    "beautify",
                    "online_services",
                    "gifts_donations"
                ],
                "moneyPattern": "about2",
                "timePatterns": {
                    "dayOfWeek": ["saturday", "sunday"],
                    "month": "all"
                },
                "riskLevel": "Trung bình",
                "iconSuggestion": "game-pad",
                "suggestions": [
                    "Nên giới hạn ngân sách giải trí hàng tháng",
                    "Theo dõi chi tiêu cuối tuần"
                ]
            },

            # ===============================
            # CHI TIÊU CUỐI TUẦN
            # ===============================
            {
                "key": "weekend_spending",
                "name": "Chi tiêu cuối tuần",
                "description": "Phần lớn giao dịch rơi vào thứ 7 và chủ nhật",
                "categories": [
                    "eating",
                    "fun_play",
                    "travel",
                    "family_service"
                ],
                "moneyPattern": "about2",
                "timePatterns": {
                    "dayOfWeek": ["saturday", "sunday"],
                    "month": "all"
                },
                "riskLevel": "Trung bình",
                "iconSuggestion": "family",
                "suggestions": [
                    "Lập kế hoạch chi tiêu cuối tuần",
                    "Tránh chi tiêu bốc đồng"
                ]
            },

            # ===============================
            # ĐẦU TƯ – VAY – NỢ
            # ===============================
            {
                "key": "investment_debt",
                "name": "Đầu tư & vay nợ",
                "description": "Giao dịch liên quan đến đầu tư, vay và trả nợ",
                "categories": [
                    "invest",
                    "borrow",
                    "loan",
                    "pay",
                    "pay_interest",
                    "earn_profit"
                ],
                "moneyPattern": "bigger",
                "timePatterns": {
                    "dayOfWeek": "all",
                    "month": "exactly"
                },
                "riskLevel": "Cao",
                "iconSuggestion": "stats",
                "suggestions": [
                    "Theo dõi dòng tiền đầu tư",
                    "Tránh vay vượt khả năng chi trả"
                ]
            },

            # ===============================
            # CHI TIÊU HỖN HỢP
            # ===============================
            {
                "key": "mixed_spending",
                "name": "Chi tiêu hỗn hợp",
                "description": "Không có nhóm chi tiêu nào chiếm ưu thế rõ ràng",
                "categories": ["other_costs", "personal_belongings", "housewares"],
                "moneyPattern": "all",
                "timePatterns": {
                    "dayOfWeek": "all",
                    "month": "all"
                },
                "riskLevel": "Thấp",
                "iconSuggestion": "box",
                "suggestions": [
                    "Tiếp tục theo dõi để nhận diện xu hướng rõ hơn"
                ]
            }
        ]
    }

