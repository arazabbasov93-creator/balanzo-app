import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/services/ocr_service.dart';
import 'package:balanzo/services/structured_receipt_parser.dart';

void main() {
  group('OcrService e-kassa preprocess', () {
    /// Simulates ML Kit column-order output for fiscal ID 7p4vW1ybWF2a.
    const columnOrderOcr = '''
Obyektin adı: QARIŞIQ MALLAR MAĞAZASI
AZ1052 BAKI ŞƏHƏRİ NƏRİMANOV RAYONU TƏBRİZ ev.106 A
VÖEN: 1502989081
Satış çeki № 270978
Tarix: 30.05.2026
Vaxt: 15:41:52
Dəst (ANTHRACITE, 5y ,) (86 ədəd) 84693106267
*ƏDV 18%
Poşet S ()
*ƏDV 18%
Məhsulun adı Say Qiymət Cəmi
1 19.99 19.99
1 0.10 0.10
Cəmi 20.09
ƏDV 18% 3.06
Nağd 20.09
Ödənilib nağd 100.10
Qalıq qaytarılıb nağd 80.01
Fiskal İD: 7p4vW1ybWF2a
''';

    test('parses column-order Azeri e-kassa receipt', () {
      final structured = OcrService.preprocessEkassaText(columnOrderOcr);
      expect(structured, contains('STORE: QARIŞIQ MALLAR MAĞAZASI'));
      expect(structured, contains('TOTAL: 20.09'));
      expect(structured, contains('ITEM:'));

      final receipt = StructuredReceiptParser.tryParse(structured);
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 2);
      expect(receipt.total, closeTo(20.09, 0.01));
      expect(receipt.items.first.name, contains('Dəst'));
      expect(receipt.items.first.name, isNot(contains('84693106267')));
      expect(receipt.items.last.name, contains('Poşet'));
    });

    test('does not treat change line as total', () {
      const ocr = '''
Obyektin adı: TEST MAĞAZA
Məhsulun adı Say Qiymət Cəmi
1 10.00 10.00
Cəmi 10.00
Qalıq qaytarılıb nağd 80.01
Fiskal İD: abc123
''';
      final structured = OcrService.preprocessEkassaText(ocr);
      expect(structured, isNot(contains('TOTAL: 80.01')));
      expect(structured, anyOf(contains('TOTAL: 10.00'), contains('TOTAL: 10 AZN')));
    });

    test('finds items when table header OCR is missing', () {
      const ocr = '''
Obyektin adı: QARIŞIQ MALLAR MAĞAZASI
Tarix: 30.05.2026
Dəst (ANTHRACITE)
Poşet S
1 19.99 19.99
1 0.10 0.10
Cəmi 20.09
Fiskal İD: 7p4vW1ybWF2a
''';
      final structured = OcrService.preprocessEkassaText(ocr);
      final receipt = StructuredReceiptParser.tryParse(structured);
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 2);
      expect(receipt.total, closeTo(20.09, 0.01));
    });

    test('SUNMI trade-markup receipt with split price lines', () {
      const ocr = '''
Object name: ARZAQ MAĞAZASI
04.06.2026
Quantity Price Total
Product
0.85
3.40
SAVUSKI YOQURT ERIK
(pc)
*Trade markup: 18%
Total
3.40
Fiscal ID: 4tTQLtJ6pL5N
''';
      final structured = OcrService.preprocessEkassaText(ocr);
      final receipt = StructuredReceiptParser.tryParse(structured);
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 1);
      expect(receipt.total, closeTo(3.40, 0.05));
      expect(receipt.items.first.name.toUpperCase(), contains('SAVUSKI'));
    });

    test('two items when unit/qty/total split across lines', () {
      const ocr = '''
Object name: ARZAQ MAĞAZASI
04.06.2026
Quantity Price Total
Product
1
2.90 2.90
BLACK STYLE COMPACTS (pc)
*Trade markup: 18%
1.80
1
NAPITOK GO 0.5 L SILVER (pc)
1.80
*Trade markup: 18%
Total
4.70
Fiscal ID: 3SqhhohgojRd
''';
      final structured = OcrService.preprocessEkassaText(ocr);
      final receipt = StructuredReceiptParser.tryParse(structured);
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 2);
      expect(receipt.total, closeTo(4.70, 0.05));
      expect(
        receipt.items.any((i) => i.name.toUpperCase().contains('NAPITOK')),
        isTrue,
      );
    });

    test('finds items when qty unit total are on separate lines', () {
      const ocr = '''
Obyektin adı: BRAVO
Tarix: 01.06.2026
Dəst
Poşet
1
19.99
19.99
1
0.10
0.10
Cəmi 20.09
Fiskal İD: test123
''';
      final structured = OcrService.preprocessEkassaText(ocr);
      final receipt = StructuredReceiptParser.tryParse(structured);
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 2);
    });
  });
}
