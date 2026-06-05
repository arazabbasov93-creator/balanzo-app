import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/services/receipt_parser_service.dart';

void main() {
  test('skips Anthropic when API key is not configured', () async {
    expect(ReceiptParserService.isAvailable, isFalse);
    expect(
      () => ReceiptParserService.parse('random unstructured text'),
      throwsA(
        predicate(
          (e) =>
              e is Exception &&
              e.toString().contains('Could not parse this receipt on device'),
        ),
      ),
    );
  });
}
