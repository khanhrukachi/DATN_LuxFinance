"""Evidence-based category queries. No generated balances or fabricated records."""
from __future__ import annotations
import calendar
import re
from collections import defaultdict
from datetime import date, timedelta
from .category_taxonomy import LABELS, PARENT_CATEGORIES, build_catalog


def money(n):
    return f'{n:,.0f}'.replace(',', '.') + ' đ'


class ChatQueryEngine:
    def __init__(self, finance):
        self.finance = finance

    def label(self, cid, catalog):
        item = build_catalog(catalog).get(cid, {})
        return item.get('display_name') or LABELS.get(cid) or PARENT_CATEGORIES.get(cid, {}).get('label') or cid

    def period(self, q, today):
        if re.search(r'\b(tat ca|toan bo|all time|ever)\b', q):
            return date(1900, 1, 1), today, 'all'
        month_validation = re.search(r'\b(?:thang|month)\s+(\d+)\b', q)
        if month_validation and not 1 <= int(month_validation.group(1)) <= 12:
            raise ValueError('Tháng phải từ 1 đến 12.')
        written_day = re.search(r'\bngay\s+(\d{1,2})\s+thang\s+(\d{1,2})(?:\s+nam\s+(\d{4}))?', q)
        if written_day and 'tu ' not in q:
            dd,mm,yy = written_day.groups()
            day = date(int(yy or today.year),int(mm),int(dd))
            return day, day, 'day'
        quarter = re.search(r'\bquy\s*([1-4])(?:\s+(?:nam\s*)?(\d{4}))?\b', q)
        if quarter or 'quy nay' in q or 'quy truoc' in q:
            number = int(quarter.group(1)) if quarter else (today.month-1)//3+1
            year = int(quarter.group(2) or today.year) if quarter else today.year
            if 'quy truoc' in q and not quarter:
                number -= 1
                if number == 0:number=4;year-=1
            first_month=(number-1)*3+1
            last_month=first_month+2
            first=date(year,first_month,1);last=date(year,last_month,calendar.monthrange(year,last_month)[1])
            return first,min(last,today) if first<=today<=last else last,'quarter'
        # Preserve slash-separated years before the legacy selector normalizes them.
        m = re.search(r'\b(?:thang|month)\s+(\d{1,2})\s*[/\-]\s*(\d{4})\b', q)
        if m:
            mm, yy = map(int, m.groups())
            end = date(yy, mm, calendar.monthrange(yy, mm)[1])
            return date(yy, mm, 1), min(end, today) if (yy, mm) == (today.year, today.month) else end, 'month'
        # A single explicit date means that day, not the current month.
        if not re.search(r'\b(tu|from|so sanh|compare|so voi)\b', q):
            m = re.search(r'(?<!\d)(\d{1,2})/(\d{1,2})(?:/(\d{4}))?(?!\d)', q)
            if m:
                dd, mm, yy = m.groups()
                d = date(int(yy or today.year), int(mm), int(dd))
                return d, d, 'day'
        return self.finance._select_period_from_question(q, today)

    def select(self, normalized, q, catalog, targets, start, end):
        items = self.finance._within(normalized, start, end)
        if targets:
            items = [t for t in items if self.finance._category_query_match(q, t, catalog, targets)]
        # Category scope wins over generic verbs: "thu chi lương" stays salary.
        direction = 'both'
        if re.search(r'\b(thu chi|dong tien|cashflow|tong quan|phan tich|bao cao)\b', q):
            direction = 'both'
        elif re.search(r'\b(thu nhap|tong thu|tien vao|income|salary|nhan)\b', q):
            direction = 'income'
        elif re.search(r'\b(chi tieu|tong chi|da chi|chi ra|tieu|expense|spending)\b', q):
            direction = 'expense'
        elif targets:
            incoming = {'income', 'salary', 'borrow', 'debt_collection', 'earn_profit', 'other_income'}
            direction = 'income' if all(t in incoming for t in targets) else 'expense'
        else:
            direction = 'expense'
        if direction != 'both':
            items = [t for t in items if t.money > 0] if direction == 'income' else [t for t in items if t.money < 0]
        return items, direction

    def answer(self, q, txs, today, catalog, context):
        targets = self.finance._query_category_targets(q, catalog)
        # Semantic requests for category definitions do not require transactions.
        if re.search(r'\b(la gi|gom|bao gom|danh sach danh muc|co nhung|thuoc nhom|thuoc danh muc|category list)\b', q):
            return self.taxonomy(targets, catalog)
        if re.search(r'\b(ngan sach|han muc|vuot muc|budget)\b', q):
            start, end, kind = self.period(q, today)
            if kind not in ('month', 'day'):
                return self.reply('budget_period_clarification', 'Ngân sách được đặt theo tháng. Bạn muốn xem tháng nào?', needs=['analysis_month'])
            normalized, _ = self.finance._normalized(txs, today, catalog)
            effective = min(today, date(start.year, start.month, calendar.monthrange(start.year, start.month)[1]))
            if start > today:
                return self.reply('budget_period_clarification', 'Có thể xem hạn mức tháng tương lai nhưng chưa có chi thực tế để đánh giá.', needs=['recorded_month'])
            result = self.finance._answer_budget_question(q, normalized, effective, catalog, context)
            if result is not None:
                return result
        # Leave model/affordability/salary-date questions to their dedicated services.
        if re.search(r'\b(du bao|du doan|forecast|predict|bat thuong|anomaly|thoi quen|hanh vi|phan cum|behavior|goi y|tu van|nen tiet kiem|du tien|du tra|afford|co the mua|ngay nhan luong|luong khi nao)\b', q):
            return None
        if re.search(r'\b(phan tich sau|suc khoe tai chinh|financial health)\b', q):
            return None
        normalized, diagnostics = self.finance._normalized(txs, today, catalog)
        comparison = bool(re.search(r'\b(so sanh|so voi|voi nhau|tang|giam|compare|versus)\b', q))
        if comparison:
            return self.compare(q, normalized, today, catalog, targets, diagnostics)
        supported = targets or re.search(r'\b(bao nhieu|tong|thong ke|tong quan|phan tich|bao cao|danh gia|nhieu nhat|cao nhat|lon nhat|it nhat|thap nhat|trung binh|binh quan|ty trong|ti le|ty le|chiem|liet ke|chi tiet|gan nhat|may lan|so lan|bao lan|giao dich|thu|chi|thu nhap|tieu|spending|income|expense)\b', q)
        if not supported:
            return None
        start, end, kind = self.period(q, today)
        if end < start or start > today:
            return self.reply('period_clarification', 'Kỳ này chưa có dữ liệu thực tế hoặc khoảng ngày không hợp lệ.', needs=['recorded_period'])
        items, direction = self.select(normalized, q, catalog, targets, start, end)
        # Explicit note/merchant search; never silently interpret a category as a merchant.
        search = re.search(r'(?:ghi chu|mon|dia diem|tai|o)\s*[\":]?\s*"([^"]+)"', q)
        if search:
            term = search.group(1)
            from .chat_ai_service import folded
            items = [t for t in items if term in folded(t.note + ' ' + t.merchant)]
        inflow = sum(t.money for t in items if t.money > 0)
        outflow = sum(abs(t.money) for t in items if t.money < 0)
        amount = inflow if direction == 'income' else outflow if direction == 'expense' else inflow + outflow
        evidence = dict(amount=round(amount), income=round(inflow), expense=round(outflow), net=round(inflow-outflow),
                        direction=direction, matchedCategories=targets, transactionCount=len(items), diagnostics=diagnostics)
        scope = ', '.join(self.label(t, catalog) for t in targets) or ('thu chi' if direction == 'both' else 'thu vào' if direction == 'income' else 'chi ra')
        header = f'{scope} từ {start:%d/%m/%Y} đến {end:%d/%m/%Y}' if kind != 'all' else f'{scope} trong toàn bộ lịch sử được cung cấp'
        intent = 'category_summary'
        lines = [f'{header}: {len(items)} giao dịch; thu vào {money(inflow)}, chi ra {money(outflow)}, chênh lệch {money(inflow-outflow)}.']
        if re.search(r'\b(trung binh|binh quan|average)\b', q):
            days = (end-start).days+1
            if kind == 'all':
                days = (end-min((t.date_time.date() for t in items), default=end)).days+1
            evidence.update(averageTransaction=round(amount/len(items), 2) if items else 0, averageDay=round(amount/days, 2), calendarDays=days)
            lines.append(f'Bình quân mỗi giao dịch {money(evidence["averageTransaction"])}; mỗi ngày lịch {money(evidence["averageDay"])} ({days} ngày).')
            intent = 'category_average'
        grouped = bool(re.search(r'\b(theo danh muc|tung danh muc|danh muc cha|danh muc con|top|xep hang|ty trong|ti le|ty le|chiem|nhieu nhat|it nhat|cao nhat|thap nhat)\b', q))
        if grouped or targets:
            parent = 'danh muc cha' in q
            groups = defaultdict(lambda: dict(amount=0, transactionCount=0))
            for t in items:
                cid = (t.parent_category_id or t.category_id) if parent else t.category_id
                groups[cid]['amount'] += abs(t.money)
                groups[cid]['transactionCount'] += 1
            low = bool(re.search(r'\b(it nhat|thap nhat)\b', q))
            rows = [dict(categoryId=cid, categoryName=self.label(cid,catalog), amount=round(v['amount']), transactionCount=v['transactionCount'], sharePercent=round(v['amount']/amount*100,2) if amount else 0) for cid,v in groups.items()]
            rows.sort(key=lambda r:r['amount'], reverse=not low)
            evidence.update(categories=rows, grouping='parent' if parent else 'child')
            for row in rows[:10]:
                lines.append(f'• {row["categoryName"]}: {money(row["amount"])} ({row["sharePercent"]}% trong phạm vi đang hỏi), {row["transactionCount"]} giao dịch.')
        if re.search(r'\b(ty trong|ti le|ty le|chiem)\b', q) and targets:
            all_items,_ = self.select(normalized,q,catalog,[],start,end)
            denominator = sum(abs(t.money) for t in all_items)
            share = round(amount/denominator*100,2) if denominator else None
            evidence.update(sharePercent=share, denominator=round(denominator))
            lines.append(f'Tỷ trọng so với tổng {direction} cùng kỳ: {share}%. ' if share is not None else 'Tổng cùng kỳ bằng 0 nên không tính tỷ trọng.')
        if re.search(r'\b(liet ke|chi tiet|gan nhat|giao dich lon nhat|giao dich nho nhat|khoan (?:chi )?lon nhat|khoan (?:chi )?nho nhat)\b', q):
            ordered = sorted(items,key=lambda t:t.date_time,reverse=True)
            if re.search(r'\b(lon nhat|nho nhat)\b',q):
                ordered = sorted(items,key=lambda t:abs(t.money),reverse='nho nhat' not in q)[:1]
            limit_match = re.search(r'\b(\d{1,2})\s+giao dich',q)
            limit = min(20,max(1,int(limit_match.group(1)))) if limit_match else 10
            evidence.update(transactions=[dict(id=t.id,money=round(t.money),dateTime=t.date_time.isoformat(),categoryId=t.category_id,categoryName=self.label(t.category_id,catalog),note=t.note) for t in ordered[:limit]], matchedTransactionCount=len(items))
            intent = 'transaction_details'
            for t in evidence['transactions']:
                lines.append(f'• {t["dateTime"][:16].replace("T"," ")}: {t["categoryName"]}, {money(t["money"])}, {t["note"]}.')
        if not items:
            lines.append('Không có giao dịch được ghi nhận khớp kỳ và danh mục này.')
        return self.reply(intent,'\n'.join(lines),evidence,period=dict(type=kind,startDate=start.isoformat(),endDate=end.isoformat()))

    def taxonomy(self, targets, catalog):
        indexed = build_catalog(catalog)
        unique = {v.get('_stable_id'):v for v in indexed.values() if v.get('_stable_id')}
        if not unique:
            from .category_taxonomy import CHILD_PARENT
            unique = {cid:dict(id=cid,parent=parent) for cid,parent in CHILD_PARENT.items()}
            unique.update({cid:dict(id=cid,isParent=True) for cid in PARENT_CATEGORIES})
        rows=[]
        for cid,item in unique.items():
            if targets and cid not in targets and item.get('parent') not in targets:continue
            rows.append(dict(categoryId=cid,categoryName=self.label(cid,catalog),parentId=item.get('parent') or '',isParent=item.get('isParent') in (True,'true')))
        lines=[f'• {r["categoryName"]} ({r["categoryId"]})' + (f' — thuộc {self.label(r["parentId"],catalog)}' if r['parentId'] else '') for r in rows]
        return self.reply('category_definition','\n'.join(lines) or 'Không tìm thấy danh mục này trong danh mục hiện tại.',dict(categories=rows))

    def compare(self,q,normalized,today,catalog,targets,diagnostics):
        # Compare distinct categories in the same selected period, not against last month.
        periods = re.findall(r'\b(?:thang|month)\s+(\d{1,2})(?:\s*[/\-]\s*(\d{4})|\s+nam\s+(\d{4}))?\b',q)
        start,end,kind=self.period(q,today)
        if len(targets)>=2 and not re.search(r'thang truoc|tuan truoc|nam ngoai|cung ky',q) and len(periods)<2:
            rows=[]
            for target in targets:
                items,direction=self.select(normalized,q,catalog,[target],start,end)
                rows.append(dict(categoryId=target,categoryName=self.label(target,catalog),amount=round(sum(abs(t.money) for t in items)),transactionCount=len(items)))
            return self.reply('category_comparison','\n'.join(f'• {r["categoryName"]}: {money(r["amount"])} ({r["transactionCount"]} giao dịch).' for r in rows),dict(categories=rows,scopeMayOverlap=True),period=dict(startDate=start.isoformat(),endDate=end.isoformat()),warnings=['Danh mục cha có thể bao gồm danh mục con; các dòng so sánh không cộng dồn.'])
        if len(periods)>=2:
            def bounds(values):
                mm=int(values[0]);yy=int(values[1] or values[2] or today.year)
                a=date(yy,mm,1);b=date(yy,mm,calendar.monthrange(yy,mm)[1])
                return a,min(b,today) if yy==today.year and mm==today.month else b
            start,end=bounds(periods[0]);prev_start,prev_end=bounds(periods[1])
        elif kind=='week':
            if 'tuan truoc' in q and 'tuan nay' in q:start=today-timedelta(days=today.weekday());end=today
            prev_end=start-timedelta(days=1);prev_start=prev_end-timedelta(days=6)
        elif kind=='year':
            if 'nam ngoai' in q and 'nam nay' in q:start=date(today.year,1,1);end=today
            prev_start=date(start.year-1,1,1);prev_end=date(start.year-1,12,31)
        elif kind=='quarter':
            prev_end=start-timedelta(days=1)
            first_month=(prev_end.month-1)//3*3+1
            prev_start=date(prev_end.year,first_month,1)
        elif kind=='day':
            if 'hom nay' in q:start=end=today
            prev_start=prev_end=start-timedelta(days=1)
        else:
            if 'thang nay' in q:start=date(today.year,today.month,1);end=today
            prev_end=start-timedelta(days=1);prev_start=prev_end.replace(day=1)
        same_days='cung ky' in q or 'cung so ngay' in q
        # Default to equally elapsed days when comparing an ongoing current period.
        if end==today and not re.search(r'ca thang|ca tuan|ca nam|toan bo ky',q):same_days=True
        if same_days:prev_end=min(prev_end,prev_start+timedelta(days=(end-start).days))
        if start > today or prev_start > today:
            return self.reply('period_clarification','Kỳ so sánh chưa diễn ra. Hãy chọn kỳ có dữ liệu thực tế.',needs=['recorded_period'])
        current,direction=self.select(normalized,q,catalog,targets,start,end)
        previous,_=self.select(normalized,q,catalog,targets,prev_start,prev_end)
        a=sum(abs(t.money) for t in current);b=sum(abs(t.money) for t in previous);delta=a-b
        percent=round(delta/b*100,2) if b else None
        lines=[f'Kỳ {start:%d/%m/%Y}–{end:%d/%m/%Y}: {money(a)}; kỳ {prev_start:%d/%m/%Y}–{prev_end:%d/%m/%Y}: {money(b)}.',f'{"Tăng" if delta>0 else "Giảm" if delta<0 else "Không đổi"} {money(abs(delta))}'+(f' ({abs(percent)}%).' if percent is not None else '; kỳ đối chiếu bằng 0 nên không tính %.')]
        rows={};parent='danh muc cha' in q
        for side,items in [('current',current),('previous',previous)]:
            for t in items:
                cid=(t.parent_category_id or t.category_id) if parent else t.category_id
                row=rows.setdefault(cid,dict(categoryId=cid,categoryName=self.label(cid,catalog),currentAmount=0,previousAmount=0))
                row[side+'Amount']+=abs(t.money)
        for row in rows.values():
            row['change']=row['currentAmount']-row['previousAmount']
            row['changePercent']=round(row['change']/row['previousAmount']*100,2) if row['previousAmount'] else None
        return self.reply('period_comparison','\n'.join(lines),dict(current=dict(amount=round(a),startDate=start.isoformat(),endDate=end.isoformat(),transactionCount=len(current)),previous=dict(amount=round(b),startDate=prev_start.isoformat(),endDate=prev_end.isoformat(),transactionCount=len(previous)),change=round(delta),changePercent=percent,categories=list(rows.values()),direction=direction,diagnostics=diagnostics),warnings=['So sánh cùng số ngày đã diễn ra.' if same_days else 'Hai kỳ có thể có độ dài khác nhau.'])

    @staticmethod
    def reply(intent,answer,evidence=None,period=None,needs=None,warnings=None):
        return dict(success=True,intent=intent,answer=answer,evidence=evidence or {},period=period or {},needsInput=needs or [],warnings=warnings or [])
