import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/anthropic_config.dart';
import '../models/receipt.dart';
import 'category_service.dart';
import 'crash_service.dart';

class ReceiptParserService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  static bool get isAvailable => AnthropicConfig.apiKey.trim().isNotEmpty;

  static Future<Receipt> parse(String ocrText) async {
    if (!isAvailable) {
      throw Exception(
        'Could not parse this receipt on device. '
        'Try a clearer photo, scan the e-kassa QR, or enter items manually.',
      );
    }

    final cats = CategoryService.cached;
    final categoryNames = cats.map((c) => c.name).toList();
    final categoryList = categoryNames.isEmpty ? 'Other' : categoryNames.join(', ');
    final categoryPrompt = categoryNames.isEmpty
        ? ''
        : 'For each item assign exactly one category from this list: [$categoryList]. '
            'Use the category name exactly as written. Never return a category name outside this list. '
            'Use Other only when no category can be reasonably inferred.\n';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'x-api-key': AnthropicConfig.apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 1024,
          'system':
              'You receive pre-structured receipt data extracted from OCR. Your job is normalization only -not parsing.\n\n'
              'The input format is:\n'
              'STORE: store name\n'
              'DATE: YYYY-MM-DD\n'
              'TOTAL: amount currency\n'
              'SERVICE_CHARGE: amount (rate%) -- optional, only present if a service fee exists\n'
              '---\n'
              'ITEM: raw name | QTY: quantity | UNIT: unit_price | TOTAL: total_price\n\n'
              'Your tasks:\n'
              '1. Clean item names -fix obvious OCR errors (confused characters: 0/O, 1/I/l, 8/B, rn/m), remove leading numbers and dots\n'
              '2. Convert all numbers to proper decimals (commas to dots)\n'
              '3. Return the store name exactly as given -do not modify it\n'
              '4. Return the date exactly as given -do not modify it\n'
              '5. Calculate subtotal as sum of all item total_price values\n'
              '6. If total provided, use it -otherwise sum items\n'
              '7. If SERVICE_CHARGE is provided, use that exact value for service_charge field\n'
              '8. $categoryPrompt\n\n'
              'Return only valid JSON, no explanation, no markdown:\n'
              '{\n'
              '  "store": "store name or null",\n'
              '  "date": "YYYY-MM-DD or null",\n'
              '  "items": [\n'
              '    {\n'
              '      "name": "cleaned item name",\n'
              '      "quantity": number,\n'
              '      "unit_price": number,\n'
              '      "total_price": number,\n'
              '      "category": "category name"\n'
              '    }\n'
              '  ],\n'
              '  "subtotal": number,\n'
              '  "service_charge": number,\n'
              '  "vat": 0,\n'
              '  "total": number,\n'
              '  "currency": "AZN"\n'
              '}',
          'messages': [
            {
              'role': 'user',
              'content': 'Receipt OCR text:\n$ocrText',
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Anthropic API error ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = (data['content'] as List).first['text'] as String;

      final json = content
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .trim();

      return Receipt.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e, stack) {
      await CrashService.log(e, stack, context: 'receipt_parsing');
      rethrow;
    }
  }
}
