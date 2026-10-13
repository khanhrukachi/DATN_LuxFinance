import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_category_widgets.dart';
import '../utils/reminder_helpers.dart';

class DebtReminderCard extends StatelessWidget {
  final Debt debt;
  final bool busy;
  final ValueChanged<bool> onChanged;
  const DebtReminderCard({super.key,required this.debt,required this.busy,required this.onChanged});
  @override Widget build(BuildContext context) {
    final d=debt;
    final enabled=d.remind && d.dueDate!=null;
    final isBusy=busy;
    return Container(
      margin:const EdgeInsets.only(top:12),
      decoration:SpendingStyle.decoration(context),
      child:Material(
        color:Colors.transparent,
        borderRadius:BorderRadius.circular(20),
        clipBehavior:Clip.antiAlias,
        child:Padding(
          padding:const EdgeInsets.fromLTRB(14,14,8,14),
          child:Row(children:[
            Container(
              width:48,height:48,
              decoration:BoxDecoration(
                color:SpendingStyle.teal.withOpacity(.13),
                borderRadius:BorderRadius.circular(16),
              ),
              child:Center(child:DebtCategoryIcon(id:DebtCategoryPresentation.id(d.direction))),
            ),
            const SizedBox(width:12),
            Expanded(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text(d.contactName,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:15)),
                const SizedBox(height:4),
                Text(DebtCategoryPresentation.title(context,DebtCategoryPresentation.id(d.direction)),style:TextStyle(fontSize:12,color:SpendingStyle.muted(context))),
                const SizedBox(height:5),
                Row(children:[
                  Icon(d.dueDate==null ? Icons.event_busy_outlined : Icons.event_available_outlined,size:15,color:d.dueDate==null ? SpendingStyle.warning : SpendingStyle.accent(context)),
                  const SizedBox(width:5),
                  Expanded(child:Text(d.dueDate==null ? reminderText(context,'due_date_missing') : '${reminderText(context,'due_date_prefix')} ${DateFormat('dd/MM/yyyy').format(d.dueDate!)}',maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:12,color:SpendingStyle.muted(context)))),
                ]),
                const SizedBox(height:8),
                Container(
                  padding:const EdgeInsets.symmetric(horizontal:9,vertical:4),
                  decoration:BoxDecoration(
                    color:(enabled ? SpendingStyle.accent(context) : SpendingStyle.muted(context)).withOpacity(.10),
                    borderRadius:BorderRadius.circular(20),
                  ),
                  child:Text(reminderText(context,enabled ? 'enabled' : 'disabled'),style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:enabled ? SpendingStyle.accent(context) : SpendingStyle.muted(context))),
                ),
              ],
            )),
            const SizedBox(width:4),
            Switch.adaptive(
              value:enabled,
              onChanged:isBusy || d.dueDate==null ? null : onChanged,
              activeTrackColor:SpendingStyle.teal,
              activeThumbColor:Colors.white,
              inactiveTrackColor:SpendingStyle.muted(context).withOpacity(.25),
              inactiveThumbColor:SpendingStyle.card(context),
            ),
          ]),
        ),
      ),
    );
  }
}
