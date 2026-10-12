import 'debt_phone_field.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

String _ct(BuildContext context, String key) => AppLocalizations.of(context).translate(key);
String _contactRoleName(BuildContext context, String role) => _ct(context, {'person':'debt_role_person','customer':'debt_role_customer','supplier':'debt_role_supplier','lender':'debt_role_lender','borrower':'debt_role_borrower'}[role] ?? 'debt_role_person');

class DebtContactSelectField extends StatelessWidget {
  final DebtFirebase service;
  final DebtContact? selected;
  final bool enabled;
  final ValueChanged<DebtContact> onChanged;
  const DebtContactSelectField({Key? key,required this.service,this.selected,required this.enabled,required this.onChanged}):super(key:key);
  @override Widget build(BuildContext context)=>FormField<String>(
    key:ValueKey(selected?.id),initialValue:selected?.id,
    validator:(v)=>v==null || v.isEmpty ? _ct(context,'debt_contact_required') : null,
    builder:(field)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(_ct(context,'debt_contact'),style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:8),
      Material(color:SpendingStyle.background(context),borderRadius:BorderRadius.circular(16),clipBehavior:Clip.antiAlias,child:InkWell(onTap:!enabled ? null : () async {
        FocusScope.of(context).unfocus();
        final contact=await showModalBottomSheet<DebtContact>(context:context,isScrollControlled:true,useSafeArea:true,backgroundColor:SpendingStyle.card(context),shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(28))),clipBehavior:Clip.antiAlias,builder:(ctx){
          final media=MediaQuery.of(ctx);
          return Padding(padding:EdgeInsets.only(bottom:media.viewInsets.bottom),child:SizedBox(height:(media.size.height-media.viewInsets.bottom)*.8,child:DebtContactPicker(service:service,selectedId:selected?.id)));
        });
        if(contact==null)return;
        if(!field.mounted)return;
        field.didChange(contact.id);onChanged(contact);
      },child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),border:Border.all(color:field.hasError ? SpendingStyle.danger : SpendingStyle.teal.withOpacity(.2))),child:Row(children:[
        _ContactAvatar(name:selected?.name ?? '',selected:selected!=null),const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(selected?.name ?? _ct(context,'debt_select_or_add_person'),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w600)),const SizedBox(height:3),Text(selected==null ? _ct(context,'debt_name_and_phone') : selected!.phone.isEmpty ? _ct(context,'debt_selected_contact') : selected!.phone,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:12,color:SpendingStyle.muted(context)))])),
        const SizedBox(width:8),Icon(enabled ? Icons.expand_more_rounded : Icons.lock_outline_rounded,color:SpendingStyle.accent(context),size:22),
      ])))),
      if(field.hasError)Padding(padding:const EdgeInsets.only(top:7,left:4),child:Text(field.errorText!,style:const TextStyle(color:SpendingStyle.danger,fontSize:12))),
      if(!enabled)Padding(padding:const EdgeInsets.only(top:7),child:Text(_ct(context,'debt_contact_locked'),style:TextStyle(fontSize:12,color:SpendingStyle.muted(context)))),
      const SizedBox(height:16),
    ]),
  );
}
class _ContactAvatar extends StatelessWidget {
  final String name;final bool selected;
  const _ContactAvatar({required this.name,this.selected=false});
  @override Widget build(BuildContext context)=>Container(width:44,height:44,decoration:BoxDecoration(color:SpendingStyle.teal.withOpacity(.14),borderRadius:BorderRadius.circular(14)),alignment:Alignment.center,child:name.trim().isEmpty ? Icon(Icons.person_add_alt_1_outlined,color:SpendingStyle.accent(context)) : Text(String.fromCharCode(name.trim().runes.first).toUpperCase(),style:TextStyle(fontSize:19,fontWeight:FontWeight.w700,color:SpendingStyle.accent(context))));
}
class DebtContactPicker extends StatefulWidget {
  final DebtFirebase service;final String? selectedId;
  const DebtContactPicker({Key? key,required this.service,this.selectedId}):super(key:key);
  @override State<DebtContactPicker> createState()=>_DebtContactPickerState();
}
class _DebtContactPickerState extends State<DebtContactPicker> {
  late final Stream<List<DebtContact>> stream;
  final search=TextEditingController();bool adding=false;
  @override void initState(){super.initState();stream=widget.service.watchContacts();}
  @override void dispose(){search.dispose();super.dispose();}
  Future<void> add() async {
    if(adding)return;
    FocusScope.of(context).unfocus();setState(()=>adding=true);
    try {
      final contact=await showDialog<DebtContact>(context:context,builder:(_)=>_NewContactDialog(service:widget.service));
      if(contact!=null && mounted)Navigator.pop(context,contact);
    }finally{if(mounted)setState(()=>adding=false);}
  }
  @override Widget build(BuildContext context)=>CustomScrollView(keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,slivers:[SliverToBoxAdapter(child:Column(children:[
    const SizedBox(height:10),Container(width:40,height:4,decoration:BoxDecoration(color:SpendingStyle.muted(context).withOpacity(.25),borderRadius:BorderRadius.circular(4))),
    Padding(padding:const EdgeInsets.fromLTRB(20,16,12,12),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_ct(context,'debt_picker_title'),style:TextStyle(fontSize:21,fontWeight:FontWeight.w700)),const SizedBox(height:4),Text(_ct(context,'debt_picker_subtitle'),style:TextStyle(fontSize:12,color:SpendingStyle.muted(context)))])),IconButton(tooltip:_ct(context,'common_close'),onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))])),
    Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:SpendingStyle.input(context,_ct(context,'debt_picker_search'),icon:Icons.search_rounded),textInputAction:TextInputAction.search)),
    Padding(padding:const EdgeInsets.fromLTRB(20,12,20,12),child:SpendingActionButton(label:_ct(context,'debt_picker_add'),icon:Icons.person_add_alt_1_rounded,onPressed:adding ? null : add)),
  ])),StreamBuilder<List<DebtContact>>(stream:stream,builder:(context,s){
    if(s.hasError)return SliverFillRemaining(hasScrollBody:false,child:Center(child:Padding(padding:const EdgeInsets.all(20),child:Text(_ct(context,'debt_picker_load_error')+': '+s.error.toString(),textAlign:TextAlign.center))));
    if(!s.hasData)return SliverToBoxAdapter(child:Shimmer.fromColors(
      baseColor:SpendingStyle.card(context),
      highlightColor:SpendingStyle.teal.withOpacity(.18),
      child:Padding(padding:const EdgeInsets.fromLTRB(20,4,20,24),child:Column(children:[
        for(var i=0;i<4;i++) ...[
          Container(height:76,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16))),
          const SizedBox(height:10),
        ],
      ])),
    ));
    final keyword=search.text.trim().toLowerCase();
    final list=s.data!.where((c)=>'${c.name} ${c.phone}'.toLowerCase().contains(keyword)).toList();
    if(list.isEmpty)return SliverFillRemaining(hasScrollBody:false,child:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.people_outline_rounded,size:40,color:SpendingStyle.accent(context)),const SizedBox(height:10),Text(keyword.isEmpty ? _ct(context,'debt_picker_empty') : _ct(context,'debt_picker_no_results'),textAlign:TextAlign.center)]))));
    return SliverPadding(padding:const EdgeInsets.fromLTRB(20,0,20,24),sliver:SliverList(delegate:SliverChildBuilderDelegate((context,index){final c=list[index];final selected=c.id==widget.selectedId;
    return Padding(padding:const EdgeInsets.only(bottom:8),child:Material(color:selected ? SpendingStyle.teal.withOpacity(.12) : SpendingStyle.background(context),borderRadius:BorderRadius.circular(16),clipBehavior:Clip.antiAlias,child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:6),leading:_ContactAvatar(name:c.name),title:Text(c.name,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Text(c.phone.isEmpty ? _ct(context,'debt_no_phone') : c.phone,maxLines:1,overflow:TextOverflow.ellipsis),trailing:selected ? Icon(Icons.check_circle_rounded,color:SpendingStyle.accent(context)) : Icon(Icons.chevron_right_rounded,color:SpendingStyle.muted(context)),onTap:()=>Navigator.pop(context,c))));
    },childCount:list.length)));
  }),
  ]);
}
class _NewContactDialog extends StatefulWidget {
  final DebtFirebase service;
  const _NewContactDialog({required this.service});
  @override State<_NewContactDialog> createState()=>_NewContactDialogState();
}
class _NewContactDialogState extends State<_NewContactDialog> {
  final name=TextEditingController(),phone=TextEditingController(),note=TextEditingController();final form=GlobalKey<FormState>();bool saving=false;late final String id;String role='person';
  @override void initState(){super.initState();id=widget.service.contacts.doc().id;}
  @override void dispose(){name.dispose();phone.dispose();note.dispose();super.dispose();}
  Future<void> save() async {
    if(saving || !form.currentState!.validate())return;
    setState(()=>saving=true);
    loadingAnimation(context);
    var loadingVisible = true;
    try{
      final c=DebtContact(id:id,name:name.text.trim(),phone:phone.text.trim(),role:role,note:note.text.trim());
      await widget.service.saveContact(c);
      if(mounted) {
        Navigator.of(context,rootNavigator:true).pop();
        loadingVisible = false;
        Navigator.pop(context,c);
      }
    }
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally{
      if(loadingVisible && mounted) Navigator.of(context,rootNavigator:true).pop();
      if(mounted)setState(()=>saving=false);
    }
  }
  @override Widget build(BuildContext context)=>PopScope(canPop:!saving,child:Dialog(backgroundColor:SpendingStyle.card(context),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),insetPadding:const EdgeInsets.symmetric(horizontal:20,vertical:24),child:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(20),child:Form(key:form,child:AbsorbPointer(absorbing:saving,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text(_ct(context,'debt_contact_new_title'),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w700))),IconButton(onPressed:saving ? null : ()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))]),
    Text(_ct(context,'debt_contact_new_hint'),style:TextStyle(fontSize:13,color:SpendingStyle.muted(context))),const SizedBox(height:14),
    TextFormField(controller:name,maxLength:100,textCapitalization:TextCapitalization.words,textInputAction:TextInputAction.next,decoration:SpendingStyle.input(context,_ct(context,'debt_contact_name'),icon:Icons.person_outline),validator:(v)=>v==null || v.trim().isEmpty ? _ct(context,'debt_contact_name_required') : null),const SizedBox(height:10),
    DebtPhoneField(controller:phone),const SizedBox(height:10),
    DropdownButtonFormField<String>(value:role,decoration:SpendingStyle.input(context,_ct(context,'debt_contact_role'),icon:Icons.badge_outlined),items:['person','customer','supplier','lender','borrower'].map((r)=>DropdownMenuItem(value:r,child:Text(_contactRoleName(context,r)))).toList(),onChanged:saving ? null : (v){if(v!=null)setState(()=>role=v);}),const SizedBox(height:10),
    TextFormField(controller:note,maxLength:500,maxLines:2,textCapitalization:TextCapitalization.sentences,decoration:SpendingStyle.input(context,_ct(context,'debt_contact_note_optional'),icon:Icons.notes_rounded)),const SizedBox(height:16),
    SpendingActionButton(label:_ct(context,'debt_contact_save_and_select'),icon:Icons.check_rounded,onPressed:saving ? null : save),
  ])))))));
}

class DebtDetailActions extends StatelessWidget {
  final VoidCallback onEdit,onDelete;
  const DebtDetailActions({Key? key,required this.onEdit,required this.onDelete}):super(key:key);
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:16),child:LayoutBuilder(builder:(context,box)=>Wrap(spacing:12,runSpacing:10,children:[
    SizedBox(width:box.maxWidth<300 ? box.maxWidth : (box.maxWidth-12)/2,child:_button(context,_ct(context,'debt_edit'),Icons.edit_rounded,SpendingStyle.accent(context),onEdit)),
    SizedBox(width:box.maxWidth<300 ? box.maxWidth : (box.maxWidth-12)/2,child:_button(context,_ct(context,'debt_delete'),Icons.delete_outline_rounded,SpendingStyle.danger,onDelete)),
  ])));
  Widget _button(BuildContext context,String text,IconData icon,Color color,VoidCallback action)=>Material(color:color.withOpacity(.08),borderRadius:BorderRadius.circular(16),clipBehavior:Clip.antiAlias,child:InkWell(onTap:action,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:15),decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),border:Border.all(color:color.withOpacity(.22))),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:color,size:21),const SizedBox(width:8),Flexible(child:Text(text,textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.w600,color:color)))]))));
}
