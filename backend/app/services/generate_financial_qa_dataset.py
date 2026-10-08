"""Generate concise supported Q&A examples; never generate user transactions."""
import json
from pathlib import Path
from .category_taxonomy import CHILD_PARENT, PARENT_CATEGORIES
BASE = Path(__file__).parent

def generate():
    rows = []
    categories = sorted(set(CHILD_PARENT) | set(PARENT_CATEGORIES))
    for cid in categories:
        parent = CHILD_PARENT.get(cid)
        templates = [('category_cashflow', 'Tháng này tổng dòng tiền của {c} là bao nhiêu?')]
        if cid.startswith('expense_') or (parent or '').startswith('expense_'):
            templates += [('category_spending', 'Tháng này tôi đã chi bao nhiêu cho {c}?'),
                          ('period_comparison', 'Chi {c} tháng này so với tháng trước thế nào?'),
                          ('budget_status', 'Ngân sách {c} tháng này còn bao nhiêu?')]
        templates.append(('period_comparison', 'So sánh {c} tháng này với tháng trước'))
        if cid == 'income' or parent == 'income':
            templates.append(('income_period_comparison', 'So sánh thu nhập {c} tháng này với tháng trước'))
        for intent, template in templates:
            rows.append(dict(question=template.format(c=cid), intent=intent, category_id=cid, parent_category_id=parent))
    rows += [dict(question=q, intent=i) for q,i in [
        ('Tháng này tổng thu chi là bao nhiêu?', 'period_summary'),
        ('So sánh thu nhập tháng này và tháng trước', 'income_period_comparison'),
        ('So sánh chi tiêu từng danh mục cha tháng này và tháng trước', 'period_comparison'),
        ('So sánh chi tiêu từng danh mục tháng này với tháng trước cùng số ngày', 'period_comparison'),
        ('Danh mục nào chi nhiều nhất tháng này?', 'top_spending_categories'),
        ('Dự báo chi tiêu 7 ngày tới', 'spending_forecast'),
        ('Tháng này có giao dịch bất thường không?', 'anomaly_analysis'),
        ('Phân tích thói quen chi tiêu tháng này', 'behavior_analysis')]]
    (BASE/'financial_qa_training_data.json').write_text(json.dumps(dict(schemaVersion='financial_chat_examples_v1', datasetType='parser_test_examples_not_trained_model', questionCount=len(rows), examples=rows), ensure_ascii=False, indent=2), encoding='utf-8')
    (BASE/'financial_qa_category_aliases.json').write_text(json.dumps(dict(categories=[dict(category_id=c, parent_category_id=CHILD_PARENT.get(c)) for c in categories]), ensure_ascii=False, indent=2), encoding='utf-8')
if __name__ == '__main__': generate()
