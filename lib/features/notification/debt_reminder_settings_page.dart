import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_category_widgets.dart';
import '../../controls/debt_firebase.dart';
import '../../controls/debt_reminder_service.dart';
import '../../models/debt.dart';
import '../spending/add_spending/widget/spending_style.dart';
import 'package:intl/intl.dart';

class DebtReminderSettingsPage extends StatefulWidget {
  const DebtReminderSettingsPage({Key? key}):super(key:key);
  @override State<DebtReminderSettingsPage> createState()=>_DebtReminderSettingsPageState();
}
class _DebtReminderSettingsPageState extends State<DebtReminderSettingsPage> {
  late final DebtFirebase service;
  late final Stream<List<Debt>> stream;
  final busy=<String>{};
  @override void initState(){super.initState();service=DebtFirebase();stream=service.watchDebts();}
  Future<void> toggle(Debt d,bool enabled) async {
    if(busy.contains(d.id) || FirebaseAuth.instance.currentUser?.uid!=service.uid)return;
    setState(()=>busy.add(d.id));
    try {
      if(enabled) {
        final allowed=await DebtReminderService.instance.requestPermission();
        if(!allowed)throw StateError('Bật quyền thông báo trong cài đặt thiết bị trước.');
      }
      await service.setReminderEnabled(d.id,enabled);
      await DebtReminderService.instance.refreshSafely(service.uid);
      final error=DebtReminderService.instance.lastError;
      if(error!=null)throw StateError('Đã lưu tùy chọn; chưa cập nhật được lịch trên thiết bị: $error');
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally{if(mounted)setState(()=>busy.remove(d.id));}
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:SpendingStyle.background(context),appBar:AppBar(backgroundColor:SpendingStyle.background(context),title:const Text('Nhắc hạn sổ nợ')),body:StreamBuilder<List<Debt>>(stream:stream,builder:(context,s){
    if(s.hasError)return Center(child:Text('Không tải được khoản nợ: ${s.error}'));
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final active=s.data!.where((d)=>d.remaining>0).toList();
    if(active.isEmpty)return const Center(child:Text('Không có khoản nợ cần nhắc'));
    return ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(16),decoration:SpendingStyle.decoration(context,hero:true),child:const Text('Quản lý nhắc hạn tại đây. Hạn trả được ghi trong khoản nợ; bật/tắt nhắc không thay đổi số dư ví.')),
      for(final d in active)Container(margin:const EdgeInsets.only(top:12),decoration:SpendingStyle.decoration(context),child:SwitchListTile(secondary:DebtCategoryIcon(id:DebtCategoryPresentation.id(d.direction)),title:Text(d.contactName,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${DebtCategoryPresentation.title(context,DebtCategoryPresentation.id(d.direction))}\n${d.dueDate==null ? 'Chưa có hạn trả. Hãy bổ sung hạn ở khoản nợ.' : 'Hạn ${DateFormat('dd/MM/yyyy').format(d.dueDate!)}'}'),value:d.remind && d.dueDate!=null,onChanged:busy.contains(d.id) || d.dueDate==null ? null : (v)=>toggle(d,v))),
    ]);
  }));
}
