import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/controls/debt_reminder_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/controls/wallet_firebase.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_category_widgets.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_contact_picker.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_phone_field.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:share_plus/share_plus.dart';


String _t(BuildContext context, String key) => AppLocalizations.of(context).translate(key);

String debtMoney(int n) => '${NumberFormat.decimalPattern('vi_VN').format(n)} ₫';
String debtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
String debtStatus(BuildContext context, Debt d) => d.remaining == 0 ? _t(context,'debt_status_paid') : d.overdue ? _t(context,'debt_status_overdue') : d.paid > 0 ? _t(context,'debt_status_partial') : _t(context,'debt_status_unpaid');

Widget _debtScreenSkeleton(BuildContext context) {
  final baseColor = SpendingStyle.card(context);
  final highlightColor = SpendingStyle.teal.withOpacity(.18);

  Widget placeholder({double? width, required double height, double radius = 14}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  return Shimmer.fromColors(
    baseColor: baseColor,
    highlightColor: highlightColor,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        placeholder(height: 82, radius: 20),
        const SizedBox(height: 14),
        placeholder(height: 142, radius: 24),
        const SizedBox(height: 18),
        placeholder(height: 50, radius: 16),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: placeholder(height: 38, radius: 20)),
          const SizedBox(width: 8),
          Expanded(child: placeholder(height: 38, radius: 20)),
          const SizedBox(width: 8),
          Expanded(child: placeholder(height: 38, radius: 20)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: placeholder(height: 36, radius: 20)),
          const SizedBox(width: 8),
          Expanded(child: placeholder(height: 36, radius: 20)),
          const SizedBox(width: 8),
          Expanded(child: placeholder(height: 36, radius: 20)),
        ]),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[
          placeholder(height: 86, radius: 20),
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
}

