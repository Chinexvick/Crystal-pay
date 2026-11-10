import 'dart:ui';

import 'package:crystal_pay/core/icons/phosphor.dart';

import '../app/theme.dart';

// ───────────────────────── Billers ─────────────────────────

enum BillKind { network, disco, tv, betting, internet }

class Biller {
  const Biller({required this.id, required this.name, required this.kind, this.asset, this.color = C.primary, this.isNew = false, this.short});
  final String id;
  final String name;
  final BillKind kind;
  final String? asset;
  final Color color;
  final bool isNew;
  final String? short;
}

String _l(String n) => 'assets/logos/$n.webp';

const networks = <Biller>[
  Biller(id: 'mtn', name: 'MTN', kind: BillKind.network, asset: 'assets/logos/mtn.webp'),
  Biller(id: 'airtel', name: 'Airtel', kind: BillKind.network, asset: 'assets/logos/airtel.webp'),
  Biller(id: 'glo', name: 'GLO', kind: BillKind.network, asset: 'assets/logos/glo.webp'),
  Biller(id: 't2', name: 'T2 Mobile', kind: BillKind.network, asset: 'assets/logos/t2.webp'),
  Biller(id: 'vitel', name: 'VITEL', kind: BillKind.network, asset: 'assets/logos/vitel.webp'),
];

final discos = <Biller>[
  Biller(id: 'ibedc', name: 'Ibadan Electricity', kind: BillKind.disco, asset: _l('ibedc'), short: 'IBEDC'),
  Biller(id: 'jos', name: 'Jos Electricity', kind: BillKind.disco, asset: _l('jos'), short: 'JED'),
  Biller(id: 'phed', name: 'Port Harcourt Electricity', kind: BillKind.disco, asset: _l('phed'), short: 'PHED'),
  Biller(id: 'kaduna', name: 'Kaduna Electricity', kind: BillKind.disco, asset: _l('kaduna'), short: 'KAEDCO'),
  Biller(id: 'ikeja', name: 'Ikeja Electricity', kind: BillKind.disco, asset: _l('ikeja'), short: 'IKEDC'),
  Biller(id: 'abuja', name: 'Abuja Electricity', kind: BillKind.disco, asset: _l('abuja'), short: 'AEDC'),
  Biller(id: 'eko', name: 'Eko Electricity', kind: BillKind.disco, asset: _l('eko'), short: 'EKEDC'),
  Biller(id: 'enugu', name: 'Enugu Electricity', kind: BillKind.disco, asset: _l('enugu'), short: 'EEDC'),
  Biller(id: 'kano', name: 'Kano Electricity', kind: BillKind.disco, asset: _l('kano'), short: 'KEDCO'),
  Biller(id: 'benin', name: 'Benin Electricity', kind: BillKind.disco, asset: _l('benin'), short: 'BEDC'),
  Biller(id: 'startimes', name: 'Startimes Energy', kind: BillKind.disco, asset: _l('startimes')),
  Biller(id: 'yola', name: 'Yola Electricity', kind: BillKind.disco, asset: _l('yola'), isNew: true, short: 'YEDC'),
  Biller(id: 'aba', name: 'Aba Electricity', kind: BillKind.disco, asset: _l('aba'), short: 'ABA'),
];

final tvProviders = <Biller>[
  Biller(id: 'dstv', name: 'DStv', kind: BillKind.tv, asset: _l('dstv'), color: C.primary),
  Biller(id: 'gotv', name: 'GOtv', kind: BillKind.tv, asset: _l('gotv'), color: C.violet),
  Biller(id: 'startimes_tv', name: 'StarTimes', kind: BillKind.tv, asset: _l('startimes_tv'), color: Color(0xFFE8890C)),
  Biller(id: 'showmax', name: 'Showmax', kind: BillKind.tv, color: C.navy),
];

final bettingProviders = <Biller>[
  Biller(id: 'bangbet', name: 'Bangbet', kind: BillKind.betting, asset: _l('bangbet')),
  Biller(id: 'ilotbet', name: 'iLOTBet', kind: BillKind.betting, asset: _l('ilotbet')),
  Biller(id: '1xbet', name: '1xBET', kind: BillKind.betting, asset: _l('1xbet')),
  Biller(id: 'bet9ja', name: 'Bet9ja', kind: BillKind.betting, asset: _l('bet9ja'), color: C.primaryDark),
  Biller(id: 'sporty', name: 'SportyBet', kind: BillKind.betting, asset: _l('sporty'), color: C.error),
  Biller(id: 'nairabet', name: 'NairaBet', kind: BillKind.betting, asset: _l('nairabet'), color: C.navy),
  Biller(id: 'betking', name: 'BetKing', kind: BillKind.betting, asset: _l('betking'), color: C.violet),
  Biller(id: 'merrybet', name: 'MerryBet', kind: BillKind.betting, asset: _l('merrybet'), color: Color(0xFFE8890C)),
  Biller(id: 'betway', name: 'Betway', kind: BillKind.betting, asset: _l('betway'), color: C.primary),
  Biller(id: 'livescore', name: 'LiveScore Bet', kind: BillKind.betting, asset: _l('livescore'), color: C.cyan),
];

