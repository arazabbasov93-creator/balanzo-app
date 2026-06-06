import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
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
          'max_tokens': 4096,
          'system':
              'You are a receipt data extraction expert. You receive '
              'raw OCR text scanned from a physical receipt. The text '
              'may be messy, contain OCR errors, mixed languages, or '
              'unusual formatting.\n\n'
              'Your job is to extract every piece of useful information '
              'from this text in one pass. The receipt may be in any '
              'language or script. Extract regardless of language.\n\n'
              'EXTRACTION RULES:\n\n'
              'Store name:\n'
              '- Find the business name usually at the top\n'
              '- May be in any language or script\n'
              '- If not found use null\n\n'
              'Date:\n'
              '- Find any date on the receipt in any format\n'
              '- Convert to YYYY-MM-DD\n'
              '- If not found use null\n\n'
              'Items:\n'
              '- Extract every product or service line\n'
              '- Each item has a name quantity unit price and total price\n'
              '- Quantity defaults to 1 if not shown\n'
              '- Unit price equals total price if only one price shown\n'
              '- Fix obvious OCR errors: 0↔O 1↔I↔l 8↔B rn↔m\n'
              '- Remove leading numbers dots or codes not part of name\n'
              '- Keep original language of item names do not translate\n'
              '- If item line splits across two OCR lines merge them\n'
              '- Ignore header lines footer lines tax registration '
              'numbers cashier names terminal IDs receipt serial '
              'numbers\n\n'
              'Prices and numbers:\n'
              '- Normalize decimal separator to dot\n'
              '- Remove thousand separator spaces\n'
              '- All prices must be positive numbers\n\n'
              'Total:\n'
              '- Find the final total amount on the receipt\n'
              '- Usually the largest amount near the bottom\n'
              '  often emphasized or on its own line\n'
              '- May have no label at all\n'
              '- If multiple candidates use the one closest to\n'
              '  sum of all items\n'
              '- If no total found calculate from item sum\n\n'
              'Currency:\n'
              '- Read currency symbol or code directly from receipt\n'
              '- Recognize any symbol: ₼ \$ € £ ₺ ₽ ₾ ₸ ¥ ₩ ₹\n'
              '  ฿ ₫ د.إ ﷼ kr zł Ft and any ISO 4217 code\n'
              '- Return ISO 4217 code: AZN USD EUR GBP TRY RUB\n'
              '  GEL KZT JPY KRW INR THB VND AED SAR SEK PLN\n'
              '  HUF and any other valid ISO 4217 code\n'
              '- If currency appears multiple times use the one\n'
              '  next to the total amount\n'
              '- If currency cannot be determined return null\n'
              '- Never guess or default to any currency\n\n'
              'Categories:\n'
              '- Assign each item exactly one category from this\n'
              '  list: [$categoryList]\n'
              '- Use category name exactly as written\n'
              '- Never return a category outside this list\n'
              '- Use Other only when nothing fits\n\n'
              'CRITICAL RULES:\n'
              '- Never invent items not in the OCR text\n'
              '- Never skip items that are in the OCR text\n'
              '- If field cannot be determined use null for\n'
              '  strings and 0 for numbers\n'
              '- Return only valid JSON no explanation no\n'
              '  markdown no code fences\n\n'
              'Return this exact JSON structure:\n'
              '{\n'
              '  "store": "store name or null",\n'
              '  "date": "YYYY-MM-DD or null",\n'
              '  "items": [\n'
              '    {\n'
              '      "name": "item name in original language",\n'
              '      "quantity": number,\n'
              '      "unit_price": number,\n'
              '      "total_price": number,\n'
              '      "category": "category name"\n'
              '    }\n'
              '  ],\n'
              '  "subtotal": number,\n'
              '  "vat": number,\n'
              '  "total": number,\n'
              '  "currency": "ISO 4217 code or null"\n'
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
      debugPrint('[AI Parse] Raw response: $content');

      final json = content
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .trim();
      debugPrint('[AI Parse] Cleaned JSON: $json');

      return Receipt.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e, stack) {
      await CrashService.log(e, stack, context: 'receipt_parsing');
      rethrow;
    }
  }
}