class DebtBookScreen extends StatefulWidget {
  const DebtBookScreen({Key? key}) : super(key:key);
  @override State<DebtBookScreen> createState() => _DebtBookScreenState();
}
class _DebtBookScreenState extends State<DebtBookScreen> with WidgetsBindingObserver {
  late final DebtFirebase service;
  late final Stream<List<Debt>> debts;
  late final Stream<List<DebtContact>> contacts;
  late final Stream<int> balance;
  String search = '', direction = 'all', status = 'all';
  bool exporting = false, checking = false;
  List<Debt> latest = [];
  @override void initState() {
    super.initState(); service = DebtFirebase(); debts = service.watchDebts(); contacts = service.watchContacts(); balance=WalletFirebase.watch(service.uid);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => checkReminders());
  }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkReminders();
  }
  Future<void> checkReminders() async {
    if (checking) return;
    checking = true;
    try {
      await DebtReminderService.instance.refreshSafely(service.uid);
      final error=DebtReminderService.instance.lastError;
      if(error!=null && mounted) message(_t(context,'debt_reminder_error') + ': $error');
    } catch (e) { if (mounted) message(_t(context,'debt_reminder_check_error') + ': $e'); }
    finally { checking = false; }
  }
  void message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text))); }
  Future<void> perform(Future<void> Function() action) async {
    try { await action(); } catch(e) { message(e.toString()); }
  }
  Future<void> export() async {
    setState(() => exporting = true);
    loadingAnimation(context);
    var loadingVisible = true;
    try {
      final snapshot = await service.items.get();
      final all = snapshot.docs.map(Debt.fromDoc).toList();
      if(!mounted)return;
      String cell(Object? s) {
        var value = s?.toString() ?? '';
        if (RegExp(r'^[=+@\-\t\r]').hasMatch(value)) value = "'$value";
        return '"${value.replaceAll('"','""')}"';
      }
      final rows = <List<Object?>>[
        [_t(context,'debt_export_record_type'),_t(context,'debt_export_id'),_t(context,'debt_export_contact'),_t(context,'debt_export_category'),_t(context,'debt_export_amount'),_t(context,'debt_export_paid'),_t(context,'debt_export_remaining'),_t(context,'debt_export_date'),_t(context,'debt_export_due_date'),_t(context,'debt_export_status'),_t(context,'debt_export_note')],
        for(final d in all) ...[
          [_t(context,'debt_export_debt'),d.id,d.contactName,DebtCategoryPresentation.title(context,d.categoryId),d.amount,d.paid,d.remaining,debtDate(d.date),d.dueDate == null ? '' : debtDate(d.dueDate!),debtStatus(context,d),d.note],
          for(final p in d.payments) [_t(context,'debt_export_payment'),d.id,d.contactName,DebtCategoryPresentation.title(context,d.paymentCategoryId),p.amount,'','',debtDate(p.date),'','',p.note],
        ]
      ];
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/so_no_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsBytes([0xef,0xbb,0xbf,...utf8.encode(rows.map((r) => r.map(cell).join(',')).join('\r\n'))]);
      if (!mounted) return;
      Navigator.of(context,rootNavigator:true).pop();
      loadingVisible = false;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles([XFile(file.path)], text:_t(context,'debt_export_share_title'), sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size);
    } catch(e) { message(_t(context,'debt_export_error') + ': $e'); }
    finally {
      if(loadingVisible && mounted) Navigator.of(context,rootNavigator:true).pop();
      if(mounted) setState(() => exporting = false);
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: SpendingStyle.background(context),
    appBar: AppBar(backgroundColor:SpendingStyle.background(context),title:Text(_t(context,'debt_book_title')),actions:[
      IconButton(tooltip:_t(context,'debt_add'),icon:const Icon(Icons.add_circle_outline_rounded),onPressed:() => Navigator.push(context,MaterialPageRoute(builder:(_) => DebtEditor(service:service)))),
      IconButton(tooltip:_t(context,'debt_contacts_title'),icon:const Icon(Icons.people_outline),onPressed:() => Navigator.push(context,MaterialPageRoute(builder:(_) => DebtContactsScreen(service:service)))),
      IconButton(tooltip:_t(context,'debt_export_csv'),icon:const Icon(Icons.ios_share),onPressed:exporting ? null : export),
    ]),
    body: StreamBuilder<List<Debt>>(stream:debts,builder:(context,snapshot) {
      if(snapshot.hasError) return Center(child:Text(_t(context,'debt_load_error') + ': ' + snapshot.error.toString()));
      if(!snapshot.hasData) return _debtScreenSkeleton(context);
      final all = snapshot.data!; latest = all;
      final filtered = all.where((d) => (direction == 'all' || d.direction == direction) && (status == 'all' || (status == 'overdue' ? d.overdue : d.status == status)) && '${d.contactName} ${d.note}'.toLowerCase().contains(search.toLowerCase())).toList();
      int total(String type) => all.where((d) => d.direction == type).fold(0,(s,d) => s+d.remaining);
      return ListView(padding:const EdgeInsets.fromLTRB(16,8,16,100),children:[
        StreamBuilder<int>(stream:balance,builder:(context,w) => Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(16),decoration:SpendingStyle.decoration(context),child:Text(w.hasError ? _t(context,'debt_wallet_load_error') : _t(context,'debt_wallet_balance') + ': ' + (w.hasData ? debtMoney(w.data!) : '...'),style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)))),
        Container(padding:const EdgeInsets.all(20),decoration:SpendingStyle.decoration(context,hero:true),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(_t(context,'debt_total'),style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:14),
          Text(_t(context,'debt_to_collect') + '  ' + debtMoney(total('lend')),style:TextStyle(fontSize:21,fontWeight:FontWeight.bold,color:SpendingStyle.accent(context))),
          const SizedBox(height:8),Text(_t(context,'debt_to_pay') + '  ' + debtMoney(total('borrow')),style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
          const SizedBox(height:10),Text(all.where((d) => d.overdue).length.toString()+' '+_t(context,'debt_overdue_count')+' · '+all.where((d) => d.status == 'paid').length.toString()+' '+_t(context,'debt_completed_count')),
        ])),const SizedBox(height:16),
        TextField(decoration:SpendingStyle.input(context,_t(context,'debt_search'),icon:Icons.search),onChanged:(v) => setState(() => search=v)),
        const SizedBox(height:12),Wrap(spacing:8,children:[
          for(final entry in {'all':_t(context,'debt_filter_all'),'lend':_t(context,'debt_filter_lend'),'borrow':_t(context,'debt_filter_borrow')}.entries) ChoiceChip(avatar:entry.key=='all' ? null : DebtCategoryIcon(id:DebtCategoryPresentation.id(entry.key),size:24),label:Text(entry.key=='all' ? entry.value : DebtCategoryPresentation.title(context,DebtCategoryPresentation.id(entry.key))),selected:direction == entry.key,onSelected:(_) => setState(() => direction=entry.key))]),
        Wrap(spacing:8,children:[for(final entry in {'all':_t(context,'debt_status_all'),'unpaid':_t(context,'debt_status_unpaid'),'partial':_t(context,'debt_status_partial'),'paid':_t(context,'debt_status_paid'),'overdue':_t(context,'debt_status_overdue')}.entries) ChoiceChip(label:Text(entry.value),selected:status==entry.key,onSelected:(_) => setState(() => status=entry.key))]),
        const SizedBox(height:12),Text(filtered.length.toString()+' '+_t(context,filtered.length==1 ? 'debt_count_one' : 'debt_count_many')),
        if(filtered.isEmpty) Padding(padding:const EdgeInsets.all(28),child:Text(_t(context,'debt_empty'),textAlign:TextAlign.center)),
        for(final d in filtered) Padding(padding:const EdgeInsets.only(top:12),child:Container(decoration:SpendingStyle.decoration(context),child:Material(color:Colors.transparent,borderRadius:BorderRadius.circular(20),clipBehavior:Clip.antiAlias,child:ListTile(
          contentPadding:const EdgeInsets.all(16),leading:DebtCategoryIcon(id:DebtCategoryPresentation.id(d.direction)),
          title:Text(d.contactName,style:const TextStyle(fontWeight:FontWeight.bold)),
          subtitle:Padding(padding:const EdgeInsets.only(top:6),child:Text((d.direction=='lend' ? _t(context,'debt_to_collect') : _t(context,'debt_to_pay'))+': '+debtMoney(d.remaining)+'\n'+debtStatus(context,d)+(d.dueDate==null ? '' : ' · '+_t(context,'debt_due_date')+' '+debtDate(d.dueDate!)),style:TextStyle(color:d.overdue ? SpendingStyle.danger : SpendingStyle.muted(context)))),
          trailing:const Icon(Icons.chevron_right),onTap:() => Navigator.push(context,MaterialPageRoute(builder:(_) => DebtDetailScreen(service:service,id:d.id))),
        )))),
      ]);
    }),
  );
}

