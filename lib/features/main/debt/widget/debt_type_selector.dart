import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/debt/debt_style.dart';
import 'debt_category_icon.dart';
import 'debt_category_presentation.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class DebtTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String>? onChanged;

  const DebtTypeSelector({Key? key, required this.value, this.onChanged})
    : super(key: key);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        AppLocalizations.of(context).translate('debt_type'),
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final direction in ['lend', 'borrow'])
              SizedBox(
                width: box.maxWidth < 320
                    ? box.maxWidth
                    : (box.maxWidth - 10) / 2,
                child: Material(
                  color: value == direction
                      ? DebtStyle.teal.withOpacity(.12)
                      : DebtStyle.background(context),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(direction),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: value == direction
                              ? DebtStyle.accent(context)
                              : DebtStyle.teal.withOpacity(.16),
                        ),
                      ),
                      child: Row(
                        children: [
                          DebtCategoryIcon(
                            id: DebtCategoryPresentation.id(direction),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DebtCategoryPresentation.title(
                                context,
                                DebtCategoryPresentation.id(direction),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (value == direction)
                            Icon(
                              Icons.check_circle,
                              color: DebtStyle.accent(context),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
