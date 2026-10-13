import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:shimmer/shimmer.dart';

Widget reminderLoadingSkeleton(BuildContext context)=>Shimmer.fromColors(
  baseColor:SpendingStyle.card(context),
  highlightColor:SpendingStyle.teal.withOpacity(.2),
  child:ListView(padding:const EdgeInsets.fromLTRB(16,12,16,100),children:[
    Container(height:170,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(24))),
    const SizedBox(height:14),
    for(var i=0;i<4;i++) ...[
      Container(height:78,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20))),
      const SizedBox(height:12),
    ],
  ]),
);