class DebtEditor extends StatefulWidget {
  final DebtFirebase service; final Debt? debt;
  const DebtEditor({Key? key,required this.service,this.debt}):super(key:key);
  @override State<DebtEditor> createState() => _DebtEditorState();
}
class _DebtEditorState extends State<DebtEditor> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(), note = TextEditingController();
  late DateTime date; DateTime? due;
  String direction='lend'; String? contactId; bool remind=true,busy=false,walletTracked=true,alreadyInWallet=false;
  late final String draftId;
  @override void initState() {super.initState(); final d=widget.debt; date=d?.date ?? DateTime.now(); draftId=d?.id ?? widget.service.items.doc().id; walletTracked=d?.walletTracked ?? true; due=d?.dueDate; direction=d?.direction ?? 'lend'; contactId=d?.contactId; remind=d?.remind ?? true; amount.text=d?.amount.toString() ?? ''; note.text=d?.note ?? '';}
  @override void dispose() {amount.dispose();note.dispose();super.dispose();}
  Future<void> pick(bool deadline) async {
    final result=await showDatePicker(context:context,initialDate:(deadline ? due : date) ?? date,firstDate:DateTime(2000),lastDate:DateTime(2100));
    if(result!=null && mounted) setState(() {if(deadline) due=result; else date=result;});
  }
  Future<void> save(List<DebtContact> list) async {
    if(!form.currentState!.validate()) return;
    setState(() => busy=true);
    loadingAnimation(context);
    var loadingVisible = true;
    try {
      final selected=list.firstWhere((c) => c.id==contactId);
      final old=widget.debt;
      await widget.service.saveDebt(Debt(id:draftId,contactId:selected.id,contactName:selected.name,direction:direction,amount:int.parse(amount.text),date:date,dueDate:due,remind:remind,note:note.text.trim(),payments:old?.payments ?? [],revision:old?.revision ?? 0,walletTracked:walletTracked,walletImpact:old?.walletImpact ?? 0), create:old==null,alreadyInWallet:alreadyInWallet);
      if(mounted) {
        Navigator.of(context,rootNavigator:true).pop();
        loadingVisible = false;
        Navigator.pop(context);
      }
    } catch(e) {if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally {
      if(loadingVisible && mounted) Navigator.of(context,rootNavigator:true).pop();
      if(mounted) setState(() => busy=false);
    }
  }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:SpendingStyle.background(context),appBar:AppBar(backgroundColor:SpendingStyle.background(context),title:Text(widget.debt==null ? _t(context,'debt_add') : _t(context,'debt_edit'))),
      body:StreamBuilder<List<DebtContact>>(stream:widget.service.watchContacts(),builder:(context,s) {
        if(s.hasError) return Center(child:Text(_t(context,'debt_contacts_load_error')+': '+s.error.toString()));
        if(!s.hasData) return _debtScreenSkeleton(context);
        final list=s.data!;
        final exists=list.any((c) => c.id==contactId);
        return AbsorbPointer(absorbing:busy,child:Form(key:form,child:ListView(padding:const EdgeInsets.all(16),children:[
          Container(padding:const EdgeInsets.all(16),decoration:SpendingStyle.decoration(context),child:Material(color:Colors.transparent,borderRadius:BorderRadius.circular(20),child:Column(children:[
            DebtTypeSelector(value:direction,onChanged:widget.debt?.payments.isNotEmpty==true ? null : (v)=>setState(()=>direction=v)),
            const SizedBox(height:18),DebtContactSelectField(service:widget.service,selected:exists ? list.firstWhere((c)=>c.id==contactId) : null,enabled:widget.debt?.payments.isNotEmpty!=true,onChanged:(c)=>setState(()=>contactId=c.id)),
            TextFormField(controller:amount,keyboardType:TextInputType.number,inputFormatters:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(12)],decoration:SpendingStyle.input(context,_t(context,'debt_amount'),icon:Icons.payments_outlined),validator:(v) => (int.tryParse(v ?? '') ?? 0)<=0 ? _t(context,'debt_amount_required') : null),
            const SizedBox(height:14),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.calendar_month),title:Text(_t(context,'debt_transaction_date')),subtitle:Text(debtDate(date)),onTap:() => pick(false)),
            ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.event_available),title:Text(_t(context,'debt_due_date')),subtitle:Text(due==null ? _t(context,'debt_due_not_set') : debtDate(due!)),onTap:() => pick(true),trailing:due==null ? null : IconButton(icon:const Icon(Icons.clear),onPressed:() => setState(() => due=null))),
            SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(_t(context,'debt_track_wallet')),subtitle:Text(widget.debt!=null && !widget.debt!.walletTracked ? _t(context,'debt_wallet_enable_hint') : _t(context,'debt_wallet_hint')),value:walletTracked,onChanged:widget.debt?.walletTracked==true ? null : (v) => setState(() => walletTracked=v)),
            if(walletTracked && widget.debt?.walletTracked!=true) CheckboxListTile(contentPadding:EdgeInsets.zero,title:Text(_t(context,'debt_already_in_wallet')),subtitle:Text(_t(context,'debt_already_in_wallet_hint')),value:alreadyInWallet,onChanged:(v) => setState(() => alreadyInWallet=v ?? false)),
            TextFormField(controller:note,maxLines:3,maxLength:500,decoration:SpendingStyle.input(context,_t(context,'debt_note'),icon:Icons.edit_note)),
          ]))),const SizedBox(height:20),SpendingActionButton(label:_t(context,'debt_save'),onPressed:busy ? null : () => save(list)),
        ])));
      }));
}

