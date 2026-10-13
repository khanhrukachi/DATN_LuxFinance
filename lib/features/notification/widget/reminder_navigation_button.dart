import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';

class ReminderNavigationButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;
  const ReminderNavigationButton({required this.title,required this.subtitle,required this.enabled,required this.onTap});

  @override
  Widget build(BuildContext context)=>Opacity(
    opacity:enabled ? 1 : .55,
    child:Material(
      color:Colors.transparent,
      elevation:2,
      shadowColor:SpendingStyle.accent(context).withOpacity(.24),
      borderRadius:BorderRadius.circular(18),
      clipBehavior:Clip.antiAlias,
      child:InkWell(
        onTap:onTap,
        child:Ink(
          decoration:BoxDecoration(
            gradient:SpendingStyle.gradient,
            border:Border.all(color:SpendingStyle.ink,width:2),
            borderRadius:BorderRadius.circular(18),
          ),
          child:Padding(
            padding:const EdgeInsets.symmetric(horizontal:14,vertical:13),
            child:Row(children:[
              Container(
                width:48,height:48,
                decoration:BoxDecoration(
                  color:Colors.white.withOpacity(.48),
                  borderRadius:BorderRadius.circular(16),
                ),
                child:const Icon(Icons.menu_book_rounded,color:SpendingStyle.ink,size:25),
              ),
              const SizedBox(width:12),
              Expanded(child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:15,color:SpendingStyle.ink)),
                  const SizedBox(height:4),
                  Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:12,color:SpendingStyle.ink.withOpacity(.78))),
                ],
              )),
              const SizedBox(width:8),
              Container(
                width:32,height:32,
                decoration:BoxDecoration(color:Colors.white.withOpacity(.42),shape:BoxShape.circle),
                child:const Icon(Icons.arrow_forward_rounded,size:18,color:SpendingStyle.ink),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
}