final internetProviders = <Biller>[
  Biller(id: 'spectranet', name: 'Spectranet', kind: BillKind.internet, color: C.primary),
  Biller(id: 'smile', name: 'Smile', kind: BillKind.internet, color: C.violet),
  Biller(id: 'fiberone', name: 'FiberOne', kind: BillKind.internet, color: C.navy),
  Biller(id: 'ipnx', name: 'ipNX', kind: BillKind.internet, color: C.cyan),
];

Biller networkById(String id) => networks.firstWhere((n) => n.id == id, orElse: () => networks.first);

// ───────────────────────── Data plans ─────────────────────────

class DataPlan {
  const DataPlan(this.size, this.unit, this.days, this.price, this.bucket, {this.tag});
  final String size;
  final String unit;
  final int days;
  final int price;
  final String bucket; // HOT / Daily / Weekly / Weekend / Monthly
  final String? tag;
  String get validity => days == 1 ? '1 Day' : '$days Days';
  String get label => '$size$unit';
}

const dataBuckets = ['HOT', 'Daily', 'Weekly', 'Weekend', 'Monthly'];

const _basePlans = <DataPlan>[
  DataPlan('500', 'MB', 30, 250, 'HOT'),
  DataPlan('1', 'GB', 3, 400, 'HOT'),
  DataPlan('2.5', 'GB', 2, 500, 'HOT', tag: 'Weekend'),
  DataPlan('3', 'GB', 3, 1200, 'HOT'),
  DataPlan('5', 'GB', 3, 2000, 'HOT'),
  DataPlan('1', 'GB', 7, 420, 'HOT'),
  DataPlan('3', 'GB', 7, 1260, 'HOT'),
  DataPlan('5', 'GB', 7, 2100, 'HOT'),
  DataPlan('1', 'GB', 14, 420, 'HOT', tag: '1GB Night'),
  DataPlan('3', 'GB', 14, 1500, 'HOT'),
  DataPlan('5', 'GB', 14, 2300, 'HOT'),
  DataPlan('10', 'GB', 14, 4000, 'HOT'),
  DataPlan('100', 'MB', 1, 100, 'Daily'),
  DataPlan('200', 'MB', 1, 200, 'Daily'),
  DataPlan('500', 'MB', 1, 350, 'Daily'),
  DataPlan('1', 'GB', 1, 500, 'Daily'),
  DataPlan('2', 'GB', 1, 750, 'Daily'),
  DataPlan('3.2', 'GB', 1, 1000, 'Daily'),
  DataPlan('1', 'GB', 7, 420, 'Weekly'),
  DataPlan('1.5', 'GB', 7, 600, 'Weekly'),
  DataPlan('3', 'GB', 7, 1260, 'Weekly'),
  DataPlan('5', 'GB', 7, 2100, 'Weekly'),
  DataPlan('7', 'GB', 7, 3000, 'Weekly'),
  DataPlan('10', 'GB', 7, 3500, 'Weekly'),
  DataPlan('1', 'GB', 2, 300, 'Weekend', tag: 'Weekend'),
  DataPlan('2.5', 'GB', 2, 500, 'Weekend', tag: 'Weekend'),
  DataPlan('4', 'GB', 2, 800, 'Weekend', tag: 'Weekend'),
  DataPlan('7', 'GB', 2, 1200, 'Weekend', tag: 'Weekend'),
  DataPlan('1.5', 'GB', 30, 1000, 'Monthly'),
  DataPlan('3', 'GB', 30, 1600, 'Monthly'),
  DataPlan('6', 'GB', 30, 2500, 'Monthly'),
  DataPlan('10', 'GB', 30, 3500, 'Monthly'),
  DataPlan('20', 'GB', 30, 5500, 'Monthly'),
  DataPlan('40', 'GB', 30, 10000, 'Monthly'),
  DataPlan('75', 'GB', 30, 15000, 'Monthly'),
  DataPlan('120', 'GB', 30, 22000, 'Monthly'),
];