class DebtDetailScreen extends StatefulWidget {
  final DebtFirebase service; final String id;
  const DebtDetailScreen({Key? key,required this.service,required this.id}):super(key:key);
  @override State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}
class _DebtDetailScreenState extends State<DebtDetailScreen> {
  bool busy=false;
  late final Stream<DocumentSnapshot<Map<String,dynamic>>> stream;
  @override void initState(){super.initState();stream=widget.service.items.doc(widget.id).snapshots();}
  Future<bool> confirm(String text) async => await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
    backgroundColor:SpendingStyle.card(c),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
    icon:Icon(Icons.info_outline_rounded,color:SpendingStyle.danger,size:30),
    title:Text(_t(context,'debt_confirm_title')),content:SingleChildScrollView(child:Text(text)),
    actionsPadding:const EdgeInsets.fromLTRB(20,0,20,20),
    actions:[OutlinedButton(style:OutlinedButton.styleFrom(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),onPressed:()=>Navigator.pop(c,false),child:Text(_t(context,'common_cancel'))),
      FilledButton(style:FilledButton.styleFrom(backgroundColor:SpendingStyle.danger,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),onPressed:()=>Navigator.pop(c,true),child:Text(_t(context,'common_confirm')))],
  )) ?? false;
  Future<bool> run(Future<void> Function() action) async {
    setState(() => busy=true);
    loadingAnimation(context);
    var loadingVisible = true;
    var succeeded = false;
    try{await action();succeeded=true;}
    catch(e){if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally{
      if(loadingVisible && mounted) Navigator.of(context,rootNavigator:true).pop();
      if(mounted)setState(() => busy=false);
    }
    return succeeded;
  }
  Future<void> payment(Debt d) async {
    await Navigator.push<bool>(context,MaterialPageRoute(builder:(_) => DebtPaymentEditor(debt:d,service:widget.service)));
  }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:SpendingStyle.background(context),appBar:AppBar(backgroundColor:SpendingStyle.background(context),title:Text(_t(context,'debt_detail'))),
      body:StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:stream,builder:(context,s){
        if(s.hasError)return Center(child:Text(_t(context,'debt_detail_load_error')+': '+s.error.toString()));
        if(!s.hasData)return _debtScreenSkeleton(context);
        if(!s.data!.exists)return Center(child:Text(_t(context,'debt_deleted')));
        final d=Debt.fromDoc(s.data!);
        return AbsorbPointer(absorbing:busy,child:ListView(padding:const EdgeInsets.all(16),children:[
          Container(padding:const EdgeInsets.all(20),decoration:SpendingStyle.decoration(context,hero:true),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[DebtCategoryIcon(id:DebtCategoryPresentation.id(d.direction)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(d.contactName,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),Text(DebtCategoryPresentation.title(context,DebtCategoryPresentation.id(d.direction)))]))]),const SizedBox(height:12),
            Text((d.direction=='lend' ? _t(context,'debt_to_collect') : _t(context,'debt_to_pay'))+': '+debtMoney(d.remaining),style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
            const SizedBox(height:10),Text(_t(context,'debt_original')+': ${debtMoney(d.amount)}\n'+_t(context,'debt_paid')+': ${debtMoney(d.paid)}\n'+_t(context,'debt_date')+': ${debtDate(d.date)}\n'+_t(context,'debt_due_date')+': ${d.dueDate==null ? _t(context,'debt_due_not_set') : debtDate(d.dueDate!)}\n'+debtStatus(context,d)),
            const SizedBox(height:10),Text(d.walletTracked ? _t(context,'debt_wallet_linked') : _t(context,'debt_wallet_not_linked')),
            const SizedBox(height:12),LinearProgressIndicator(value:d.paid/d.amount,color:SpendingStyle.accent(context)),if(d.note.isNotEmpty) Padding(padding:const EdgeInsets.only(top:12),child:Text(d.note)),
          ])),const SizedBox(height:16),
          if(d.remaining>0) SpendingActionButton(label:DebtCategoryPresentation.title(context,DebtCategoryPresentation.paymentId(d.direction)),icon:Icons.payments_outlined,onPressed:busy ? null : () => payment(d)),
          DebtDetailActions(onEdit:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>DebtEditor(service:widget.service,debt:d))),onDelete:() async {
            if(await confirm(_t(context,'debt_delete_confirm'))) {
              final deleted = await run(() => widget.service.deleteDebt(d));
              if(deleted && mounted) Navigator.pop(context);
            }
          }),
          Text(_t(context,'debt_payment_history'),style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
          if(d.payments.isEmpty) Padding(padding:const EdgeInsets.all(20),child:Text(_t(context,'debt_no_payments'))),
          for(final p in d.payments.reversed) Container(margin:const EdgeInsets.only(top:10),decoration:SpendingStyle.decoration(context),child:Material(color:Colors.transparent,borderRadius:BorderRadius.circular(20),clipBehavior:Clip.antiAlias,child:ListTile(leading:DebtCategoryIcon(id:DebtCategoryPresentation.paymentId(d.direction)),title:Text(debtMoney(p.amount)),subtitle:Text('${debtDate(p.date)}${p.note.isEmpty ? '' : '\n${p.note}'}'),trailing:IconButton(tooltip:_t(context,'debt_undo_payment'),icon:const Icon(Icons.undo),onPressed:() async {if(await confirm(_t(context,'debt_undo_confirm'))) await run(() => widget.service.removePayment(d.id,p.id));})))),
        ]));
      }));
}

