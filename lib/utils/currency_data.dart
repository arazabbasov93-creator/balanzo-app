class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final String country;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.country,
  });
}

const kCurrencies = <CurrencyInfo>[
  CurrencyInfo(code: 'AZN', symbol: '₼', name: 'Azerbaijani Manat', country: 'Azerbaijan'),
  CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar', country: 'United States'),
  CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro', country: 'European Union'),
  CurrencyInfo(code: 'GBP', symbol: '£', name: 'British Pound', country: 'United Kingdom'),
  CurrencyInfo(code: 'TRY', symbol: '₺', name: 'Turkish Lira', country: 'Turkey'),
  CurrencyInfo(code: 'RUB', symbol: '₽', name: 'Russian Ruble', country: 'Russia'),
  CurrencyInfo(code: 'GEL', symbol: '₾', name: 'Georgian Lari', country: 'Georgia'),
  CurrencyInfo(code: 'KZT', symbol: '₸', name: 'Kazakhstani Tenge', country: 'Kazakhstan'),
  CurrencyInfo(code: 'UAH', symbol: '₴', name: 'Ukrainian Hryvnia', country: 'Ukraine'),
  CurrencyInfo(code: 'AMD', symbol: '֏', name: 'Armenian Dram', country: 'Armenia'),
  CurrencyInfo(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham', country: 'United Arab Emirates'),
  CurrencyInfo(code: 'SAR', symbol: '﷼', name: 'Saudi Riyal', country: 'Saudi Arabia'),
  CurrencyInfo(code: 'INR', symbol: '₹', name: 'Indian Rupee', country: 'India'),
  CurrencyInfo(code: 'CNY', symbol: '¥', name: 'Chinese Yuan', country: 'China'),
  CurrencyInfo(code: 'JPY', symbol: '¥', name: 'Japanese Yen', country: 'Japan'),
  CurrencyInfo(code: 'KRW', symbol: '₩', name: 'South Korean Won', country: 'South Korea'),
  CurrencyInfo(code: 'THB', symbol: '฿', name: 'Thai Baht', country: 'Thailand'),
  CurrencyInfo(code: 'VND', symbol: '₫', name: 'Vietnamese Dong', country: 'Vietnam'),
  CurrencyInfo(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah', country: 'Indonesia'),
  CurrencyInfo(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit', country: 'Malaysia'),
  CurrencyInfo(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', country: 'Singapore'),
  CurrencyInfo(code: 'HKD', symbol: 'HK\$', name: 'Hong Kong Dollar', country: 'Hong Kong'),
  CurrencyInfo(code: 'PKR', symbol: '₨', name: 'Pakistani Rupee', country: 'Pakistan'),
  CurrencyInfo(code: 'BDT', symbol: '৳', name: 'Bangladeshi Taka', country: 'Bangladesh'),
  CurrencyInfo(code: 'EGP', symbol: 'E£', name: 'Egyptian Pound', country: 'Egypt'),
  CurrencyInfo(code: 'NGN', symbol: '₦', name: 'Nigerian Naira', country: 'Nigeria'),
  CurrencyInfo(code: 'ZAR', symbol: 'R', name: 'South African Rand', country: 'South Africa'),
  CurrencyInfo(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real', country: 'Brazil'),
  CurrencyInfo(code: 'MXN', symbol: 'MX\$', name: 'Mexican Peso', country: 'Mexico'),
  CurrencyInfo(code: 'ARS', symbol: 'AR\$', name: 'Argentine Peso', country: 'Argentina'),
  CurrencyInfo(code: 'COP', symbol: 'CO\$', name: 'Colombian Peso', country: 'Colombia'),
  CurrencyInfo(code: 'CLP', symbol: 'CL\$', name: 'Chilean Peso', country: 'Chile'),
  CurrencyInfo(code: 'CAD', symbol: 'CA\$', name: 'Canadian Dollar', country: 'Canada'),
  CurrencyInfo(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', country: 'Australia'),
  CurrencyInfo(code: 'NZD', symbol: 'NZ\$', name: 'New Zealand Dollar', country: 'New Zealand'),
  CurrencyInfo(code: 'CHF', symbol: 'Fr', name: 'Swiss Franc', country: 'Switzerland'),
  CurrencyInfo(code: 'SEK', symbol: 'kr', name: 'Swedish Krona', country: 'Sweden'),
  CurrencyInfo(code: 'NOK', symbol: 'kr', name: 'Norwegian Krone', country: 'Norway'),
  CurrencyInfo(code: 'DKK', symbol: 'kr', name: 'Danish Krone', country: 'Denmark'),
  CurrencyInfo(code: 'PLN', symbol: 'zł', name: 'Polish Zloty', country: 'Poland'),
  CurrencyInfo(code: 'HUF', symbol: 'Ft', name: 'Hungarian Forint', country: 'Hungary'),
  CurrencyInfo(code: 'CZK', symbol: 'Kč', name: 'Czech Koruna', country: 'Czech Republic'),
  CurrencyInfo(code: 'RON', symbol: 'lei', name: 'Romanian Leu', country: 'Romania'),
  CurrencyInfo(code: 'BGN', symbol: 'лв', name: 'Bulgarian Lev', country: 'Bulgaria'),
  CurrencyInfo(code: 'RSD', symbol: 'din', name: 'Serbian Dinar', country: 'Serbia'),
  CurrencyInfo(code: 'TND', symbol: 'DT', name: 'Tunisian Dinar', country: 'Tunisia'),
  CurrencyInfo(code: 'MAD', symbol: 'د.م', name: 'Moroccan Dirham', country: 'Morocco'),
  CurrencyInfo(code: 'ILS', symbol: '₪', name: 'Israeli Shekel', country: 'Israel'),
  CurrencyInfo(code: 'JOD', symbol: 'د.ا', name: 'Jordanian Dinar', country: 'Jordan'),
  CurrencyInfo(code: 'KWD', symbol: 'د.ك', name: 'Kuwaiti Dinar', country: 'Kuwait'),
  CurrencyInfo(code: 'QAR', symbol: 'ر.ق', name: 'Qatari Riyal', country: 'Qatar'),
  CurrencyInfo(code: 'BHD', symbol: 'BD', name: 'Bahraini Dinar', country: 'Bahrain'),
  CurrencyInfo(code: 'OMR', symbol: 'ر.ع', name: 'Omani Rial', country: 'Oman'),
  CurrencyInfo(code: 'UZS', symbol: "so'm", name: 'Uzbekistani Som', country: 'Uzbekistan'),
  CurrencyInfo(code: 'TJS', symbol: 'SM', name: 'Tajikistani Somoni', country: 'Tajikistan'),
  CurrencyInfo(code: 'TMT', symbol: 'T', name: 'Turkmenistani Manat', country: 'Turkmenistan'),
  CurrencyInfo(code: 'KGS', symbol: 'с', name: 'Kyrgystani Som', country: 'Kyrgyzstan'),
  CurrencyInfo(code: 'MNT', symbol: '₮', name: 'Mongolian Togrog', country: 'Mongolia'),
  CurrencyInfo(code: 'TWD', symbol: 'NT\$', name: 'New Taiwan Dollar', country: 'Taiwan'),
  CurrencyInfo(code: 'PHP', symbol: '₱', name: 'Philippine Peso', country: 'Philippines'),
  CurrencyInfo(code: 'MOP', symbol: 'P', name: 'Macanese Pataca', country: 'Macau'),
  CurrencyInfo(code: 'BND', symbol: 'B\$', name: 'Brunei Dollar', country: 'Brunei'),
  CurrencyInfo(code: 'KHR', symbol: '៛', name: 'Cambodian Riel', country: 'Cambodia'),
  CurrencyInfo(code: 'LAK', symbol: '₭', name: 'Lao Kip', country: 'Laos'),
  CurrencyInfo(code: 'MMK', symbol: 'K', name: 'Myanmar Kyat', country: 'Myanmar'),
  CurrencyInfo(code: 'NPR', symbol: '₨', name: 'Nepalese Rupee', country: 'Nepal'),
  CurrencyInfo(code: 'LKR', symbol: '₨', name: 'Sri Lankan Rupee', country: 'Sri Lanka'),
  CurrencyInfo(code: 'AFN', symbol: '؋', name: 'Afghan Afghani', country: 'Afghanistan'),
  CurrencyInfo(code: 'IRR', symbol: '﷼', name: 'Iranian Rial', country: 'Iran'),
  CurrencyInfo(code: 'IQD', symbol: 'ع.د', name: 'Iraqi Dinar', country: 'Iraq'),
  CurrencyInfo(code: 'LBP', symbol: 'ل.ل', name: 'Lebanese Pound', country: 'Lebanon'),
  CurrencyInfo(code: 'YER', symbol: '﷼', name: 'Yemeni Rial', country: 'Yemen'),
  CurrencyInfo(code: 'ETB', symbol: 'Br', name: 'Ethiopian Birr', country: 'Ethiopia'),
  CurrencyInfo(code: 'KES', symbol: 'KSh', name: 'Kenyan Shilling', country: 'Kenya'),
  CurrencyInfo(code: 'GHS', symbol: '₵', name: 'Ghanaian Cedi', country: 'Ghana'),
  CurrencyInfo(code: 'TZS', symbol: 'TSh', name: 'Tanzanian Shilling', country: 'Tanzania'),
  CurrencyInfo(code: 'UGX', symbol: 'USh', name: 'Ugandan Shilling', country: 'Uganda'),
  CurrencyInfo(code: 'RWF', symbol: 'Fr', name: 'Rwandan Franc', country: 'Rwanda'),
  CurrencyInfo(code: 'XOF', symbol: 'Fr', name: 'West African CFA Franc', country: 'West Africa'),
  CurrencyInfo(code: 'XAF', symbol: 'Fr', name: 'Central African CFA Franc', country: 'Central Africa'),
  CurrencyInfo(code: 'DZD', symbol: 'د.ج', name: 'Algerian Dinar', country: 'Algeria'),
  CurrencyInfo(code: 'LYD', symbol: 'ل.د', name: 'Libyan Dinar', country: 'Libya'),
  CurrencyInfo(code: 'MUR', symbol: '₨', name: 'Mauritian Rupee', country: 'Mauritius'),
  CurrencyInfo(code: 'MZN', symbol: 'MT', name: 'Mozambican Metical', country: 'Mozambique'),
  CurrencyInfo(code: 'ZMW', symbol: 'ZK', name: 'Zambian Kwacha', country: 'Zambia'),
  CurrencyInfo(code: 'BWP', symbol: 'P', name: 'Botswana Pula', country: 'Botswana'),
  CurrencyInfo(code: 'NAD', symbol: 'N\$', name: 'Namibian Dollar', country: 'Namibia'),
  CurrencyInfo(code: 'PEN', symbol: 'S/.', name: 'Peruvian Sol', country: 'Peru'),
  CurrencyInfo(code: 'UYU', symbol: '\$U', name: 'Uruguayan Peso', country: 'Uruguay'),
  CurrencyInfo(code: 'BOB', symbol: 'Bs', name: 'Bolivian Boliviano', country: 'Bolivia'),
  CurrencyInfo(code: 'PYG', symbol: '₲', name: 'Paraguayan Guarani', country: 'Paraguay'),
  CurrencyInfo(code: 'GTQ', symbol: 'Q', name: 'Guatemalan Quetzal', country: 'Guatemala'),
  CurrencyInfo(code: 'HNL', symbol: 'L', name: 'Honduran Lempira', country: 'Honduras'),
  CurrencyInfo(code: 'NIO', symbol: 'C\$', name: 'Nicaraguan Cordoba', country: 'Nicaragua'),
  CurrencyInfo(code: 'CRC', symbol: '₡', name: 'Costa Rican Colon', country: 'Costa Rica'),
  CurrencyInfo(code: 'DOP', symbol: 'RD\$', name: 'Dominican Peso', country: 'Dominican Republic'),
  CurrencyInfo(code: 'JMD', symbol: 'J\$', name: 'Jamaican Dollar', country: 'Jamaica'),
  CurrencyInfo(code: 'TTD', symbol: 'TT\$', name: 'Trinidad Dollar', country: 'Trinidad and Tobago'),
  CurrencyInfo(code: 'ISK', symbol: 'kr', name: 'Icelandic Krona', country: 'Iceland'),
  CurrencyInfo(code: 'HRK', symbol: 'kn', name: 'Croatian Kuna', country: 'Croatia'),
  CurrencyInfo(code: 'BAM', symbol: 'KM', name: 'Bosnia-Herzegovina Mark', country: 'Bosnia'),
  CurrencyInfo(code: 'MKD', symbol: 'ден', name: 'Macedonian Denar', country: 'North Macedonia'),
  CurrencyInfo(code: 'ALL', symbol: 'L', name: 'Albanian Lek', country: 'Albania'),
  CurrencyInfo(code: 'MDL', symbol: 'L', name: 'Moldovan Leu', country: 'Moldova'),
  CurrencyInfo(code: 'BYN', symbol: 'Br', name: 'Belarusian Ruble', country: 'Belarus'),
  CurrencyInfo(code: 'KPW', symbol: '₩', name: 'North Korean Won', country: 'North Korea'),
  CurrencyInfo(code: 'FJD', symbol: 'FJ\$', name: 'Fijian Dollar', country: 'Fiji'),
  CurrencyInfo(code: 'PGK', symbol: 'K', name: 'Papua New Guinean Kina', country: 'Papua New Guinea'),
  CurrencyInfo(code: 'SBD', symbol: 'SI\$', name: 'Solomon Islands Dollar', country: 'Solomon Islands'),
  CurrencyInfo(code: 'TOP', symbol: 'T\$', name: 'Tongan Paanga', country: 'Tonga'),
  CurrencyInfo(code: 'WST', symbol: 'WS\$', name: 'Samoan Tala', country: 'Samoa'),
];

CurrencyInfo? currencyInfoFor(String? code) {
  if (code == null || code.isEmpty) return null;
  final upper = code.toUpperCase();
  for (final c in kCurrencies) {
    if (c.code == upper) return c;
  }
  return null;
}

String currencySymbol(String? code) => currencyInfoFor(code)?.symbol ?? '';

String formatMoney(double amount, String? currency, {int decimals = 2}) {
  final formatted = amount.toStringAsFixed(decimals);
  final symbol = currencySymbol(currency);
  if (symbol.isNotEmpty) return '$symbol$formatted';
  if (currency != null && currency.isNotEmpty) return '$formatted $currency';
  return formatted;
}

String currencyDisplayLabel(String? code) {
  final info = currencyInfoFor(code);
  if (info == null) return 'Unknown — tap to select';
  return '${info.symbol} ${info.code} — ${info.name}';
}
