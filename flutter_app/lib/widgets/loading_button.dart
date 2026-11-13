import 'package:flutter/material.dart';

/// FilledButton / OutlinedButton dengan state loading (otomatis disabled).
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final cb = loading ? null : onPressed;
    final child = loading
        ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
        : Text(label);
    if (outlined) {
      return icon == null || loading
          ? OutlinedButton(onPressed: cb, child: child)
          : OutlinedButton.icon(onPressed: cb, icon: icon, label: child);
    }
    return icon == null || loading
        ? FilledButton(onPressed: cb, child: child)
        : FilledButton.icon(onPressed: cb, icon: icon, label: child);
  }
}
