"""Generate concise supported Q&A examples; never generate user transactions."""
import json
from pathlib import Path
from .category_taxonomy import CHILD_PARENT, PARENT_CATEGORIES
BASE = Path(__file__).parent

def generate():
    rows = []
    categories = sorted(set(CHILD_PARENT) | set(PARENT_CATEGORIES))
    # Paired examples document language parity for every supported intent. They
    # are parser/behavior examples, not synthetic user records or model labels.
    for cid in categories:
        parent = CHILD_PARENT.get(cid)
        templates = [('category_cashflow', 'Tháng này tổng dòng tiền của {c} là bao nhiêu?')]
        if cid.startswith('expense_') or (parent or '').startswith('expense_'):
            templates += [('category_spending', 'Tháng này tôi đã chi bao nhiêu cho {c}?'),
                          ('period_comparison', 'Chi {c} tháng này so với tháng trước thế nào?'),
                          ('budget_status', 'Ngân sách {c} tháng này còn bao nhiêu?')]
        templates += [
            ('category_average', '{c} trung bình tháng này bao nhiêu?'),
            ('transaction_details', 'Liệt kê giao dịch {c} tháng này'),
            ('category_definition', '{c} thuộc danh mục nào?'),
            ('category_summary', '{c} tháng 8/2026 bao nhiêu?'),
            ('category_share', '{c} chiếm tỷ trọng bao nhiêu tháng này?'),
            ('category_summary', '{c} tháng này bao nhiêu lần?'),
            ('period_comparison', 'So sánh {c} tháng này với tháng trước'),
            ('period_comparison', 'So sánh {c} tháng 8/2026 với tháng 9/2026'),
            ('period_comparison', 'So sánh {c} tuần này với tuần trước'),
        ]
        if cid == 'income' or parent == 'income':
            templates.append(('income_period_comparison', 'So sánh thu nhập {c} tháng này với tháng trước'))
        for intent, template in templates:
            common = dict(intent=intent, category_id=cid, parent_category_id=parent)
            rows.append(dict(question=template.format(c=cid), language='vi', **common))
            if intent == 'category_cashflow':
                english = 'What was the total cash flow for {c} this month?'
            elif intent == 'category_spending':
                english = 'How much did I spend on {c} this month?'
            elif intent == 'period_comparison':
                if 'tháng 8/2026' in template:
                    english = 'Compare {c} in August 2026 with September 2026.'
                elif 'tuần này' in template:
                    english = 'Compare {c} this week with last week.'
                elif 'tháng này so với tháng trước thế nào' in template:
                    english = 'How does my {c} spending this month compare with last month?'
                else:
                    english = 'Compare {c} this month with last month.'
            elif intent == 'budget_status':
                english = 'How much budget is left for {c} this month?'
            elif intent == 'category_average':
                english = 'What was my average spending for {c} this month?'
            elif intent == 'transaction_details':
                english = 'List my {c} transactions this month.'
            elif intent == 'category_definition':
                english = 'Which category does {c} belong to?'
            elif intent == 'category_summary' and 'bao nhiêu lần' in template:
                english = 'How many {c} transactions did I record this month?'
            elif intent == 'category_summary':
                english = 'What amount was recorded for {c} in August 2026?'
            elif intent == 'category_share':
                english = 'What percentage of my spending was {c} this month?'
            else:
                english = 'Compare my {c} income this month with last month.'
            rows.append(dict(question=english.format(c=cid), language='en', **common))
    english_examples = [
        ('What is my total income and spending this month?', 'period_summary'),
        ('Compare my income this month with last month.', 'income_period_comparison'),
        ('Compare spending by parent category this month with last month.', 'period_comparison'),
        ('Compare each category this month with the same number of days last month.', 'period_comparison'),
        ('Which category did I spend the most on this month?', 'top_spending_categories'),
        ('Forecast my spending for the next 7 days.', 'spending_forecast'),
        ('Were there any unusual transactions this month?', 'anomaly_analysis'),
        ('Analyze my spending habits this month.', 'behavior_analysis'),
        ('Give me a financial overview for this month.', 'financial_overview'),
        ('Can I afford to pay rent at the end of this month?', 'affordability_check'),
        ('When am I likely to receive my salary next month?', 'next_salary_date'),
        ('Show my budget status this month.', 'budget_status'),
        ('Give me recommendations based on my spending.', 'financial_recommendations'),
    ]
    rows.extend(dict(question=q, intent=i, language='vi') for q, i in [
        ('Tháng này tổng thu chi là bao nhiêu?', 'period_summary'),
        ('So sánh thu nhập tháng này và tháng trước', 'income_period_comparison'),
        ('So sánh chi tiêu từng danh mục cha tháng này và tháng trước', 'period_comparison'),
        ('So sánh chi tiêu từng danh mục tháng này với tháng trước cùng số ngày', 'period_comparison'),
        ('Danh mục nào chi nhiều nhất tháng này?', 'top_spending_categories'),
        ('Dự báo chi tiêu 7 ngày tới', 'spending_forecast'),
        ('Tháng này có giao dịch bất thường không?', 'anomaly_analysis'),
        ('Phân tích thói quen chi tiêu tháng này', 'behavior_analysis'),
        ('Đánh giá tài chính tháng này', 'financial_overview'),
        ('Cuối tháng tôi có đủ tiền trả tiền nhà không?', 'affordability_check'),
        ('Tháng sau tôi dự kiến nhận lương ngày nào?', 'next_salary_date'),
        ('Cho tôi xem tình trạng ngân sách tháng này', 'budget_status'),
        ('Gợi ý dựa trên chi tiêu của tôi', 'financial_recommendations'),
    ])
    rows.extend(dict(question=q, intent=i, language='en') for q, i in english_examples)
    (BASE/'financial_qa_training_data.json').write_text(json.dumps(dict(
        schemaVersion='financial_chat_examples_v2',
        datasetType='bilingual_parser_test_examples_not_trained_model',
        supportedLanguages=['vi', 'en'], questionCount=len(rows),
        languageCounts={lang: sum(1 for row in rows if row['language'] == lang) for lang in ('vi', 'en')},
        examples=rows), ensure_ascii=False, indent=2), encoding='utf-8')
    (BASE/'financial_qa_category_aliases.json').write_text(json.dumps(dict(categories=[dict(category_id=c, parent_category_id=CHILD_PARENT.get(c)) for c in categories]), ensure_ascii=False, indent=2), encoding='utf-8')
if __name__ == '__main__': generate()
