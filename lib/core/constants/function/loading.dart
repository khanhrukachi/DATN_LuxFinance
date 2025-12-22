import 'package:flutter/material.dart';
import 'loading_animation.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    Key? key,
    required this.isLoading,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,

        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(1), // 👈 nền đen mờ
              alignment: Alignment.center,
              child: RotationAnimationWidget(),
            ),
          ),
      ],
    );
  }
}
