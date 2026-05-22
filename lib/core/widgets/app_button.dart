import 'package:flutter/material.dart';
import 'package:football/core/theme/app_theme.dart';

class AppButton extends StatefulWidget {
  final String text;
  final Future<void> Function()? onPressed;
  final Color? color;
  final bool outlined;
  final IconData? icon;
  final double? width;
  final EdgeInsets? padding;
  final bool enabled;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.outlined = false,
    this.icon,
    this.width,
    this.padding,
    this.enabled = true,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading || widget.onPressed == null) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.green;
    final isDisabled = _loading || widget.onPressed == null || !widget.enabled;

    final child = _loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.outlined ? color : Colors.white,
            ),
          )
        : widget.icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.text,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              )
            : Text(
                widget.text,
                style: const TextStyle(fontWeight: FontWeight.w900),
              );

    final buttonPadding = widget.padding ??
        const EdgeInsets.symmetric(vertical: 16, horizontal: 24);

    if (widget.outlined) {
      return SizedBox(
        width: widget.width ?? double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: isDisabled ? color.withAlpha(77) : color),
            padding: buttonPadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: isDisabled ? null : _handleTap,
          child: child,
        ),
      );
    }

    return SizedBox(
      width: widget.width ?? double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          disabledBackgroundColor: color.withAlpha(128),
          disabledForegroundColor: Colors.white.withAlpha(180),
        ),
        onPressed: isDisabled ? null : _handleTap,
        child: child,
      ),
    );
  }
}
