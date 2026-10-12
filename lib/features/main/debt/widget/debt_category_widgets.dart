import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import '../../../../core/constants/list.dart';

class DebtCategoryPresentation {
  static String id(String direction) => direction=='borrow' ? 'borrow' : 'loan';
  static String paymentId(String direction) => direction=='borrow' ? 'pay' : 'debt_collection';
  static Map<String,String> item(String id) => listType.firstWhere((e)=>e['id']==id,orElse:()=>{'id':id,'title':id});
  static String title(BuildContext context,String id) {
    final key=item(id)['title'] ?? id;
    final translated=AppLocalizations.of(context).translate(key);
    if(translated.isNotEmpty && translated!=key)return translated;
    final english=Localizations.localeOf(context).languageCode=='en';
    return (english ? {'loan':'Lend','borrow':'Borrow','pay':'Repay debt','debt_collection':'Collect debt','pay_interest':'Interest payment'} : {'loan':'Cho vay','borrow':'Đi vay','pay':'Trả nợ','debt_collection':'Thu nợ','pay_interest':'Trả lãi'})[id] ?? key;
  }
}
class DebtCategoryIcon extends StatelessWidget {
  final String id;final double size;
  const DebtCategoryIcon({Key? key,required this.id,this.size=42}):super(key:key);
  @override Widget build(BuildContext context){
    final path=DebtCategoryPresentation.item(id)['image'];
    return Container(width:size,height:size,padding:EdgeInsets.all(size*.18),decoration:BoxDecoration(color:SpendingStyle.teal.withOpacity(.1),borderRadius:BorderRadius.circular(14)),child:path==null ? Icon(Icons.menu_book_outlined,color:SpendingStyle.accent(context)) : Image.asset(path,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(Icons.menu_book_outlined,color:SpendingStyle.accent(context))));
  }
}
class DebtTypeSelector extends StatelessWidget {
  final String value;final ValueChanged<String>? onChanged;
  const DebtTypeSelector({Key? key,required this.value,this.onChanged}):super(key:key);
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(AppLocalizations.of(context).translate('debt_type'),style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:10),
    LayoutBuilder(builder:(context,box)=>Wrap(spacing:10,runSpacing:10,children:[for(final direction in ['lend','borrow']) SizedBox(width:box.maxWidth<320 ? box.maxWidth : (box.maxWidth-10)/2,child:Material(color:value==direction ? SpendingStyle.teal.withOpacity(.12) : SpendingStyle.background(context),borderRadius:BorderRadius.circular(16),child:InkWell(borderRadius:BorderRadius.circular(16),onTap:onChanged==null ? null : ()=>onChanged!(direction),child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),border:Border.all(color:value==direction ? SpendingStyle.accent(context) : SpendingStyle.teal.withOpacity(.16))),child:Row(children:[DebtCategoryIcon(id:DebtCategoryPresentation.id(direction)),const SizedBox(width:8),Expanded(child:Text(DebtCategoryPresentation.title(context,DebtCategoryPresentation.id(direction)),style:const TextStyle(fontWeight:FontWeight.w600))),if(value==direction)Icon(Icons.check_circle,color:SpendingStyle.accent(context),size:20)])))))])),
  ]);
}
