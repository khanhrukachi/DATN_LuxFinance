"""Deterministic ledger Q&A: debts never enter spending or ML training inputs."""
from __future__ import annotations
import calendar
import re
import unicodedata
from collections import defaultdict
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

TZ=ZoneInfo('Asia/Ho_Chi_Minh')

def fold(value):
    return re.sub(r'\s+',' ',''.join(c for c in unicodedata.normalize('NFD',str(value).lower().replace('đ','d')) if unicodedata.category(c)!='Mn')).strip()

def intent_fold(value):
    # Avoid conflating muốn/mượn, vậy/vay and nó/nợ in accented questions.
    value=re.sub(r'\bmuốn\b','cần',str(value),flags=re.I)
    value=re.sub(r'\bvậy\b','thế',value,flags=re.I)
    value=re.sub(r'\bnó\b','đối tượng',value,flags=re.I)
    return fold(value)

def money(value):
    return f'{value:,}'.replace(',','.')+' ₫'

def day(value):
    if value is None:return None
    if isinstance(value,datetime):return value.astimezone(TZ).date() if value.tzinfo else value.date()
    if isinstance(value,date):return value
    if isinstance(value,str):
        try:return day(datetime.fromisoformat(value.replace('Z','+00:00')))
        except ValueError:return datetime.strptime(value,'%d/%m/%Y').date()
    raise ValueError('Ngày giao dịch không hợp lệ')

def integer(value):
    if isinstance(value,bool) or not isinstance(value,(int,float)) or value!=int(value):
        raise ValueError('Số tiền phải là số nguyên')
    return int(value)

def window(q,today):
    """Inclusive calendar windows, without clipping future due dates to today."""
    def parsed(dd,mm,yy=None):return date(int(yy or today.year),int(mm),int(dd))
    dates=list(re.finditer(r'(?<!\d)(\d{1,2})/(\d{1,2})(?:/(\d{4}))?(?!\d)',q))
    if len(dates)>=2 and re.search(r'\btu\b',q):
        start,end=[parsed(*m.groups()) for m in dates[:2]]
        if start>end:raise ValueError('Ngày bắt đầu phải trước hoặc bằng ngày kết thúc')
        return start,end
    if dates:
        d=parsed(*dates[0].groups())
        if 'truoc ngay' in q:return date(1900,1,1),d-timedelta(days=1)
        if 'sau ngay' in q:return d+timedelta(days=1),date(2200,12,31)
        if 'tinh den' in q or 'den ngay' in q:return date(1900,1,1),d
        return d,d
    written=re.search(r'\bngay (\d{1,2}) thang (\d{1,2})(?: nam (\d{4}))?',q)
    if written:
        d=parsed(*written.groups());return d,d
    m=re.search(r'\b(\d{1,3}) ngay (toi|qua|gan day)\b',q)
    if m:
        n=int(m[1])
        if not 1<=n<=365:raise ValueError('Số ngày phải từ 1 đến 365')
        return (today,today+timedelta(days=n-1)) if m[2]=='toi' else (today-timedelta(days=n-1),today)
    for key,delta in [('hom nay',0),('hom qua',-1),('hom kia',-2),('ngay mai',1),('ngay mot',2)]:
        if key in q:d=today+timedelta(days=delta);return d,d
    if 'tuan' in q:
        shift=7 if 'tuan sau' in q else -7 if 'tuan truoc' in q else 0
        start=today-timedelta(days=today.weekday())+timedelta(days=shift)
        return start,start+timedelta(days=6)
    month=re.search(r'\bthang (\d{1,2})(?:\s*[/\-]\s*(\d{4})| nam (\d{4}))?',q)
    if month or any(x in q for x in ['thang nay','thang truoc','thang sau']):
        if month: mm=int(month[1]);yy=int(month[2] or month[3] or today.year)
        else:
            shift=-1 if 'thang truoc' in q else 1 if 'thang sau' in q else 0
            yy,zero=divmod(today.year*12+today.month-1+shift,12);mm=zero+1
        return date(yy,mm,1),date(yy,mm,calendar.monthrange(yy,mm)[1])
    quarter=re.search(r'\bquy ([1-4])(?:[/ ](?:nam )?(\d{4}))?',q)
    if quarter or 'quy nay' in q or 'quy truoc' in q or 'quy sau' in q:
        n=int(quarter[1]) if quarter else (today.month-1)//3+1
        yy=int(quarter[2] or today.year) if quarter else today.year
        if not quarter:
            value=yy*4+n-1+(-1 if 'quy truoc' in q else 1 if 'quy sau' in q else 0)
            yy,zero=divmod(value,4);n=zero+1
        start=(n-1)*3+1;end=start+2
        return date(yy,start,1),date(yy,end,calendar.monthrange(yy,end)[1])
    year=re.search(r'\bnam (\d{4})',q)
    if year or 'nam nay' in q or 'nam truoc' in q or 'nam sau' in q:
        yy=int(year[1]) if year else today.year+(-1 if 'nam truoc' in q else 1 if 'nam sau' in q else 0)
        return date(yy,1,1),date(yy,12,31)
    return None