class DebtPaymentEditor extends StatefulWidget {
  final Debt debt; final DebtFirebase service;
  const DebtPaymentEditor({Key? key,required this.debt,required this.service}):super(key:key);
  @override State<DebtPaymentEditor> createState() => _DebtPaymentEditorState();
}
class _DebtPaymentEditorState extends State<DebtPaymentEditor> {
  final amount=TextEditingController(),note=TextEditingController();final form=GlobalKey<FormState>();
  DateTime date=DateTime.now();
  bool saving=false;
  late final String paymentId;
  @override void initState(){super.initState();paymentId=widget.service.items.doc().id;if(date.isBefore(widget.debt.date)) date=widget.debt.date;}
  Future<void> save() async {
    if(saving || !form.currentState!.validate())return;
    setState(() => saving=true);
    loadingAnimation(context);
    var loadingVisible = true;
    try {
      await widget.service.addPayment(widget.debt.id,DebtPayment(id:paymentId,amount:int.parse(amount.text),date:date,note:note.text.trim()));
      if(mounted) {
        Navigator.of(context,rootNavigator:true).pop();
        loadingVisible = false;
        Navigator.pop(context,true);
      }
    } catch(e) {if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally {
      if(loadingVisible && mounted) Navigator.of(context,rootNavigator:true).pop();
      if(mounted)setState(() => saving=false);
    }
  }
  @override void dispose(){amount.dispose();note.dispose();super.dispose();}
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:SpendingStyle.background(context),appBar:AppBar(title:Text(DebtCategoryPresentation.title(context,DebtCategoryPresentation.paymentId(widget.debt.direction))),backgroundColor:SpendingStyle.background(context)),body:Form(key:form,child:ListView(padding:const EdgeInsets.all(16),children:[
    Center(child:DebtCategoryIcon(id:DebtCategoryPresentation.paymentId(widget.debt.direction),size:64)),const SizedBox(height:12),
    Text(_t(context,'debt_remaining')+': ${debtMoney(widget.debt.remaining)}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:20),
    TextFormField(controller:amount,inputFormatters:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(12)],keyboardType:TextInputType.number,decoration:SpendingStyle.input(context,_t(context,'debt_payment_amount')),validator:(v){final n=int.tryParse(v ?? '') ?? 0;return n<=0 || n>widget.debt.remaining ? _t(context,'debt_payment_range_error')+' '+debtMoney(widget.debt.remaining) : null;}),
    Align(
      alignment:Alignment.centerLeft,
      child:OutlinedButton.icon(
        onPressed:saving ? null : () => setState(() => amount.text=widget.debt.remaining.toString()),
        icon:const Icon(Icons.done_all_rounded,size:18),
        label:Text(_t(context,'debt_pay_all')),
        style:OutlinedButton.styleFrom(
          side:BorderSide(color:SpendingStyle.accent(context).withOpacity(.65)),
          foregroundColor:SpendingStyle.accent(context),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
        ),
      ),
    ),
    ListTile(title:Text(_t(context,'debt_payment_date')),subtitle:Text(debtDate(date)),onTap:() async {final d=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(widget.debt.date.year,widget.debt.date.month,widget.debt.date.day),lastDate:DateTime(2100));if(d!=null && mounted)setState(() => date=d);}),
    TextFormField(controller:note,maxLength:500,decoration:SpendingStyle.input(context,_t(context,'debt_note'))),const SizedBox(height:20),
    SpendingActionButton(label:_t(context,'debt_confirm_payment'),onPressed:saving ? null : save),
  ])));
}

