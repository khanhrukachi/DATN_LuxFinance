import 'package:personal_financial_management/features/main/debt/debt_book_screen.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_category_widgets.dart';

import 'debt_reminder_settings_page.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../../controls/notification_service.dart';
import '../../controls/debt_reminder_service.dart';
import '../../controls/debt_firebase.dart';
import '../spending/add_spending/widget/spending_style.dart';

Map<String,dynamic> reminderData(String? payload) {
  try {return Map<String,dynamic>.from(jsonDecode(payload ?? '') as Map);}
  catch(_){return {};}
}
class ReminderSchedulePage extends StatefulWidget {
  const ReminderSchedulePage({Key? key}):super(key:key);
  @override State<ReminderSchedulePage> createState()=>_ReminderSchedulePageState();
}
class _ReminderSchedulePageState extends State<ReminderSchedulePage> {
  final service=NotificationService();
  List<PendingNotificationRequest> items=[];
  String? uid,error;
  bool loading=true,busy=false;
  String filter='all';
  @override void initState(){super.initState();uid=FirebaseAuth.instance.currentUser?.uid;load();}
  bool get active=>uid!=null && FirebaseAuth.instance.currentUser?.uid==uid;
  void message(String value){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(value)));}
  Future<void> load() async {
    if(!active){if(mounted)setState(() {loading=false;error='Bạn cần đăng nhập lại';items=[];});return;}
    if(mounted)setState(() {loading=true;error=null;});
    try {
      await service.initialize();
      final pending=await service.getPendingReminders();
      if(!mounted || !active)return;
      pending.sort((a,b){
        final x=DateTime.tryParse(reminderData(a.payload)['scheduledAt']?.toString() ?? '');
        final y=DateTime.tryParse(reminderData(b.payload)['scheduledAt']?.toString() ?? '');
        if(x==null)return y==null ? a.id.compareTo(b.id) : 1;
        if(y==null)return -1;
        return x.compareTo(y);
      });
      setState(() {items=pending.where((p){final d=reminderData(p.payload);return d['uid']==null || d['uid']==uid;}).toList();loading=false;});
    }catch(e){if(mounted)setState(() {error=e.toString();loading=false;});}
  }
  bool daily(PendingNotificationRequest p)=>p.id==2000000001 || reminderData(p.payload)['source']=='daily_spending';
  String kind(PendingNotificationRequest p)=>reminderData(p.payload)['source']=='debt_local' ? 'debt' : daily(p) ? 'daily' : 'other';
  Future<void> configureDaily() async {
    if(!active)return;
    PendingNotificationRequest? current;
    for(final item in items){if(daily(item)){current=item;break;}}
    final data=reminderData(current?.payload);
    final initial=TimeOfDay(hour:(data['hour'] as num?)?.toInt() ?? 20,minute:(data['minute'] as num?)?.toInt() ?? 0);
    final selected=await showTimePicker(context:context,initialTime:initial);
    if(selected==null || !mounted || !active)return;
    await execute(() async {
      final allowed=await service.requestLocalNotificationPermission();
      if(!allowed)throw StateError('Chưa có quyền thông báo. Hãy bật trong cài đặt thiết bị.');
      await service.configureDailyReminder(enabled:true,hour:selected.hour,minute:selected.minute);
    });
  }
  Future<void> execute(Future<void> Function() action) async {
    if(busy || !active)return;
    setState(() => busy=true);
    try {await action();await load();}
    catch(e){message(e.toString());}
    finally{if(mounted)setState(() => busy=false);}
  }
  Future<void> cancel(PendingNotificationRequest p) async {
    if(busy || !active)return;
    final isDebt=kind(p)=='debt';
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(isDebt ? 'Tắt nhắc khoản nợ?' : 'Hủy lịch nhắc?'),content:Text(isDebt ? 'Tắt nhắc cho khoản này trên tài khoản và hủy các lịch liên quan trên thiết bị. Khoản nợ và số dư ví giữ nguyên.' : p.title ?? 'LuxFinance'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Giữ lại')),TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Hủy lịch'))]));
    if(yes!=true || !mounted || !active)return;
    await execute(() async {
      if(isDebt) {
        final id=reminderData(p.payload)['debtId']?.toString();
        if(id==null || id.isEmpty)throw StateError('Lịch nhắc không có mã khoản nợ');
        await DebtFirebase(userId:uid).setReminderEnabled(id,false);
        await DebtReminderService.instance.refreshSafely(uid);
        final err=DebtReminderService.instance.lastError;
        if(err!=null)throw StateError('Đã tắt nhắc trong sổ nợ nhưng thiết bị chưa đồng bộ: $err');
      }else if(daily(p)) {await service.configureDailyReminder(enabled:false);if(p.id!=2000000001)await service.cancelReminder(p.id);}
      else {await service.cancelReminder(p.id);}
    });
  }
  String timing(PendingNotificationRequest p) {
    final data=reminderData(p.payload);
    if(daily(p)) {
      final h=(data['hour'] as num?)?.toInt(),m=(data['minute'] as num?)?.toInt();
      return h==null || m==null ? 'Lặp lại hằng ngày · lịch cũ chưa có giờ trong dữ liệu' : 'Hằng ngày ${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}';
    }
    final date=DateTime.tryParse(data['scheduledAt']?.toString() ?? '');
    return date==null ? 'Lịch cũ chưa có thông tin thời điểm' : DateFormat('dd/MM/yyyy · HH:mm').format(date.toLocal());
  }
  @override Widget build(BuildContext context) {
    final filtered=items.where((p)=>filter=='all' || kind(p)==filter).toList();
    return Scaffold(backgroundColor:SpendingStyle.background(context),appBar:AppBar(backgroundColor:SpendingStyle.background(context),title:const Text('Lịch nhắc'),actions:[IconButton(tooltip:'Đồng bộ nhắc nợ',onPressed:busy ? null : ()=>execute(() async {await DebtReminderService.instance.refreshSafely(uid);final err=DebtReminderService.instance.lastError;if(err!=null)throw StateError(err);}),icon:const Icon(Icons.sync))]),
        floatingActionButton:FloatingActionButton(backgroundColor:SpendingStyle.teal,foregroundColor:SpendingStyle.ink,onPressed:busy || !active ? null : () async {await Navigator.push(context,MaterialPageRoute(builder:(_)=>const ManualReminderEditor()));if(mounted)load();},child:const Icon(Icons.add_alarm)),
        body:loading ? const Center(child:CircularProgressIndicator()) : error!=null ? Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!,textAlign:TextAlign.center),TextButton(onPressed:load,child:const Text('Thử lại'))]))) : RefreshIndicator(onRefresh:load,child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(16,8,16,100),children:[
          Container(padding:const EdgeInsets.all(20),decoration:SpendingStyle.decoration(context,hero:true),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${items.length} lịch đang chờ',style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)),const SizedBox(height:8),const Text('Lịch trên thiết bị này. Không cần chạy server Python để nhận nhắc đã đặt.'),const SizedBox(height:12),TextButton.icon(onPressed:busy || !active ? null : () async {await Navigator.push(context,MaterialPageRoute(builder:(_)=>const DebtReminderSettingsPage()));if(mounted)load();},icon:const Icon(Icons.menu_book_outlined),label:const Text('Bật / tắt nhắc hạn sổ nợ')),SpendingActionButton(label:'Đặt giờ ghi chi tiêu hằng ngày',icon:Icons.schedule,onPressed:busy ? null : configureDaily)])),
          const SizedBox(height:12),Wrap(spacing:8,children:[for(final entry in {'all':'Tất cả','debt':'Sổ nợ','daily':'Hằng ngày','other':'Khác'}.entries)ChoiceChip(label:Text(entry.value),selected:filter==entry.key,onSelected:(_)=>setState(()=>filter=entry.key))]),
          if(busy)const LinearProgressIndicator(),
          if(filtered.isEmpty)const Padding(padding:EdgeInsets.all(32),child:Text('Chưa có lịch phù hợp. Nhấn + để thêm lịch riêng.',textAlign:TextAlign.center)),
          for(final p in filtered)Container(margin:const EdgeInsets.only(top:12),decoration:SpendingStyle.decoration(context),child:ListTile(contentPadding:const EdgeInsets.all(16),leading:kind(p)=='debt' ? DebtCategoryIcon(id:reminderData(p.payload)['categoryId']?.toString() ?? 'loan') : const SpendingFieldIcon(icon:Icons.alarm),title:Text(p.title ?? 'LuxFinance',style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${timing(p)}${p.body==null ? '' : '\n${p.body}'}'),trailing:IconButton(tooltip:'Hủy lịch',icon:const Icon(Icons.notifications_off_outlined),onPressed:busy ? null : ()=>cancel(p)),onTap:kind(p)=='debt' ? () {final id=reminderData(p.payload)['debtId']?.toString();if(id!=null && active)Navigator.push(context,MaterialPageRoute(builder:(_)=>DebtDetailScreen(service:DebtFirebase(userId:uid),id:id)));} : daily(p) ? configureDaily : reminderData(p.payload)['source']=='manual_reminder' ? () async {await Navigator.push(context,MaterialPageRoute(builder:(_)=>ManualReminderEditor(existing:p)));if(mounted)load();} : null)),
        ])));
  }
}
class ManualReminderEditor extends StatefulWidget {
  final PendingNotificationRequest? existing;
  const ManualReminderEditor({Key? key,this.existing}):super(key:key);
  @override State<ManualReminderEditor> createState()=>_ManualReminderEditorState();
}
class _ManualReminderEditorState extends State<ManualReminderEditor> {
  final title=TextEditingController(),body=TextEditingController();
  final form=GlobalKey<FormState>();
  final service=NotificationService();
  DateTime time=DateTime.now().add(const Duration(hours:1));
  bool saving=false;int? id;late final String? uid;
  @override void initState(){super.initState();uid=FirebaseAuth.instance.currentUser?.uid;final old=widget.existing;if(old!=null){id=old.id;title.text=old.title ?? '';body.text=old.body ?? '';time=DateTime.tryParse(reminderData(old.payload)['scheduledAt']?.toString() ?? '')?.toLocal() ?? time;}}
  @override void dispose(){title.dispose();body.dispose();super.dispose();}
  Future<void> pick() async {
    final date=await showDatePicker(context:context,initialDate:time,firstDate:DateTime.now().subtract(const Duration(days:1)),lastDate:DateTime(2100));
    if(date==null || !mounted)return;
    final hour=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(time));
    if(hour!=null && mounted)setState(()=>time=DateTime(date.year,date.month,date.day,hour.hour,hour.minute));
  }
  Future<void> save() async {
    if(saving || !form.currentState!.validate())return;
    if(!time.isAfter(DateTime.now())){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Chọn thời điểm ở tương lai')));return;}
    setState(()=>saving=true);
    try {
      if(uid==null || FirebaseAuth.instance.currentUser?.uid!=uid)throw StateError('Phiên đăng nhập đã thay đổi');
      final allowed=await service.requestLocalNotificationPermission();
      if(!allowed)throw StateError('Chưa có quyền thông báo');
      final pending=await service.getPendingReminders();
      if(id==null && pending.length>=60)throw StateError('Thiết bị đã có nhiều lịch. Hủy bớt lịch trước khi thêm.');
      if(id==null) {
        final used=pending.map((p)=>p.id).toSet();
        var candidate=1400000000+DateTime.now().millisecondsSinceEpoch % 100000000;
        while(used.contains(candidate)){candidate++;}
        id=candidate;
      }
      await service.scheduleReminder(id:id!,scheduledAt:time,title:title.text.trim(),body:body.text.trim(),data:{'source':'manual_reminder','uid':uid});
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:SpendingStyle.background(context),appBar:AppBar(backgroundColor:SpendingStyle.background(context),title:Text(widget.existing==null ? 'Thêm lịch nhắc' : 'Sửa lịch nhắc')),body:AbsorbPointer(absorbing:saving,child:Form(key:form,child:ListView(padding:const EdgeInsets.all(16),children:[
    TextFormField(controller:title,maxLength:100,decoration:SpendingStyle.input(context,'Tiêu đề',icon:Icons.notifications_outlined),validator:(v)=>v==null || v.trim().isEmpty ? 'Nhập tiêu đề' : null),const SizedBox(height:12),
    TextFormField(controller:body,maxLength:500,maxLines:3,decoration:SpendingStyle.input(context,'Nội dung')),const SizedBox(height:12),
    Container(decoration:SpendingStyle.decoration(context),child:ListTile(leading:const Icon(Icons.event_available),title:const Text('Thời điểm nhắc'),subtitle:Text(DateFormat('dd/MM/yyyy · HH:mm').format(time)),onTap:pick)),const SizedBox(height:20),
    if(saving)const Center(child:CircularProgressIndicator()) else SpendingActionButton(label:'Đặt lịch nhắc',onPressed:save),
  ]))));
}
