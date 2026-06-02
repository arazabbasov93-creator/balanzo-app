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
  });
}
