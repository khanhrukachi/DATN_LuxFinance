import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/profile/widget/profile_style.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/models/user.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:shimmer/shimmer.dart';

class InfoWidget extends StatelessWidget {
  const InfoWidget({Key? key, this.user}) : super(key: key);
  final User? user;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8), padding: const EdgeInsets.all(22),
      decoration: ProfileStyle.decoration(context),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(gradient: ProfileStyle.gradient, shape: BoxShape.circle),
            child: ClipOval(child: SizedBox(width: 88, height: 88,
                child: user == null ? loadingInfo(width: 88, height: 88, radius: 44)
                    : CachedNetworkImage(imageUrl: user!.avatar, fit: BoxFit.cover,
                    placeholder: (_, __) => loadingInfo(width: 88, height: 88, radius: 44),
                    errorWidget: (_, __, ___) => ColoredBox(color: ProfileStyle.background(context),
                        child: Icon(Icons.person_outline_rounded, size: 38, color: ProfileStyle.accent(context))))))),
        const SizedBox(height: 14),
        if (user == null) loadingInfo(width: 140, height: 20)
        else Text(user!.name, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ProfileStyle.text(context))),
        const SizedBox(height: 16),
        Container(width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ProfileStyle.background(context), borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ProfileStyle.teal.withOpacity(.16))),
            child: Row(children: [Icon(Icons.account_balance_wallet_outlined, color: ProfileStyle.accent(context)),
              const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppLocalizations.of(context).translate('total_assets'),
                    style: TextStyle(fontSize: 12, color: ProfileStyle.muted(context))),
                const SizedBox(height: 5),
                if (user == null) loadingInfo(width: 120, height: 22)
                else Text(NumberFormat.currency(locale: Localizations.localeOf(context).languageCode == 'vi' ? 'vi_VN' : 'en_US',
                    symbol: '₫', decimalDigits: 0).format(user!.money),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ProfileStyle.accent(context))),
              ]))])),
      ]));
  Widget loadingInfo({required double width, required double height, double radius = 5}) =>
      Builder(builder: (context) => Shimmer.fromColors(baseColor: ProfileStyle.background(context),
          highlightColor: ProfileStyle.teal.withOpacity(.18),
          child: Container(width: width, height: height, decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(radius)))));
}