List<DataPlan> plansFor(String networkId, String bucket) {
  final factor = switch (networkId) {
    'mtn' => 1.0,
    'airtel' => .98,
    'glo' => .92,
    't2' => 1.0,
    'vitel' => 1.05,
    _ => 1.0,
  };
  return _basePlans
      .where((p) => p.bucket == bucket)
      .map((p) => DataPlan(p.size, p.unit, p.days, ((p.price * factor) / 10).round() * 10, p.bucket, tag: p.tag))
      .toList();
}

// ───────────────────────── TV & Internet bundles ─────────────────────────

class Bundle {
  const Bundle(this.name, this.price, {this.detail = ''});
  final String name;
  final int price;
  final String detail;
}

const tvBundles = <String, List<Bundle>>{
  'dstv': [
    Bundle('DStv Padi', 4400, detail: 'Entry bouquet'),
    Bundle('DStv Yanga', 6000, detail: 'Family favourites'),
    Bundle('DStv Confam', 11000, detail: 'Sports & movies'),
    Bundle('DStv Compact', 19000, detail: 'Premium sports'),
    Bundle('DStv Compact Plus', 30000, detail: 'More channels, more sports'),
    Bundle('DStv Premium', 44500, detail: 'Everything on DStv'),
  ],
  'gotv': [
    Bundle('GOtv Smallie', 1900, detail: 'Monthly'),
    Bundle('GOtv Jinja', 3900, detail: 'Monthly'),
    Bundle('GOtv Jolli', 5800, detail: 'Monthly'),
    Bundle('GOtv Max', 8500, detail: 'Monthly'),
    Bundle('GOtv Supa', 11400, detail: 'Monthly'),
  ],
  'startimes_tv': [
    Bundle('Nova', 1900, detail: 'Monthly'),
    Bundle('Basic', 3700, detail: 'Monthly'),
    Bundle('Smart', 5100, detail: 'Monthly'),
    Bundle('Classic', 5500, detail: 'Monthly'),
    Bundle('Super', 9000, detail: 'Monthly'),
  ],
  'showmax': [
    Bundle('Showmax Mobile', 1450, detail: '1 screen · mobile only'),
    Bundle('Showmax Standard', 2900, detail: '2 screens · HD'),
    Bundle('Showmax Pro', 8400, detail: 'Sports + entertainment'),
  ],
};

const internetBundles = <String, List<Bundle>>{
  'spectranet': [
    Bundle('Spectranet 30GB', 10000, detail: '30 days'),
    Bundle('Spectranet 100GB', 18000, detail: '30 days'),
    Bundle('Spectranet 200GB', 30000, detail: '30 days'),
    Bundle('Spectranet Unlimited', 42000, detail: '30 days'),
  ],
  'smile': [
    Bundle('Smile 10GB', 6000, detail: '30 days'),
    Bundle('Smile 40GB', 15000, detail: '30 days'),
    Bundle('Smile 100GB', 26000, detail: '30 days'),
  ],
  'fiberone': [
    Bundle('FiberOne 5Mbps', 20000, detail: '30 days'),
    Bundle('FiberOne 10Mbps', 35000, detail: '30 days'),
    Bundle('FiberOne 20Mbps', 55000, detail: '30 days'),
  ],
  'ipnx': [
    Bundle('ipNX Home 10Mbps', 18000, detail: '30 days'),
    Bundle('ipNX Home 25Mbps', 30000, detail: '30 days'),
  ],
};

// ───────────────────────── International airtime ─────────────────────────

class IntlOperator {
  const IntlOperator(this.name, this.code, this.dial);
  final String name;
  final String code;
  final String dial;
  String get letter => name.substring(0, 1).toUpperCase();

  /// Country flag (assets/flags/ISO2.png) taken from the operator's country prefix.
  String? get flag {
    const m = {'Benin': 'bj', 'Cameroon': 'cm', 'Canada': 'ca', 'China': 'cn', 'DR Congo': 'cd', 'Germany': 'de', 'Ghana': 'gh', 'Guinea-Conakry': 'gn', 'India': 'in', 'Kenya': 'ke', 'South Africa': 'za', 'United Kingdom': 'gb', 'United States': 'us'};
    for (final e in m.entries) {
      if (name.startsWith(e.key)) return 'assets/flags/${e.value}.png';
    }
    return null;
  }
}

