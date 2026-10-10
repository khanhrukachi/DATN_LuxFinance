import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/core/constants/function/pick_function.dart';
import 'package:image_picker/image_picker.dart';
Widget pickImageWidget({required Function(XFile? file) image}) => Builder(builder: (context) => Padding(
  padding: const EdgeInsets.all(12),
  child: Row(children: [
    for (final gallery in [true, false]) ...[
      if (!gallery) const SizedBox(width: 12),
      Expanded(child: Material(color: SpendingStyle.teal.withOpacity(.08),
          borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: () async { final file = await pickImage(gallery); image(file); },
            child: SizedBox(height: 76, child: Icon(gallery ? Icons.add_photo_alternate_outlined
                : Icons.camera_alt_outlined, size: 30, color: SpendingStyle.accent(context))),
          )),
      ),
    ],
  ]),
));
