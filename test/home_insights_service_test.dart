import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/services/home_insights_service.dart';

void main() {
  group('resolveAnalysisPeriod', () {
    test('uses current month when receipts exist there', () {
      final asOf = DateTime(2026, 6, 2);
      final rows = [
        {'purchase_date': '2026-06-01'},
        {'purchase_date': '2026-05-29'},
      ];
      final p = HomeInsightsService.resolveAnalysisPeriod(rows, asOf);
      expect(p.month, 6);
      expect(p.year, 2026);
      expect(p.fallback, isFalse);
    });

    test('falls back to latest month with receipts', () {
      final asOf = DateTime(2026, 6, 2);
      final rows = [
        {'purchase_date': '2026-05-29'},
        {'purchase_date': '2026-05-15'},
        {'purchase_date': '2026-04-10'},
      ];
      final p = HomeInsightsService.resolveAnalysisPeriod(rows, asOf);
      expect(p.month, 5);
      expect(p.year, 2026);
      expect(p.fallback, isTrue);
    });

    test('defaults to asOf month when no receipts', () {
      final asOf = DateTime(2026, 6, 2);
      final p = HomeInsightsService.resolveAnalysisPeriod([], asOf);
      expect(p.month, 6);
      expect(p.year, 2026);
      expect(p.fallback, isFalse);
    });
  });
}