class DebtQAService:
    revision='debt_qa_v1'
    FOLLOWUP=re.compile(r'\b(nguoi do|anh ay|chi ay|ban ay|ho|con|vay|the|da tra|bao nhieu|khi nao|chi tiet|liet ke|lan cuoi|gan nhat|tat toan|ma doi tuong|ma khoan|tra chua|thanh toan chua|het chua)\b')
    SIGNAL=re.compile(r'\b(so no|cong no|du no|no|vay|muon|tat toan|tra cho|tra toi|tra minh|cho toi vay|repay|debt|loan|borrow)\b')
    @classmethod
    def is_debt_question(cls, question, history=None):
        q=intent_fold(question)
        # "dự báo chi tiêu" must continue to its existing model route.
        if cls.SIGNAL.search(q):return True
        prev=cls.previous(history)
        return bool(prev and cls.SIGNAL.search(intent_fold(prev)) and cls.FOLLOWUP.search(q))
    @staticmethod
    def previous(history):
        return next((h.get('content','') for h in reversed(history or []) if h.get('role')=='user'),'')
    @staticmethod
    def direction(q):
        lend=bool(re.search(r'\b(cho vay|cho muon|cho .{1,60} vay|cho .{1,60} muon|no toi|no minh|no cua toi cho|ai no toi|tra toi|tra minh|thu no|thu hoi|da thu|thu duoc|nhan lai|vay toi|muon toi|can thu|receivable|lend|lent|owe me)\b',q))
        borrow=bool(re.search(r'\b(toi (?:dang |con |het )?no|minh (?:dang |con |het )?no|toi (?:da )?vay|toi (?:da )?muon|vay cua|vay tu|muon cua|toi (?:da )?tra|toi (?:da )?thanh toan|thanh toan cho|vay ai|muon ai|dang no ai|no ai|di vay|di muon|tra no|tra cho|can tra|payable|borrow|i owe)\b',q))
        if lend and borrow:return 'both'
        if lend:return 'lend'
        if borrow:return 'borrow'
        # Personal "nợ An" usually means payable; broad ledger totals mean both.
        if not re.search(r'\b(nguoi do|anh ay|chi ay|ban ay|ho)\b',q) and re.search(r'\bno (?!toi\b|minh\b|rong\b|qua\b|xau\b)',q) and not re.search(r'\b(so no|du no|cong no|khoan no|tong no|het no)\b',q):return 'borrow'
        return 'both'
    @staticmethod
    def response(intent,answer,evidence=None,needs=None,warnings=None,context=None):
        return {'success':True,'intent':intent,'answer':answer,'evidence':evidence or {},
                'needsInput':needs or [],'warnings':warnings or [],'serviceRevision':'debt_qa_v1',
                'debtContext':context or {}}
    def normalize(self,snapshot):
        contacts={str(c['id']):dict(c) for c in snapshot.get('contacts',[]) if c.get('id')}
        records=[];warnings=list(snapshot.get('warnings',[]))
        for raw in snapshot.get('items',[]):
            try:
                amount=integer(raw['amount'])
                if amount<=0:raise ValueError('Tiền gốc không hợp lệ')
                direction=raw['direction']
                if direction not in ('lend','borrow'):raise ValueError('Loại khoản nợ không hợp lệ')
                cid=str(raw['contactId'])
                contact=contacts.get(cid,{})
                name=str(contact.get('name') or raw.get('contactName') or cid)
                # Resolve both current names and historic names without rewriting records.
                if cid not in contacts:contacts[cid]={'id':cid,'name':name,'phone':''}
                contacts[cid].setdefault('aliases',[])
                if raw.get('contactName'):contacts[cid]['aliases'].append(str(raw['contactName']))
                payments=[]
                for p in raw.get('payments',[]):
                    n=integer(p['amount'])
                    if n<=0:raise ValueError('Thanh toán không hợp lệ')
                    payments.append({'id':str(p['id']),'amount':n,'date':day(p['date']),'note':str(p.get('note') or '')})
                if len({p['id'] for p in payments})!=len(payments):raise ValueError('ID thanh toán bị trùng')
                paid=sum(p['amount'] for p in payments)
                if paid>amount:raise ValueError('Đã trả vượt tiền gốc')
                records.append({'id':str(raw['id']),'contactId':cid,'contactName':name,'direction':direction,
                    'amount':amount,'paid':paid,'remaining':amount-paid,'date':day(raw['date']),
                    'dueDate':day(raw.get('dueDate')),'payments':payments,'note':str(raw.get('note') or ''),
                    'status':'paid' if paid==amount else 'partial' if paid else 'unpaid'})
            except (KeyError,TypeError,ValueError,OverflowError):
                warnings.append(f"Bản ghi {raw.get('id','không có mã')} không hợp lệ, chưa được cộng vào kết quả.")
        return records,contacts,warnings
    def match_contacts(self,q,contacts,raw=None):
        q=re.sub(r'\b(?:bao nhieu lan|may lan|so lan|lan cuoi|lan gan nhat|nam (?:nay|truoc|sau|\d{4}))\b','',q)
        matches=[]
        def usable(alias):
            key=fold(alias)
            if key in {'lan','nam','minh','anh','chi','ho'}:
                if raw is not None and not re.search(r'(?<!\w)'+re.escape(str(alias).lower())+r'(?!\w)',str(raw).lower()):return False
                if key=='minh' and re.match(r'^minh (?:dang |con )?no ai',q):return False
            return True
        for cid,c in contacts.items():
            aliases=[c.get('name',''),c.get('phone',''),cid,*c.get('aliases',[])]
            lengths=[len(fold(a)) for a in aliases if a and usable(a) and re.search(r'(?<![a-z0-9])'+re.escape(fold(a))+r'(?![a-z0-9])',q)]
            if lengths:matches.append((max(lengths),cid))
        if matches:
            best=max(n for n,_ in matches);return [cid for n,cid in matches if n==best]
        # Short names are allowed only when unambiguous; duplicate "An" asks back.
        words=set(q.split())
        for cid,c in contacts.items():
            last=fold(c.get('name','')).split()[-1:] or ['']
            if last[0] and usable(c.get('name','').split()[-1]) and last[0] in words and last[0] not in {'ai','toi','minh','no','vay','tra'}:matches.append((len(last[0]),cid))
        return [cid for _,cid in matches]
    def answer(self, *, question, snapshot, reference_date=None, history=None, contact_id=None, debt_id=None):
        today=reference_date or datetime.now(TZ).date()
        q=fold(question);previous=fold(self.previous(history))
        short_followup=bool(previous and self.SIGNAL.search(intent_fold(self.previous(history))) and not self.SIGNAL.search(intent_fold(question)) and self.FOLLOWUP.search(q))
        current_q=q
        if short_followup:
            old=re.sub(r'(?<!\d)\d{1,2}/\d{1,2}(?:/\d{4})?(?!\d)|\b(?:hom nay|hom qua|ngay mai|tuan (?:nay|truoc|sau)|thang (?:nay|truoc|sau|\d{1,2}(?:/\d{4})?)|nam (?:nay|truoc|sau|\d{4})|\d+ ngay (?:toi|qua))\b','',previous)
            q+=' '+old
        if re.search(r'\b(la gi|khac nhau|phan biet)\b',q):
            return self.response('debt_definition','Đi vay là khoản bạn cần trả; cho vay là khoản bạn cần thu. Số còn nợ = tiền gốc − các lần thanh toán đã ghi. Trả hết là số còn nợ bằng 0; quá hạn là còn nợ và hạn trả trước hôm nay. Tiền gốc vay/nợ được quản lý riêng với chi tiêu tiêu dùng.')
        if 'so sanh' in q or 'chenh lech giua' in q:
            return self.response('debt_comparison_clarification','Bạn muốn so sánh số tiền đã trả theo ngày thanh toán hay số dư còn nợ ở từng thời điểm? Hãy hỏi từng kỳ cụ thể; số dư quá khứ được tái dựng từ các bản ghi hiện còn.',needs=['comparison_basis'])
        records,contacts,warnings=self.normalize(snapshot)
        if any(w.startswith('Bản ghi ') for w in warnings):
            return self.response('debt_data_invalid','Sổ nợ có bản ghi chưa hợp lệ nên chưa thể tính số tiền đầy đủ. Hãy kiểm tra các khoản nợ.',warnings=warnings,needs=['valid_debt_records'])
        if re.search(r'^(them|xoa|sua|ghi nhan|cap nhat|danh dau|tao)\b',q) or re.search(r'\b(?:hay|vui long|giup toi) (?:them|xoa|sua|ghi nhan|cap nhat)\b',q):
            return self.response('debt_read_only','Hỏi đáp chỉ tra cứu sổ nợ. Hãy thêm, sửa, xóa hoặc ghi nhận thanh toán tại màn hình Sổ nợ.',needs=['use_debt_screen'])
        matches=self.match_contacts(current_q,contacts,question)
        if contact_id:
            if contact_id not in contacts:return self.response('debt_contact_not_found','Không tìm thấy đối tượng có mã này trong sổ nợ của bạn.',needs=['contact_id'])
            matches=[contact_id]
        inherited=False
        if not matches and re.search(r'\b(nguoi do|anh ay|chi ay|ban ay|ho)\b',q):
            matches=self.match_contacts(previous,contacts,self.previous(history));inherited=True
            if not matches:return self.response('debt_contact_clarification','Bạn muốn hỏi khoản nợ của người nào?',needs=['contact_id'])
        elif not matches and short_followup:
            matches=self.match_contacts(previous,contacts,self.previous(history));inherited=True
        if len(matches)>1:
            candidates=[{'contactId':cid,'name':contacts[cid].get('name',cid)} for cid in matches]
            return self.response('debt_contact_clarification','Có nhiều đối tượng phù hợp:\n'+'\n'.join(f"- {c['name']} (mã {c['contactId']})" for c in candidates)+'\nHãy nhập tên đầy đủ hoặc hỏi kèm mã đối tượng.',{'contacts':candidates},['contact_id'])
        # Do not replace an unknown explicit name with a total across all people.
        if not matches:
            person=re.search(r'\b(?:tra cho|(?:toi|minh) (?:dang |con )?no)\s+(?:anh |chi |ban )?([a-z]+(?:\s+[a-z]+){0,3})',q)
            if person:
                candidate=re.split(r'\b(bao|con|da|tong|khi|ngay|thang|nam|hien|hom|gan|trong|voi|hay|can|nao|la|het)\b',person[1])[0].strip()
                if candidate and candidate.split()[0] not in {'ai','nguoi','nhieu','bao','may'} and candidate not in {'ai','toi','minh','nguoi do','tat ca','rong','qua han'} and not candidate.startswith(('cua','sap','chua','nhieu','tung','theo','nguoi','mot','co','o ')):
                    return self.response('debt_contact_not_found',f'Không tìm thấy đối tượng “{candidate}” trong sổ nợ. Hãy nhập đúng tên hoặc mã đối tượng.',needs=['contact_id'])
        direction=self.direction(current_q)
        if (inherited or short_followup) and direction=='both':direction=self.direction(previous)
        selected=[d for d in records if (direction=='both' or d['direction']==direction) and (not matches or d['contactId'] in matches)]
        if debt_id:
            selected=[d for d in selected if d['id']==debt_id]
            if not selected:return self.response('debt_not_found','Không tìm thấy khoản nợ có mã này trong phạm vi đang hỏi.',needs=['debt_id'])
        explicit_id=re.search(r'(?:#|ma khoan\s+)([a-z0-9_-]+)',q)
        if explicit_id:
            selected=[d for d in selected if fold(d['id'])==explicit_id[1]]
            if not selected:return self.response('debt_not_found','Không tìm thấy mã khoản nợ này trong phạm vi đang hỏi.',needs=['debt_id'])
        try:
            period=window(current_q,today)
            if period is None and short_followup and not re.search(r'\b(da tra|lich su|khi nao|den han|qua han)\b',current_q):period=window(previous,today)
        except (ValueError,OverflowError):return self.response('debt_period_clarification','Ngày hoặc khoảng thời gian chưa hợp lệ. Hãy nhập dd/MM/yyyy hoặc tháng/năm.',needs=['valid_period'])
        context={'contactId':matches[0] if matches else None,'direction':direction}
        evidence={'source':snapshot.get('source','provided_test_snapshot'),'asOf':today.isoformat(),
                  'loadedAt':snapshot.get('loadedAt'),'direction':direction,
                  'contactId':context['contactId'],'historyComplete':not warnings}
        if period:evidence['period']={'start':period[0].isoformat(),'end':period[1].isoformat()}
        asof=bool(period and re.search(r'\b(tinh den|den ngay|cuoi thang)\b',q) and not re.search(r'\b(den han|sap den|thanh toan|da tra)\b',q))
        if asof:
            if period[1]>today:return self.response('debt_future_balance','Chưa thể xác định số dư nợ tại một ngày tương lai khi chưa có kế hoạch trả. Có thể hỏi các khoản đến hạn trong khoảng đó.',needs=['repayment_plan'])
            cutoff=period[1];evidence['asOf']=cutoff.isoformat();evidence['periodBasis']='balance_as_of'
            selected=[dict(d) for d in selected if d['date']<=cutoff]
            for d in selected:
                d['payments']=[p for p in d['payments'] if p['date']<=cutoff]
                d['paid']=sum(p['amount'] for p in d['payments']);d['remaining']=d['amount']-d['paid']
                d['status']='paid' if not d['remaining'] else 'partial' if d['paid'] else 'unpaid'
            warnings.append('Số dư quá khứ được tái dựng từ bản ghi hiện tại; các khoản đã sửa/xóa trước đây không có phiên bản lịch sử trong sổ nợ.')
        def result(intent,text,data=None,needs=None):
            return self.response(intent,text,{**evidence,**(data or {})},needs,warnings,context)
        # Payment totals use payment dates, never loan creation dates.
        payment=bool(re.search(r'\b(da tra|da thanh toan|da thu|thu duoc|thu hoi|nhan lai|tra toi|tra minh|lich su|thanh toan gan|tra gan|lan tra|tra may|tra bao nhieu lan)\b',q)) and not re.search(r'\b(da tra het|da tat toan)\b',q)
        if re.search(r'\b(bao nhieu lan|may lan|so lan)\b',q) and re.search(r'\b(tra|thu)\b',q):payment=True
        if period and re.search(r'\b(thu no|tra no)\b',q) and not re.search(r'\b(can|phai|sap|den han|qua han)\b',q):payment=True
        if payment:
            payments=[{**p,'debtId':d['id'],'contactId':d['contactId'],'contactName':d['contactName'],'direction':d['direction']} for d in selected for p in d['payments'] if not period or period[0]<=p['date']<=period[1]]
            payments.sort(key=lambda p:(p['date'],p['id']),reverse=True)
            total=sum(p['amount'] for p in payments);evidence['periodBasis']='payment_date'
            rows=[{**p,'date':p['date'].isoformat()} for p in payments]
            by_direction={key:sum(p['amount'] for p in payments if p['direction']==key) for key in ['borrow','lend']}
            if re.search(r'\b(lan cuoi|gan nhat|gan day nhat)\b',q) and not re.search(r'bao nhieu|tong',q):
                if not payments:return result('debt_last_payment','Chưa có thanh toán phù hợp.',{'payments':[],'totalPaid':0})
                p=payments[0];return result('debt_last_payment',f"Lần ghi nhận gần nhất: {p['contactName']}, {money(p['amount'])}, ngày {p['date']:%d/%m/%Y}.",{'payments':rows[:1],'totalPaid':total})
            if re.search(r'\b(bao nhieu lan|may lan|so lan)\b',q):return result('debt_payment_count',f'Có {len(payments)} lần thanh toán, tổng {money(total)}.',{'paymentCount':len(payments),'totalPaid':total})
            lines=[f"{p['date']:%d/%m/%Y} · {p['contactName']}: {money(p['amount'])}" for p in payments[:20]]
            text=f"Có {len(payments)} lần ghi nhận. Đã trả nợ đi vay: {money(by_direction['borrow'])}; đã thu nợ cho vay: {money(by_direction['lend'])}."
            if re.search(r'\b(lich su|chi tiet|liet ke)\b',q):text+='\n'+'\n'.join(lines)
            return result('debt_payments',text,{'totalPaid':total,'paidBorrow':by_direction['borrow'],'collectedLend':by_direction['lend'],'paymentCount':len(payments),'payments':rows[:50],'shownCount':min(50,len(rows))})
        closed=bool(re.search(r'\b(da tra het|da tat toan|da thanh toan het|hoan tat)\b',q)) and not re.search(r'\b(khong tinh|tru|bo qua)\b',q)
        partial=bool(re.search(r'\b(tra mot phan|chua tra het)\b',q))
        unpaid=bool(re.search(r'\b(chua tra|chua tra gi|chua tra lan nao|chua thanh toan lan nao)\b',q)) and not partial
        if closed:selected=[d for d in selected if d['status']=='paid']
        elif partial:selected=[d for d in selected if d['status']=='partial']
        elif unpaid:selected=[d for d in selected if d['status']=='unpaid']
        due=bool(re.search(r'\b(den han|qua han|han tra|han thanh toan|khi nao|can tat toan|phai tat toan|phai tra het|can tra het|sap tra|khong co han|chua dat han)\b',q))
        if period and re.search(r'\b(can tra|can thu|phai tra|phai thu|du tra|du tien|co the tra|kha nang tra)\b',q):due=True
        if due:
            selected=[d for d in selected if d['remaining']>0]
            missing=[d for d in selected if d['dueDate'] is None]
            if re.search(r'\b(khong co han|chua dat han)\b',q):selected=missing
            elif 'qua han' in q:
                selected=[d for d in selected if d['dueDate'] and d['dueDate']<today]
                late=re.search(r'qua han (?:hon|tren) (\d+) ngay',q)
                if late:selected=[d for d in selected if (today-d['dueDate']).days>int(late[1])]
            if period:selected=[d for d in selected if d['dueDate'] and period[0]<=d['dueDate']<=period[1]]
            elif 'sap' in q:selected=[d for d in selected if d['dueDate'] and today<=d['dueDate']<=today+timedelta(days=29)]
            selected.sort(key=lambda d:(d['dueDate'] or date.max,d['id']))
            evidence['periodBasis']='due_date'
            rows=self.rows(selected,today)
            lines=[f"{d['contactName']}: {'cần trả' if d['direction']=='borrow' else 'cần thu'} {money(d['remaining'])}; "+(f"hạn {d['dueDate']:%d/%m/%Y}" if d['dueDate'] else 'chưa đặt hạn trả') for d in selected[:20]]
            text='\n'.join(lines) if lines else 'Không có khoản nợ còn dư phù hợp với điều kiện hạn trả đang hỏi.'
            if missing and not selected and 'qua han' not in q:text+=f' Có {len(missing)} khoản chưa đặt hạn nên chưa xác định được ngày cần tất toán.'
            text+='\nNgày cần tất toán dựa trên hạn đã ghi, không phải ngày do mô hình dự đoán.'
            if re.search(r'\b(du tien|du tra|co the tra|kha nang tra)\b',q):
                balance=snapshot.get('balance');payable=sum(d['remaining'] for d in selected if d['direction']=='borrow')
                if balance is None:return result('debt_affordability','Chưa đọc được số dư ví để đối chiếu các khoản đến hạn.',needs=['available_balance'])
                return result('debt_affordability',f'Ví có {money(balance)}; cần trả {money(payable)} theo điều kiện hạn trả; thiếu {money(max(0,payable-balance))}.',{'availableBalance':balance,'payableDue':payable,'shortfall':max(0,payable-balance)})
            return result('debt_due_dates',text,{'debts':rows[:50],'recordCount':len(rows),'remaining':sum(d['remaining'] for d in selected),'missingDueDateCount':len(missing),'shownCount':min(50,len(rows)),**self.stats(selected,today)})
        if period and not asof:
            if closed:
                selected=[d for d in selected if d['payments'] and period[0]<=max(p['date'] for p in d['payments'])<=period[1]]
                evidence['periodBasis']='settlement_date'
            else:
                selected=[d for d in selected if period[0]<=d['date']<=period[1]]
                evidence['periodBasis']='loan_date'
        if not closed and not re.search(r'\b(lich su|tat ca|toan bo|ban dau|tien goc|tong vay|da vay)\b',q):selected=[d for d in selected if d['remaining']>0]
        # Explicit note/location equivalents: debt notes can be searched in quotes.
        note=re.search(r'(?:ghi chu|noi dung)\s+["“](.*?)["”]',question,re.I)
        if note:selected=[d for d in selected if fold(note[1]) in fold(d['note'])]
        stats=self.stats(selected,today)
        evidence.update(stats)
        evidence['debts']=self.rows(selected,today)[:50];evidence['shownCount']=min(50,len(selected))
        if re.search(r'\b(du tien|du tra|co the tra|kha nang tra|afford)\b',q):
            balance=snapshot.get('balance');payable=stats['borrowRemaining']
            if balance is None:return result('debt_affordability','Chưa đọc được số dư ví để đối chiếu số cần trả.',needs=['available_balance'])
            text=f'Số dư ví: {money(balance)}. Tổng cần trả trong phạm vi đang hỏi: {money(payable)}. '+(f'Còn {money(balance-payable)} nếu trả hết.' if balance>=payable else f'Thiếu {money(payable-balance)} để trả hết.')
            return result('debt_affordability',text,{'availableBalance':balance,'shortfall':max(0,payable-balance)})
        if re.search(r'\b(tinh lai|lai suat|tien lai|lai vay)\b',q):
            return result('debt_interest_unsupported','Sổ nợ hiện lưu tiền gốc và các lần thanh toán, chưa có trường lãi suất hoặc tiền lãi. Chưa thể tính lãi chính xác.',needs=['interest_terms'])
        if re.search(r'\b(du bao|du doan|bao gio tra duoc|khi nao tra duoc)\b',q):
            return result('debt_forecast_unsupported','Sổ nợ chưa có kế hoạch trả định kỳ hoặc cam kết của đối tượng để dự báo ngày trả hết. Có thể hỏi hạn đã ghi hoặc số còn nợ.',needs=['repayment_plan'])
        if re.search(r'\b(no rong|chenh lech)\b',q):return result('debt_net',f"Cần trả {money(stats['borrowRemaining'])}, cần thu {money(stats['lendRemaining'])}; nợ ròng (cần trả − cần thu) {money(stats['borrowRemaining']-stats['lendRemaining'])}.")
        if re.search(r'\b(nhieu nhat|lon nhat|it nhat|nho nhat|uu tien|tra truoc)\b',q):
            reverse=not re.search(r'\b(it nhat|nho nhat)\b',q)
            if 'uu tien' in q or 'tra truoc' in q:
                selected.sort(key=lambda d:(d['dueDate'] is None,d['dueDate'] or date.max,-d['remaining']))
            else:selected.sort(key=lambda d:d['remaining'],reverse=reverse)
            if re.search(r'\b(ai|nguoi|doi tuong)\b',q) and not ('uu tien' in q or 'tra truoc' in q):
                totals=defaultdict(int);names={}
                for d in selected:totals[d['contactId']]+=d['remaining'];names[d['contactId']]=d['contactName']
                ranked=sorted(totals,key=totals.get,reverse=reverse)
                if not ranked:return result('debt_ranking','Không có đối tượng còn dư nợ phù hợp.')
                evidence['contacts']=[{'contactId':cid,'name':names[cid],'remaining':totals[cid]} for cid in ranked[:50]]
                return result('debt_ranking',f'Đối tượng đứng đầu theo số còn nợ: {names[ranked[0]]}, {money(totals[ranked[0]])}.')
            if not selected:return result('debt_ranking','Không có khoản nợ còn dư phù hợp.')
            evidence['debts']=self.rows(selected,today)[:50]
            first=selected[0]
            return result('debt_ranking',f"Khoản đứng đầu theo {'hạn trả gần nhất, chưa đặt hạn xếp sau' if 'uu tien' in q or 'tra truoc' in q else 'số còn nợ'}: {first['contactName']}, {money(first['remaining'])}.")
        groups=defaultdict(lambda:{'borrowRemaining':0,'lendRemaining':0,'paidBorrow':0,'collectedLend':0,'count':0})
        for d in selected:
            g=groups[d['contactId']];g['name']=d['contactName'];g['count']+=1
            g['borrowRemaining' if d['direction']=='borrow' else 'lendRemaining']+=d['remaining']
            g['paidBorrow' if d['direction']=='borrow' else 'collectedLend']+=d['paid']
        people=[{'contactId':cid,**g} for cid,g in groups.items()]
        evidence['contacts']=people;evidence['contactCount']=len(people)
        if re.search(r'\b(no ai|vay ai|muon ai|ai (?:dang |con )?(?:no|vay)|nhung ai|nguoi nao|cho ai vay|cho ai muon|danh sach nguoi|theo nguoi|tung nguoi)\b',q):
            lines=[f"{p['name']}: cần trả {money(p['borrowRemaining'])}; cần thu {money(p['lendRemaining'])}." for p in people[:50]]
            return result('debt_people','\n'.join(lines) if lines else 'Không có đối tượng còn dư nợ phù hợp.')
        if re.search(r'\b(bao nhieu khoan|may khoan|so khoan|bao nhieu nguoi|may nguoi|so nguoi)\b',q):return result('debt_count',f'Có {len(selected)} khoản thuộc {len(people)} đối tượng trong phạm vi đang hỏi.')
        if re.search(r'\b(het no|tat toan chua|tra het chua)\b',q):
            exists=any((direction=='both' or d['direction']==direction) and (not matches or d['contactId'] in matches) for d in records)
            if not exists:return result('debt_settlement_status','Không có khoản nợ phù hợp trong sổ để xác nhận tình trạng tất toán.')
            return result('debt_settlement_status',f'Chưa tất toán hết: còn {money(stats["remaining"])} trong phạm vi đang hỏi.' if stats['remaining'] else 'Các khoản nợ trong phạm vi đang hỏi đã thanh toán hết.')
        label=f"Đối tượng {contacts[matches[0]].get('name')}" if matches else 'Sổ nợ'
        text=f"{label}: cần trả {money(stats['borrowRemaining'])}; cần thu {money(stats['lendRemaining'])}. Có {len(selected)} khoản phù hợp."
        if re.search(r'\b(ban dau|tien goc|tong vay|da vay)\b',q):text+=f" Tổng tiền gốc: {money(stats['principal'])}."
        if re.search(r'\b(chi tiet|liet ke|tong quan|phan tich|bao cao)\b',q):
            text+='\n'+'\n'.join(f"{d['contactName']}: {'đi vay' if d['direction']=='borrow' else 'cho vay'}, gốc {money(d['amount'])}, đã thanh toán {money(d['paid'])}, còn {money(d['remaining'])}." for d in selected[:20])
        if re.search(r'\b(tong quan|phan tich|bao cao)\b',q):text+=f"\nCần chú ý: {stats['overdueCount']} khoản quá hạn ({money(stats['overdueRemaining'])}); {stats['missingDeadlineCount']} khoản chưa đặt hạn."
        if closed:text=f'Có {len(selected)} khoản đã thanh toán hết, tổng tiền gốc {money(stats["principal"])}.'
        return result('debt_summary',text)
    @staticmethod
    def stats(records,today=None):
        today=today or datetime.now(TZ).date()
        return {'overdueCount':sum(1 for d in records if d['remaining']>0 and d['dueDate'] and d['dueDate']<today),
                'overdueRemaining':sum(d['remaining'] for d in records if d['remaining']>0 and d['dueDate'] and d['dueDate']<today),
                'missingDeadlineCount':sum(1 for d in records if d['remaining']>0 and d['dueDate'] is None),
                'principal':sum(d['amount'] for d in records),'paid':sum(d['paid'] for d in records),
                'remaining':sum(d['remaining'] for d in records),
                'borrowRemaining':sum(d['remaining'] for d in records if d['direction']=='borrow'),
                'lendRemaining':sum(d['remaining'] for d in records if d['direction']=='lend'),
                'recordCount':len(records)}
    @staticmethod
    def rows(records,today):
        return [{k:(v.isoformat() if isinstance(v,date) else v) for k,v in d.items() if k!='payments'} |
                {'overdueDays':max(0,(today-d['dueDate']).days) if d['dueDate'] and d['remaining']>0 else 0}
                for d in records]