const intlOperators = <IntlOperator>[
  IntlOperator('Benin Moov', 'BEMV', '+229'),
  IntlOperator('Cameroon Orange', 'CMOR', '+237'),
  IntlOperator('Canada Bell', 'CANB', '+1'),
  IntlOperator('Canada ChatR', 'CANC', '+1'),
  IntlOperator('Canada Fido', 'CANF', '+1'),
  IntlOperator('Canada Koodo', 'CANK', '+1'),
  IntlOperator('Canada MTS', 'CANM', '+1'),
  IntlOperator('Canada PublicMobile', 'CANP', '+1'),
  IntlOperator('Canada Rogers', 'CANR', '+1'),
  IntlOperator('Canada Solo', 'CANS', '+1'),
  IntlOperator('Canada Virgin', 'CANV', '+1'),
  IntlOperator('Canada Wind', 'CANW', '+1'),
  IntlOperator('China Mobile', 'CHM', '+86'),
  IntlOperator('China Telecom', 'CHTE', '+86'),
  IntlOperator('China Unicom', 'CHU', '+86'),
  IntlOperator('DR Congo Orange', 'DRO', '+243'),
  IntlOperator('Germany O2', 'GE2', '+49'),
  IntlOperator('Germany Vodafone', 'GEV', '+49'),
  IntlOperator('Germany Vybe Mobile', 'GEVY', '+49'),
  IntlOperator('Ghana Tigo', 'GHT', '+233'),
  IntlOperator('Ghana Vodafone', 'GHV', '+233'),
  IntlOperator('Guinea-Conakry Cellcom', 'GCC', '+224'),
  IntlOperator('Guinea-Conakry Orange', 'GUO', '+224'),
  IntlOperator('India Aircel', 'INA', '+91'),
  IntlOperator('India BSNL', 'INB', '+91'),
  IntlOperator('India Idea Cellular', 'INC', '+91'),
  IntlOperator('India MTS', 'INM', '+91'),
  IntlOperator('India Reliance Communications', 'URL', '+91'),
  IntlOperator('India Tata DOCOMO', 'ITD', '+91'),
  IntlOperator('India Telenor', 'INT', '+91'),
  IntlOperator('Kenya Safaricom', 'KES', '+254'),
  IntlOperator('South Africa Vodacom', 'ZAV', '+27'),
  IntlOperator('United Kingdom Lebara', 'UKL', '+44'),
  IntlOperator('United Kingdom Vodafone', 'UKV', '+44'),
  IntlOperator('United States T-Mobile', 'UST', '+1'),
];

// ───────────────────────── Marketplace categories ─────────────────────────

class Category {
  const Category(this.id, this.name, this.icon);
  final String id;
  final String name;
  final PhosphorIconData icon;
}

final categories = <Category>[
  Category('electronics', 'Electronics', PhosphorIconsDuotone.television),
  Category('houses', 'Houses', PhosphorIconsDuotone.buildings),
  Category('lands', 'Lands', PhosphorIconsDuotone.tree),
  Category('furniture', 'Furniture', PhosphorIconsDuotone.armchair),
  Category('fashion', 'Fashion', PhosphorIconsDuotone.tShirt),
  Category('phones', 'Phones & Gadgets', PhosphorIconsDuotone.deviceMobile),
  Category('appliances', 'Home Appliances', PhosphorIconsDuotone.washingMachine),
  Category('kitchen', 'Kitchen', PhosphorIconsDuotone.cookingPot),
  Category('kids', 'Baby & Kids', PhosphorIconsDuotone.baby),
  Category('events', 'Events', PhosphorIconsDuotone.confetti),
  Category('cameras', 'Cameras', PhosphorIconsDuotone.camera),
];

/// Property categories. Never paid for in the app (Terms, section 6).
const propertyCategories = {'houses', 'lands'};

/// Short label for chips and tiles.
String categoryShort(Category c) => switch (c.id) { 'phones' => 'Phones', 'appliances' => 'Appliances', 'kids' => 'Kids', _ => c.name };

Category categoryById(String id) => categories.firstWhere((c) => c.id == id, orElse: () => categories.first);

const ngStates = <String, List<String>>{
  'Lagos': ['Ikeja', 'Lekki', 'Yaba', 'Surulere', 'Victoria Island', 'Ajah', 'Maryland', 'Ikorodu'],
  'Abuja (FCT)': ['Wuse', 'Garki', 'Maitama', 'Gwarinpa', 'Kubwa', 'Jabi'],
  'Rivers': ['Port Harcourt', 'Obio-Akpor', 'Rumuola'],
  'Oyo': ['Ibadan', 'Bodija', 'Challenge'],
  'Enugu': ['Enugu', 'Independence Layout', 'Trans-Ekulu'],
  'Kano': ['Kano', 'Nassarawa', 'Fagge'],
  'Anambra': ['Awka', 'Onitsha', 'Nnewi'],
  'Delta': ['Asaba', 'Warri', 'Effurun'],
};
