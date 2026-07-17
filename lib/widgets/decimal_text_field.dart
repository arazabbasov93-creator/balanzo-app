import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Decimal numeric field with digit/dot filter and keyboard Done action.
class DecimalTextField extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration? decoration;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onDone;

  const DecimalTextField({
    super.key,
    required this.controller,
    this.decoration,
    this.style,
    this.onChanged,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: decoration,
      style: style,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      onSubmitted: (_) {
        FocusScope.of(context).unfocus();
        onDone?.call();
      },
    );
  }
}

void unfocusKeyboard(BuildContext context) => FocusScope.of(context).unfocus();
