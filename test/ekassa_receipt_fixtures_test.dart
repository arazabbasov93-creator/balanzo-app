import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/models/receipt.dart';
import 'package:balanzo/services/ocr_service.dart';
import 'package:balanzo/services/structured_receipt_parser.dart';

Receipt? parse(String ocr) =>
    StructuredReceiptParser.tryParse(OcrService.preprocessEkassaText(ocr));

void main() {
  group('e-kassa ground-truth fixtures', () {
    test('7p4v QARIŞIQ MALLAR — 2 items, 20.09', () {
      const ocr = '''
Object name: QARIŞIQ MALLAR MAĞAZASI
Object address: AZ1052 BAKI NƏRİMANOV
Date: 30.05.2026
Time: 15:41:52
Dəst (ANTHRACITE, 5y ,) (8684693106267)
*VAT: 18%
Poşet S ()
*VAT: 18%
Product Quantity Price Total
1 19.99 19.99
1 0.10 0.10
Total 20.09
Fiscal ID: 7p4vW1ybWF2a
''';
      final r = parse(ocr)!;
      expect(r.items.length, 2);
      expect(r.total, closeTo(20.09, 0.01));
      expect(r.items[0].name.toLowerCase(), contains('dəst'));
      expect(r.items[1].name.toLowerCase(), contains('poşet'));
      expect(r.items[0].totalPrice, closeTo(19.99, 0.02));
      expect(r.items[1].totalPrice, closeTo(0.10, 0.02));
    });

    test('24AAdt MƏHƏLLƏ MARKET — 9 items, 30.42', () {
      const ocr = '''
Object name: MƏHƏLLƏ MARKET
YUMURTA
*VAT-exempt
MILLA XAMA 300 QR 20 %
*VAT: 18%
MILLA PENDIR QAYMAQLI 250 QR
*VAT: 18%
YASKINO VAFLI FINDIQ-U ZUM SHOK KQ
*VAT: 18%
YASKINO TRUBKA VAFLI K Q KOKOS
*VAT: 18%
SUPER XRUPER-VOZDUS PSHEN KQ ASSORTI
*VAT: 18%
ASSORTI CHEESCAKE M. R
*VAT-exempt
COCA COLA 2 LT PR
*VAT: 18%
MEHELLE PAKET
*VAT: 18%
Product Quantity Price Total
15 0.17 2.55
1 2.90 2.90
1 3.74 3.74
0.300 13.15 3.95
0.300 11.25 3.38
0.155 9.75 1.51
0.715 14.00 10.01
1 2.30 2.30
2 0.04 0.08
Total 30.42
Fiscal ID: 24AAdtSZ36Wr
''';
      final r = parse(ocr)!;
      expect(r.items.length, 9);
      expect(r.total, closeTo(30.42, 0.05));
      expect(r.items[0].name.toUpperCase(), contains('YUMURTA'));
      expect(r.items[0].totalPrice, closeTo(2.55, 0.02));
      expect(r.items.last.name.toUpperCase(), contains('MEHELLE PAKET'));
      final sum = r.items.fold(0.0, (s, i) => s + i.totalPrice);
      expect(sum, closeTo(30.42, 0.08));
    });

    test('2vL7E MƏHƏLLƏ MARKET — 4 items, 8.87', () {
      const ocr = '''
Object name: MƏHƏLLƏ MARKET
ASSORTI TORT M.R
*VAT-exempt
ASSORTI QOZLU M.R
*VAT: 18%
ASSORTI CHEESCAKE M.R
*VAT-exempt
MEHELLE PAKET
*VAT: 18%
Product Quantity Price Total
0.150 15.00 2.25
0.280 10.00 2.80
0.270 14.00 3.78
1 0.04 0.04
Total 8.87
Fiscal ID: 2vL7E5bXRJ3Y
''';
      final r = parse(ocr)!;
      expect(r.items.length, 4);
      expect(r.total, closeTo(8.87, 0.02));
      expect(r.items.last.name.toUpperCase(), contains('MEHELLE PAKET'));
    });

    test('E7av3 MƏHƏLLƏ MARKET — 2 items, 6.33', () {
      const ocr = '''
Object name: MƏHƏLLƏ MARKET
ASSORTI CHEESCAKE M.R (kg)
*VAT-exempt
QOZ SHIRNIYYAT MEHELL E (kg)
*VAT: 18%
Product Quantity Price Total
0.335 14.00 4.69
0.225 7.30 1.64
Total 6.33
Fiscal ID: E7av3BYTEgRV
''';
      final r = parse(ocr)!;
      expect(r.items.length, 2);
      expect(r.total, closeTo(6.33, 0.02));
      expect(r.items[1].name.toUpperCase(), contains('QOZ'));
    });

    test('CaBCpw APTEK — 7 items incl. free gift, 62.38', () {
      const ocr = '''
Object name: APTEK
OTIPAKS 15ml kapli (40 +10) mq ml
*VAT: 18%
OTRIVIN 0.05% 10ml kapli
*VAT: 18%
MEKSUN 7.5mg N10
*VAT: 18%
RODINIR 250mg/5ml 60 ml (cefdinir)
*VAT: 18%
KLOK ZEFERAN 30x40 (1 kq=54) (EDED)
*VAT: 18%
PULMOTEN 150ml
*VAT: 18%
OTRIVIN SALFET (hediyye)
*VAT: 18%
Product Quantity Price Total
1 8.59 8.59
1 4.64 4.64
1 4.45 4.45
1 21.40 21.40
1 0.10 0.10
1 23.20 23.20
1 0.00 0.00
Total 62.38
Fiscal ID: CaBCpwD37fLQ
''';
      final r = parse(ocr)!;
      expect(r.items.length, 7);
      expect(r.total, closeTo(62.38, 0.05));
      expect(r.items[0].name.toUpperCase(), contains('OTIPAKS'));
      expect(r.items.any((i) => i.name.toLowerCase().contains('hediyye')), isTrue);
    });
  });
}
