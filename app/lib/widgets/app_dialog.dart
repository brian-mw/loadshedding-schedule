import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// [showShadDialog] with a side margin. shadcn_ui lets a dialog run edge to
/// edge on phone-width screens and has no margin setting, so the dialog is
/// inset here instead.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showShadDialog<T>(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: builder(context),
    ),
  );
}
