import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/services/ekassa_service.dart';

void main() {
  group('extractDocumentId', () {
    test('bare fiscal id', () {
      expect(EkassaService.extractDocumentId('E7av3BYTEgRV'), 'E7av3BYTEgRV');
    });

    test('hash URL from real receipt QR', () {
      expect(
        EkassaService.extractDocumentId(
          'https://monitoring.e-kassa.gov.az/#/index?doc=E7av3BYTEgRV',
        ),
        'E7av3BYTEgRV',
      );
    });

    test('e-kassa URL with doc param', () {
      expect(
        EkassaService.extractDocumentId(
          'https://monitoring.e-kassa.gov.az/?doc=FISCAL123',
        ),
        'FISCAL123',
      );
    });

    test('empty input', () {
      expect(EkassaService.extractDocumentId(''), isNull);
      expect(EkassaService.extractDocumentId('   '), isNull);
    });

    test('garbage without doc param', () {
      expect(EkassaService.extractDocumentId('not a valid id!!!'), isNull);
    });

    test('rejects product barcode (EAN-13)', () {
      expect(EkassaService.extractDocumentId('1234567890123'), isNull);
    });

    test('accepts short fiscal id with letters', () {
      expect(EkassaService.extractDocumentId('2vL7E5bXRJ3Y'), '2vL7E5bXRJ3Y');
    });
  });

  group('pickDocumentIdFromRawValues', () {
    test('prefers e-kassa payload over barcode noise', () {
      expect(
        EkassaService.pickDocumentIdFromRawValues([
          '1234567890123',
          'https://monitoring.e-kassa.gov.az/?doc=E7av3BYTEgRV',
        ]),
        'https://monitoring.e-kassa.gov.az/?doc=E7av3BYTEgRV',
      );
    });
  });
}
