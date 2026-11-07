import 'dart:math' as math;

import 'package:intl/intl.dart';

/// An ISO 4217 currency with the symbol the app displays for it.
class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  const CurrencyInfo(this.code, this.symbol, this.name);
}

/// Every currency the user can pick. Where a symbol is shared by several
/// currencies or written in a right-to-left script, the code is used instead.
const List<CurrencyInfo> kCurrencies = [
  CurrencyInfo('AED', 'AED', 'UAE Dirham'),
  CurrencyInfo('AFN', 'AFN', 'Afghan Afghani'),
  CurrencyInfo('ALL', 'Lek', 'Albanian Lek'),
  CurrencyInfo('AMD', '֏', 'Armenian Dram'),
  CurrencyInfo('AOA', 'Kz', 'Angolan Kwanza'),
  CurrencyInfo('ARS', 'AR\$', 'Argentine Peso'),
  CurrencyInfo('AUD', 'A\$', 'Australian Dollar'),
  CurrencyInfo('AWG', 'AWG', 'Aruban Florin'),
  CurrencyInfo('AZN', '₼', 'Azerbaijani Manat'),
  CurrencyInfo('BAM', 'KM', 'Bosnia-Herzegovina Convertible Mark'),
  CurrencyInfo('BBD', 'Bds\$', 'Barbadian Dollar'),
  CurrencyInfo('BDT', '৳', 'Bangladeshi Taka'),
  CurrencyInfo('BGN', 'лв', 'Bulgarian Lev'),
  CurrencyInfo('BHD', 'BHD', 'Bahraini Dinar'),
  CurrencyInfo('BIF', 'FBu', 'Burundian Franc'),
  CurrencyInfo('BMD', 'BD\$', 'Bermudian Dollar'),
  CurrencyInfo('BND', 'B\$', 'Brunei Dollar'),
  CurrencyInfo('BOB', 'Bs', 'Bolivian Boliviano'),
  CurrencyInfo('BRL', 'R\$', 'Brazilian Real'),
  CurrencyInfo('BSD', 'BSD', 'Bahamian Dollar'),
  CurrencyInfo('BTN', 'Nu', 'Bhutanese Ngultrum'),
  CurrencyInfo('BWP', 'BWP', 'Botswana Pula'),
  CurrencyInfo('BYN', 'BYN', 'Belarusian Ruble'),
  CurrencyInfo('BZD', 'BZ\$', 'Belize Dollar'),
  CurrencyInfo('CAD', 'CA\$', 'Canadian Dollar'),
  CurrencyInfo('CDF', 'FC', 'Congolese Franc'),
  CurrencyInfo('CHF', 'Fr', 'Swiss Franc'),
  CurrencyInfo('CLP', 'CLP\$', 'Chilean Peso'),
  CurrencyInfo('CNY', '¥', 'Chinese Yuan'),
  CurrencyInfo('COP', 'COL\$', 'Colombian Peso'),
  CurrencyInfo('CRC', '₡', 'Costa Rican Colón'),
  CurrencyInfo('CUP', 'CUP', 'Cuban Peso'),
  CurrencyInfo('CVE', 'Esc', 'Cape Verdean Escudo'),
  CurrencyInfo('CZK', 'Kč', 'Czech Koruna'),
  CurrencyInfo('DJF', 'Fdj', 'Djiboutian Franc'),
  CurrencyInfo('DKK', 'kr', 'Danish Krone'),
  CurrencyInfo('DOP', 'RD\$', 'Dominican Peso'),
  CurrencyInfo('DZD', 'DA', 'Algerian Dinar'),
  CurrencyInfo('EGP', 'E£', 'Egyptian Pound'),
  CurrencyInfo('ETB', 'ETB', 'Ethiopian Birr'),
  CurrencyInfo('EUR', '€', 'Euro'),
  CurrencyInfo('FJD', 'FJ\$', 'Fijian Dollar'),
  CurrencyInfo('GBP', '£', 'British Pound'),
  CurrencyInfo('GEL', '₾', 'Georgian Lari'),
  CurrencyInfo('GHS', '₵', 'Ghanaian Cedi'),
  CurrencyInfo('GMD', 'GMD', 'Gambian Dalasi'),
  CurrencyInfo('GNF', 'FG', 'Guinean Franc'),
  CurrencyInfo('GTQ', 'Q', 'Guatemalan Quetzal'),
  CurrencyInfo('GYD', 'G\$', 'Guyanese Dollar'),
  CurrencyInfo('HKD', 'HK\$', 'Hong Kong Dollar'),
  CurrencyInfo('HNL', 'HNL', 'Honduran Lempira'),
  CurrencyInfo('HTG', 'HTG', 'Haitian Gourde'),
  CurrencyInfo('HUF', 'Ft', 'Hungarian Forint'),
  CurrencyInfo('IDR', 'Rp', 'Indonesian Rupiah'),
  CurrencyInfo('ILS', '₪', 'Israeli New Shekel'),
  CurrencyInfo('INR', '₹', 'Indian Rupee'),
  CurrencyInfo('IQD', 'IQD', 'Iraqi Dinar'),
  CurrencyInfo('IRR', 'IRR', 'Iranian Rial'),
  CurrencyInfo('ISK', 'ISK', 'Icelandic Króna'),
  CurrencyInfo('JMD', 'J\$', 'Jamaican Dollar'),
  CurrencyInfo('JOD', 'JOD', 'Jordanian Dinar'),
  CurrencyInfo('JPY', '¥', 'Japanese Yen'),
  CurrencyInfo('KES', 'KSh', 'Kenyan Shilling'),
  CurrencyInfo('KGS', 'KGS', 'Kyrgyzstani Som'),
  CurrencyInfo('KHR', '៛', 'Cambodian Riel'),
  CurrencyInfo('KMF', 'CF', 'Comorian Franc'),
  CurrencyInfo('KRW', '₩', 'South Korean Won'),
  CurrencyInfo('KWD', 'KWD', 'Kuwaiti Dinar'),
  CurrencyInfo('KYD', 'CI\$', 'Cayman Islands Dollar'),
  CurrencyInfo('KZT', '₸', 'Kazakhstani Tenge'),
  CurrencyInfo('LAK', '₭', 'Laotian Kip'),
  CurrencyInfo('LBP', 'LBP', 'Lebanese Pound'),
  CurrencyInfo('LKR', 'LKR', 'Sri Lankan Rupee'),
  CurrencyInfo('LRD', 'L\$', 'Liberian Dollar'),
  CurrencyInfo('LSL', 'LSL', 'Lesotho Loti'),
  CurrencyInfo('LYD', 'LD', 'Libyan Dinar'),
  CurrencyInfo('MAD', 'MAD', 'Moroccan Dirham'),
  CurrencyInfo('MDL', 'MDL', 'Moldovan Leu'),
  CurrencyInfo('MGA', 'Ar', 'Malagasy Ariary'),
  CurrencyInfo('MKD', 'ден', 'Macedonian Denar'),
  CurrencyInfo('MMK', 'MMK', 'Myanmar Kyat'),
  CurrencyInfo('MNT', '₮', 'Mongolian Tugrik'),
  CurrencyInfo('MOP', 'MOP\$', 'Macanese Pataca'),
  CurrencyInfo('MRU', 'UM', 'Mauritanian Ouguiya'),
  CurrencyInfo('MUR', 'MUR', 'Mauritian Rupee'),
  CurrencyInfo('MVR', 'Rf', 'Maldivian Rufiyaa'),
  CurrencyInfo('MWK', 'MK', 'Malawian Kwacha'),
  CurrencyInfo('MXN', 'MX\$', 'Mexican Peso'),
  CurrencyInfo('MYR', 'RM', 'Malaysian Ringgit'),
  CurrencyInfo('MZN', 'MT', 'Mozambican Metical'),
  CurrencyInfo('NAD', 'N\$', 'Namibian Dollar'),
  CurrencyInfo('NGN', '₦', 'Nigerian Naira'),
  CurrencyInfo('NIO', 'NIO', 'Nicaraguan Córdoba'),
  CurrencyInfo('NOK', 'kr', 'Norwegian Krone'),
  CurrencyInfo('NPR', 'NPR', 'Nepalese Rupee'),
  CurrencyInfo('NZD', 'NZ\$', 'New Zealand Dollar'),
  CurrencyInfo('OMR', 'OMR', 'Omani Rial'),
  CurrencyInfo('PAB', 'B/.', 'Panamanian Balboa'),
  CurrencyInfo('PEN', 'S/', 'Peruvian Sol'),
  CurrencyInfo('PGK', 'PGK', 'Papua New Guinean Kina'),
  CurrencyInfo('PHP', '₱', 'Philippine Peso'),
  CurrencyInfo('PKR', 'PKR', 'Pakistani Rupee'),
  CurrencyInfo('PLN', 'zł', 'Polish Złoty'),
  CurrencyInfo('PYG', '₲', 'Paraguayan Guaraní'),
  CurrencyInfo('QAR', 'QAR', 'Qatari Riyal'),
  CurrencyInfo('RON', 'lei', 'Romanian Leu'),
  CurrencyInfo('RSD', 'din', 'Serbian Dinar'),
  CurrencyInfo('RUB', '₽', 'Russian Ruble'),
  CurrencyInfo('RWF', 'FRw', 'Rwandan Franc'),
  CurrencyInfo('SAR', 'SAR', 'Saudi Riyal'),
  CurrencyInfo('SBD', 'SI\$', 'Solomon Islands Dollar'),
  CurrencyInfo('SCR', 'SCR', 'Seychellois Rupee'),
  CurrencyInfo('SEK', 'kr', 'Swedish Krona'),
  CurrencyInfo('SGD', 'S\$', 'Singapore Dollar'),
  CurrencyInfo('SRD', 'Sr\$', 'Surinamese Dollar'),
  CurrencyInfo('THB', '฿', 'Thai Baht'),
  CurrencyInfo('TJS', 'TJS', 'Tajikistani Somoni'),
  CurrencyInfo('TMT', 'TMT', 'Turkmenistani Manat'),
  CurrencyInfo('TND', 'DT', 'Tunisian Dinar'),
  CurrencyInfo('TOP', 'T\$', 'Tongan Paʻanga'),
  CurrencyInfo('TRY', '₺', 'Turkish Lira'),
  CurrencyInfo('TTD', 'TT\$', 'Trinidad and Tobago Dollar'),
  CurrencyInfo('TWD', 'NT\$', 'New Taiwan Dollar'),
  CurrencyInfo('TZS', 'TSh', 'Tanzanian Shilling'),
  CurrencyInfo('UAH', '₴', 'Ukrainian Hryvnia'),
  CurrencyInfo('UGX', 'USh', 'Ugandan Shilling'),
  CurrencyInfo('USD', '\$', 'US Dollar'),
  CurrencyInfo('UYU', '\$U', 'Uruguayan Peso'),
  CurrencyInfo('UZS', 'UZS', 'Uzbekistani Som'),
  CurrencyInfo('VES', 'Bs.S', 'Venezuelan Bolívar'),
  CurrencyInfo('VND', '₫', 'Vietnamese Dong'),
  CurrencyInfo('XAF', 'FCFA', 'Central African CFA Franc'),
  CurrencyInfo('XCD', 'EC\$', 'East Caribbean Dollar'),
  CurrencyInfo('XOF', 'CFA', 'West African CFA Franc'),
  CurrencyInfo('XPF', 'CFPF', 'CFP Franc'),
  CurrencyInfo('YER', 'YER', 'Yemeni Rial'),
  CurrencyInfo('ZAR', 'R', 'South African Rand'),
  CurrencyInfo('ZMW', 'ZK', 'Zambian Kwacha'),
];

final Map<String, CurrencyInfo> _byCode = {
  for (final c in kCurrencies) c.code: c,
};

CurrencyInfo? findCurrency(String code) => _byCode[code.toUpperCase()];

/// Display symbol for [code], falling back to the code itself.
String currencySymbol(String code) => findCurrency(code)?.symbol ?? code;

final _moneyFormat = NumberFormat('#,##0.00');

/// "MKD 5,529.00" — how amounts in a non-default currency are shown.
String formatWithCode(double amount, String code) =>
    '$code ${_moneyFormat.format(amount)}';

/// "1 EUR = 61.40 MKD". [rate] is units of [foreign] per 1 [base].
String formatRate(double rate, {required String base, required String foreign}) {
  final value = rate < 1 ? rate.toStringAsFixed(4) : _moneyFormat.format(rate);
  return '1 $base = $value $foreign';
}

/// Rounds to cents. Never returns less than 0.01 for a positive input, so a
/// tiny converted amount still passes the "amount > 0" Firestore rule.
double roundMoney(double value) {
  final rounded = (value * 100).round() / 100;
  return value > 0 ? math.max(0.01, rounded) : rounded;
}
