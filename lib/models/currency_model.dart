// lib/models/currency_model.dart

class CurrencyModel {
  final String code;
  final String symbol;
  final String amount;
  final String name;
  final String country;

  CurrencyModel({
    required this.code,
    required this.symbol,
    required this.amount,
    required this.name,
    required this.country,
  });
}

final List<CurrencyModel> currencyList = [
  CurrencyModel(
    code: 'NGN',
    symbol: '₦',
    amount: '15000.00',
    name: 'Naira',
    country: 'Nigeria',
  ),
  CurrencyModel(
    code: 'GBP',
    symbol: '£',
    amount: '80.00',
    name: 'Pound Sterling',
    country: 'United Kingdom',
  ),
  CurrencyModel(
    code: 'Ivory Coast',
    symbol: 'CFA',
    amount: '8900.00',
    name: 'CFA Franc',
    country: 'Ivory Coast',
  ),
  CurrencyModel(
    code: 'Burkina',
    symbol: 'CFA',
    amount: '8900.00',
    name: 'CFA Franc',
    country: 'Burkina Faso',
  ),
  CurrencyModel(
    code: 'USD',
    symbol: '\$',
    amount: '120.00',
    name: 'US Dollar',
    country: 'United States',
  ),
  CurrencyModel(
    code: 'AUD Austrilia',
    symbol: 'A\$',
    amount: '200.00',
    name: 'Australian Dollar',
    country: 'Australia',
  ),
  CurrencyModel(
    code: 'SGD Singapore',
    symbol: 'S\$',
    amount: '180.00',
    name: 'Singapore Dollar',
    country: 'Singapore',
  ),
  CurrencyModel(
    code: 'Tanzania',
    symbol: 'TSh',
    amount: '30000.00',
    name: 'Tanzanian Shilling',
    country: 'Tanzania',
  ),
  CurrencyModel(
    code: 'Cameroon',
    symbol: 'CFA',
    amount: '9500.00',
    name: 'CFA Franc',
    country: 'Cameroon',
  ),
  CurrencyModel(
    code: 'Senegal',
    symbol: 'CFA',
    amount: '86700.00',
    name: 'CFA Franc',
    country: 'Senegal',
  ),
  CurrencyModel(
    code: 'GNF',
    symbol: 'FG',
    amount: '500000.00',
    name: 'Guinean Franc',
    country: 'Guinea',
  ),
  CurrencyModel(
    code: 'UGX',
    symbol: 'USh',
    amount: '40000.00',
    name: 'Ugandan Shilling',
    country: 'Uganda',
  ),
  CurrencyModel(
    code: 'ZMW',
    symbol: 'ZK',
    amount: '700.00',
    name: 'Zambian Kwacha',
    country: 'Zambia',
  ),
  CurrencyModel(
    code: 'MWK',
    symbol: 'MK',
    amount: '35000.00',
    name: 'Malawian Kwacha',
    country: 'Malawi',
  ),
  CurrencyModel(
    code: 'KES',
    symbol: 'KSh',
    amount: '16000.00',
    name: 'Kenyan Shilling',
    country: 'Kenya',
  ),
  CurrencyModel(
    code: 'GHS',
    symbol: '₵',
    amount: '250.00',
    name: 'Ghanaian Cedi',
    country: 'Ghana',
  ),
  CurrencyModel(
    code: 'Benin',
    symbol: 'CFA',
    amount: '8900.00',
    name: 'CFA Franc',
    country: 'Benin',
  ),
  CurrencyModel(
    code: 'XOF Mali',
    symbol: 'CFA',
    amount: '8800.00',
    name: 'CFA Franc',
    country: 'Mali',
  ),
  CurrencyModel(
    code: 'XOF Togo',
    symbol: 'CFA',
    amount: '87000.00',
    name: 'CFA Franc',
    country: 'Togo',
  ),
  CurrencyModel(
    code: 'AED',
    symbol: 'د.إ',
    amount: '440.00',
    name: 'UAE Dirham',
    country: 'United Arab Emirates',
  ),
  CurrencyModel(
    code: 'EUR France',
    symbol: '€',
    amount: '100.00',
    name: 'Euro',
    country: 'France',
  ),
  CurrencyModel(
    code: 'CDF DR Congo',
    symbol: 'FC',
    amount: '80000.00',
    name: 'Congolese Franc',
    country: 'Democratic Republic of the Congo',
  ),
  CurrencyModel(
    code: 'EUR Italy',
    symbol: '€',
    amount: '100.00',
    name: 'Euro',
    country: 'Italy',
  ),
  CurrencyModel(
    code: 'EUR Spain',
    symbol: '€',
    amount: '100.00',
    name: 'Euro',
    country: 'Spain',
  ),
  CurrencyModel(
    code: 'CNY China',
    symbol: '¥',
    amount: '700.00',
    name: 'Chinese Yuan',
    country: 'China',
  ),
  CurrencyModel(
    code: 'XOF Niger',
    symbol: 'CFA',
    amount: '89000.00',
    name: 'CFA Franc',
    country: 'Niger Republic',
  ),
];

class StablecoinModel {
  final String name;
  final String ticker;
  final String balance;

  StablecoinModel({
    required this.name,
    required this.ticker,
    required this.balance,
  });
}

final List<StablecoinModel> stablecoins = [
  StablecoinModel(name: 'Tether', ticker: 'USDT', balance: '120.00'),
  StablecoinModel(name: 'USD Coin', ticker: 'USDC', balance: '75.00'),
  StablecoinModel(name: 'TrueUSD', ticker: 'TUSD', balance: '60.00'),
  StablecoinModel(name: 'Pax Dollar', ticker: 'USDP', balance: '40.00'),
  StablecoinModel(name: 'Euro Coin', ticker: 'EUROC', balance: '30.00'),
  StablecoinModel(name: 'FDUSD', ticker: 'FDUSD', balance: '25.00'),
  StablecoinModel(name: 'Stably USD', ticker: 'USDS', balance: '10.00'),
  StablecoinModel(name: 'GYEN', ticker: 'GYEN', balance: '1500.00'),
  StablecoinModel(name: 'XSGD', ticker: 'XSGD', balance: '210.00'),
  StablecoinModel(name: 'CADC', ticker: 'CADC', balance: '90.00'),
  StablecoinModel(name: 'HKD', ticker: 'HKD', balance: '300.00'),
];
