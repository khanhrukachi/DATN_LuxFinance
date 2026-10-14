import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';

class ViewImage extends StatefulWidget {
  const ViewImage({super.key, required this.url});
  final String url;

  @override
  State<ViewImage> createState() => _ViewImageImageState();
}

class _ViewImageImageState extends State<ViewImage> {
  final controller = TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool check = true;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _zoom() {
    if (controller.value.getMaxScaleOnAxis() > 1.01) {
      controller.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;
    controller.value = Matrix4.identity()
      ..translate(-position.dx * 2, -position.dy * 2)
      ..scale(3.0);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SpendingStyle.background(context),
    body: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onTap: () => setState(() => check = !check),
                onDoubleTap: _zoom,
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                child: InteractiveViewer(
                  transformationController: controller,
                  minScale: 1,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: widget.url,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => Center(
                      child: Shimmer.fromColors(
                        baseColor: SpendingStyle.card(context),
                        highlightColor: SpendingStyle.teal.withOpacity(.16),
                        child: Container(
                          width: constraints.maxWidth - 32,
                          height: 240,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: SpendingStyle.muted(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: IgnorePointer(
              ignoring: !check,
              child: AnimatedOpacity(
                opacity: check ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _control(
                      Icons.arrow_back_rounded,
                          () => Navigator.pop(context),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                    ),
                    _control(
                      Icons.zoom_out_map_rounded,
                          () => controller.value = Matrix4.identity(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _control(IconData icon, VoidCallback action, {String? tooltip}) =>
      FinanceToolbarButton(
        icon: icon,
        onPressed: action,
        tooltip: tooltip ?? (Localizations.localeOf(context).languageCode == 'en'
            ? 'Reset zoom' : 'Đặt lại thu phóng'),
        color: SpendingStyle.accent(context),
        surfaceColor: SpendingStyle.card(context).withOpacity(.94),
      );
}
