import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tap-to-copy row for an e-kassa fiscal document ID.
class CopyableFiscalIdRow extends StatelessWidget {
  final String fiscalId;
  final bool compact;

  const CopyableFiscalIdRow({
    super.key,
    required this.fiscalId,
    this.compact = false,
  });

  static const _green = Color(0xFF1B5E20);
  static const _greenDark = Color(0xFF0D2818);
  static const _bg = Color(0xFFDCEEDC);

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: fiscalId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fiscal ID copied'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: compact ? 10 : 11,
      fontWeight: FontWeight.w700,
      color: _green,
      letterSpacing: 0.8,
    );
    const idStyle = TextStyle(
      fontSize: 13,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      color: _greenDark,
    );

    return Material(
      color: _bg,
      borderRadius: BorderRadius.circular(compact ? 10 : 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        onTap: () => _copy(context),
        onLongPress: () => _copy(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_outlined,
                size: compact ? 16 : 18,
                color: _green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FISCAL ID', style: labelStyle),
                    const SizedBox(height: 2),
                    SelectableText(
                      fiscalId,
                      style: idStyle.copyWith(fontSize: compact ? 12 : 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.copy_outlined, size: 18, color: _green),
            ],
          ),
        ),
      ),
    );
  }
}