class DebtContactsScreen extends StatelessWidget {
  final DebtFirebase service;
  const DebtContactsScreen({Key? key,required this.service}):super(key:key);
  Future<void> edit(BuildContext context,DebtContact? old) async {
    await Navigator.push(context,MaterialPageRoute(builder:(_) => DebtContactEditor(service:service,contact:old)));
  }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:SpendingStyle.background(context),appBar:AppBar(title:Text(_t(context,'debt_contacts_title')),backgroundColor:SpendingStyle.background(context),actions:[IconButton(tooltip:_t(context,'debt_picker_add'),icon:const Icon(Icons.person_add_alt_1_rounded),onPressed:() => edit(context,null))]),body:StreamBuilder<List<DebtContact>>(stream:service.watchContacts(),builder:(context,s){
    if(s.hasError)return Center(child:Text(_t(context,'debt_contacts_load_error')+': '+s.error.toString()));
    if(!s.hasData)return _debtScreenSkeleton(context);
    if(s.data!.isEmpty)return Center(child:Text(_t(context,'debt_contact_empty')));
    return ListView(padding:const EdgeInsets.fromLTRB(16,12,16,100),children:[for(final c in s.data!) Container(margin:const EdgeInsets.only(bottom:12),decoration:SpendingStyle.decoration(context),child:Material(color:Colors.transparent,borderRadius:BorderRadius.circular(20),clipBehavior:Clip.antiAlias,child:ListTile(leading:CircleAvatar(backgroundColor:SpendingStyle.teal.withOpacity(.14),child:Icon(Icons.person_outline_rounded,color:SpendingStyle.accent(context))),title:Text(c.name,style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Text('${roleName(context,c.role)}${c.phone.isEmpty ? '' : ' · ${c.phone}'}${c.note.isEmpty ? '' : '\n${c.note}'}'),isThreeLine:c.note.isNotEmpty,onTap:() => edit(context,c),trailing:IconButton(tooltip:_t(context,'common_delete'),icon:const Icon(Icons.delete_outline),onPressed:() async {
      final yes=await showDialog<bool>(context:context,builder:(ctx) => AlertDialog(title:Text(_t(context,'debt_contact_delete_title')),content:Text(c.name),actions:[TextButton(onPressed:() => Navigator.pop(ctx,false),child:Text(_t(context,'common_cancel'))),TextButton(onPressed:() => Navigator.pop(ctx,true),child:Text(_t(context,'common_delete')))]));
      if(yes!=true)return;
      loadingAnimation(context);
      var loadingVisible = true;
      try {
        await service.deleteContact(c.id);
      } catch(e) {
        if(loadingVisible) {
          Navigator.of(context,rootNavigator:true).pop();
          loadingVisible = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));
      } finally {
        if(loadingVisible) Navigator.of(context,rootNavigator:true).pop();
      }
    })))) ]);
  }));
}
String roleName(BuildContext context, String role) => _t(context, {'person':'debt_role_person','customer':'debt_role_customer','supplier':'debt_role_supplier','lender':'debt_role_lender','borrower':'debt_role_borrower'}[role] ?? 'debt_role_person');
class DebtContactEditor extends StatefulWidget {
  final DebtFirebase service; final DebtContact? contact;
  const DebtContactEditor({Key? key,required this.service,this.contact}):super(key:key);
  @override State<DebtContactEditor> createState() => _DebtContactEditorState();
}
class _DebtContactEditorState extends State<DebtContactEditor> {
  final name=TextEditingController(),phone=TextEditingController(),note=TextEditingController();final form=GlobalKey<FormState>();String role='person';bool busy=false;
  @override void initState(){super.initState();name.text=widget.contact?.name ?? '';phone.text=widget.contact?.phone ?? '';note.text=widget.contact?.note ?? '';role=widget.contact?.role ?? 'person';}
  @override void dispose(){name.dispose();phone.dispose();note.dispose();super.dispose();}
  Future<void> save() async {
    if(!form.currentState!.validate())return;
    setState(() => busy=true);
    loadingAnimation(context);
    var loadingVisible = true;
    try{
      await widget.service.saveContact(DebtContact(id:widget.contact?.id ?? '',name:name.text.trim(),phone:phone.text.trim(),role:role,note:note.text.trim()));
      if(mounted) {
        Navigator.of(context,rootNavigator:true).pop();
        loadingVisible = false;
        Navigator.pop(context);
      }
    }
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally{
      if(loadingVisible && mounted) Navigator.of(context,rootNavigator:true).pop();
      if(mounted)setState(() => busy=false);
    }
  }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:SpendingStyle.background(context),appBar:AppBar(title:Text(widget.contact==null ? _t(context,'debt_contact_add') : _t(context,'debt_contact_edit')),backgroundColor:SpendingStyle.background(context)),body:AbsorbPointer(absorbing:busy,child:Form(key:form,child:ListView(padding:const EdgeInsets.all(16),children:[
    TextFormField(controller:name,maxLength:100,decoration:SpendingStyle.input(context,_t(context,'debt_contact_name'),icon:Icons.person_outline),validator:(v) => v==null || v.trim().isEmpty ? _t(context,'debt_contact_name_required') : null),const SizedBox(height:12),
    DebtPhoneField(controller:phone),const SizedBox(height:12),
    DropdownButtonFormField<String>(value:role,decoration:SpendingStyle.input(context,_t(context,'debt_contact_role')),items:['person','customer','supplier','lender','borrower'].map((r) => DropdownMenuItem(value:r,child:Text(roleName(context,r)))).toList(),onChanged:(v) => setState(() => role=v!)),const SizedBox(height:12),
    TextFormField(controller:note,maxLength:500,maxLines:3,decoration:SpendingStyle.input(context,_t(context,'debt_note'))),const SizedBox(height:20),SpendingActionButton(label:_t(context,'debt_contact_save'),onPressed:busy ? null : save),
  ])))) ;
}
