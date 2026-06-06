import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../screens/ekassa_qr_screen.dart';
import '../screens/fiscal_id_screen.dart';
import '../screens/manual_entry_screen.dart';
import '../screens/receipt_capture_screen.dart';
import '../config/app_colors.dart';

/// Opens the add-receipt bottom sheet (photo, QR, fiscal ID, manual).
void showAddReceiptSheet(BuildContext context, {VoidCallback? onDone}) {
  final lang = currentLanguage.value;
  final cs = Theme.of(context).colorScheme;
  showModalBottomSheet(
    context: context,
    backgroundColor: cs.surfaceContainerHighest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.get('add_receipt', lang),
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: Colors.transparent,
              leading: Icon(Icons.document_scanner_outlined,
                  color: AppColors.primaryGreen(Theme.of(ctx).brightness)),
              title: Text(
                '📷  ${AppStrings.get('scan_receipt', lang)}',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const ReceiptCaptureScreen()))
                    .then((_) => onDone?.call());
              },
            ),
            ListTile(
              tileColor: Colors.transparent,
              leading: Icon(Icons.qr_code_scanner,
                  color: AppColors.primaryGreen(Theme.of(ctx).brightness)),
              title: Text(
                '📱  ${AppStrings.get('scan_qr_code', lang)}',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const EkassaQrScreen()))
                    .then((_) => onDone?.call());
              },
            ),
            ListTile(
              tileColor: Colors.transparent,
              leading: Icon(Icons.numbers_outlined,
                  color: AppColors.primaryGreen(Theme.of(ctx).brightness)),
              title: Text(
                '🔢  ${AppStrings.get('enter_fiscal_id', lang)}',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const FiscalIdScreen()))
                    .then((_) => onDone?.call());
              },
            ),
            ListTile(
              tileColor: Colors.transparent,
              leading: Icon(Icons.edit_note_outlined,
                  color: AppColors.primaryGreen(Theme.of(ctx).brightness)),
              title: Text(
                '✏️  ${AppStrings.get('manual_entry', lang)}',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const ManualEntryScreen()))
                    .then((_) => onDone?.call());
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    ),
  );
}
