import 'package:flutter/material.dart';

class AppLayoutBody extends StatelessWidget {
  static const double maxContentWidth = 900;

  final Widget child;

  const AppLayoutBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final gutterColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxContentWidth) return child;
        return Row(
          children: [
            Expanded(child: ColoredBox(color: gutterColor)),
            SizedBox(width: maxContentWidth, child: child),
            Expanded(child: ColoredBox(color: gutterColor)),
          ],
        );
      },
    );
  }
}
