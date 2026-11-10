import '../core/widgets/common.dart' show Status;
import 'models.dart';

DateTime _ago({int d = 0, int h = 0, int m = 0}) => DateTime.now().subtract(Duration(days: d, hours: h, minutes: m));

// ───────────────────────── Current user ─────────────────────────

const meSeller = Seller(
  id: 'me',
  name: 'Victory',
  rating: 4.9,
  reviews: 18,
  verified: true,
  city: 'Lagos',
  joined: 'Joined Mar 2026',
  sold: 12,
);

class UserProfile {
  const UserProfile({required this.name, required this.legalName, required this.phone, required this.email, required this.city, required this.tier});
  final String name;
  /// Name on the verified ID (KYC). Payout bank accounts must match it.
  final String legalName;
  final String phone;
  final String email;
  final String city;
  final int tier;
}

const mockProfile = UserProfile(name: 'Victory', legalName: 'Victory Bassey', phone: '08030000001', email: 'victory@crystalpay.app', city: 'Lagos', tier: 2);

// ───────────────────────── Sellers ─────────────────────────

const sChijioke = Seller(id: 's1', name: 'Chijioke Obi', avatar: 'assets/images/avatars/chijioke.jpg', rating: 4.8, reviews: 126, verified: true, city: 'Lagos', joined: 'Joined Jan 2025', sold: 214);
const sChinelo = Seller(id: 's2', name: 'Chinelo Adeyemi', avatar: 'assets/images/avatars/chinelo.jpg', rating: 4.9, reviews: 203, verified: true, city: 'Abuja', joined: 'Joined Aug 2024', sold: 342, response: 'Replies within minutes');
const sJohn = Seller(id: 's3', name: 'John Ekpo', avatar: 'assets/images/avatars/john.jpg', rating: 4.6, reviews: 58, verified: false, city: 'Port Harcourt', joined: 'Joined Nov 2025', sold: 71);
const sEmeka = Seller(id: 's4', name: 'Emeka Nwosu', avatar: 'assets/images/avatars/lender.jpg', rating: 4.7, reviews: 91, verified: true, city: 'Enugu', joined: 'Joined Jun 2025', sold: 133);
const sTola = Seller(id: 's5', name: 'Tola Bakare', rating: 4.5, reviews: 34, verified: false, city: 'Ibadan', joined: 'Joined Feb 2026', sold: 40);
const sAmaka = Seller(id: 's6', name: 'Amaka Eze', rating: 4.9, reviews: 77, verified: true, city: 'Lagos', joined: 'Joined Oct 2025', sold: 102, response: 'Replies within minutes');

final sellers = [sChijioke, sChinelo, sJohn, sEmeka, sTola, sAmaka];

// ───────────────────────── Listings ─────────────────────────

String _p(String n) => 'assets/images/products/$n.jpg';

final mockListings = <Listing>[
  Listing(
    id: 're1', title: '4-bedroom duplex with BQ, Lekki Phase 1', price: 145000000, negotiable: true, condition: Condition.used, categoryId: 'houses',
    images: [_p('house_1'), _p('building_1')], city: 'Lagos', area: 'Lekki', seller: sEmeka, postedAt: _ago(h: 5), views: 530, saves: 47, featured: true, delivery: false, pickup: false,
    contactPhone: '08031234567',
    description: 'Well finished 4-bedroom duplex with a boys quarters in a gated, serviced estate. Tarred roads, 24-hour security and steady power. Viewing by appointment.',
    specs: {'Listing type': 'For sale', 'Property type': 'House', 'Bedrooms': '4', 'Bathrooms': '5', 'Size': '420 sqm', 'Furnishing': 'Unfurnished', 'Parking': 'Yes', 'Title / documents': 'C of O'},
  ),
  Listing(
    id: 're3', title: '3 Bedroom Apartment, Victoria Island', price: 4500000, negotiable: true, condition: Condition.used, categoryId: 'houses',
    images: [_p('apartment_1'), _p('building_1')], city: 'Lagos', area: 'Victoria Island', seller: sChinelo, postedAt: _ago(h: 2), views: 342, saves: 31, delivery: false, pickup: false,
    contactPhone: '08094445566',
    description: 'Spacious serviced 3-bedroom apartment with a fitted kitchen, 24-hour power, lift and secure parking. Close to Adeola Odeku. One year rent upfront, plus agency and legal fees.',
    specs: {'Listing type': 'For rent', 'Rent is paid': 'Per year', 'Property type': 'Apartment / flat', 'Bedrooms': '3', 'Bathrooms': '3', 'Size': '180 sqm', 'Furnishing': 'Semi-furnished', 'Parking': 'Yes', 'Title / documents': 'C of O'},
  ),
  Listing(
    id: 're4', title: '2 Bedroom Flat in a New Block, Lekki', price: 85000000, negotiable: true, condition: Condition.used, categoryId: 'houses',
    images: [_p('building_1'), _p('apartment_1')], city: 'Lagos', area: 'Lekki', seller: sJohn, postedAt: _ago(d: 2), views: 208, saves: 17, delivery: false, pickup: false,
    contactPhone: '09055556677',
    description: 'Newly built 2-bedroom flat in a gated block of six units. Glass balconies, all rooms en suite, ample parking and good road network.',
    specs: {'Listing type': 'For sale', 'Property type': 'Apartment / flat', 'Bedrooms': '2', 'Bathrooms': '3', 'Size': '140 sqm', 'Furnishing': 'Unfurnished', 'Parking': 'Yes', 'Title / documents': "Governor's consent"},
  ),
  Listing(
    id: 're5', title: '1 Acre of Farmland, Epe', price: 12000000, negotiable: true, condition: Condition.used, categoryId: 'lands',
    images: [_p('farmland_1')], city: 'Lagos', area: 'Epe', seller: sEmeka, postedAt: _ago(d: 3), views: 156, saves: 12, delivery: false, pickup: false,
    contactPhone: '08033334455',
    description: 'One acre of dry, fertile farmland with an access path from the main road. Suitable for crops, poultry or a future estate. Survey available.',
    specs: {'Listing type': 'For sale', 'Land use': 'Agricultural', 'Plot size': '4,047 sqm', 'Fenced': 'No', 'Access road': 'Untarred', 'Topography': 'Dry land', 'Title / documents': 'Survey plan'},
  ),
  Listing(
    id: 're2', title: '600 sqm residential land, Ibeju-Lekki', price: 18000000, negotiable: true, condition: Condition.used, categoryId: 'lands',
    images: [_p('land_1')], city: 'Lagos', area: 'Ajah', seller: sTola, postedAt: _ago(d: 1), views: 291, saves: 22, delivery: false, pickup: false,
    contactPhone: '08057654321',
    description: 'Dry, fenced plot in a fast-developing area close to the new airport road. Survey and deed available for inspection. Buyer to verify documents with their own lawyer.',
    specs: {'Listing type': 'For sale', 'Land use': 'Residential', 'Plot size': '600 sqm', 'Fenced': 'Yes', 'Access road': 'Untarred', 'Topography': 'Dry land', 'Title / documents': 'Deed of assignment'},
  ),
  Listing(
    id: 'l1', title: 'iPhone X 64GB — clean, battery 87%', price: 185000, negotiable: true, condition: Condition.likeNew, categoryId: 'phones',
    images: [_p('phone')], city: 'Lagos', area: 'Ikeja', seller: sChijioke, postedAt: _ago(h: 3), views: 412, saves: 38, featured: true,
    description: 'Neatly used iPhone X, no cracks, Face ID working perfectly. Comes with original charger and a protective case. Factory unlocked, works on all networks. Reason for selling: upgraded.',
    specs: {'Storage': '64GB', 'Battery health': '87%', 'Network': 'Unlocked', 'Colour': 'Space grey'},
  ),
  Listing(
    id: 'l2', title: 'DSLR camera with 18–55mm lens & bag', price: 320000, negotiable: true, condition: Condition.used, categoryId: 'cameras',
    images: [_p('camera')], city: 'Abuja', area: 'Wuse', seller: sChinelo, postedAt: _ago(h: 9), views: 268, saves: 31,
    description: 'Great starter DSLR for photography and video. Includes kit lens, two batteries, charger, 32GB card and padded camera bag. Shutter count under 12,000.',
    specs: {'Lens': '18–55mm', 'Shutter count': '12k', 'Includes': 'Bag, 2 batteries, SD card'},
  ),
  Listing(
    id: 'l3', title: 'Portable Bluetooth boombox speaker', price: 120000, negotiable: false, condition: Condition.brandNew, categoryId: 'electronics',
    images: [_p('speaker')], city: 'Lagos', area: 'Lekki', seller: sAmaka, postedAt: _ago(h: 5), views: 530, saves: 64, featured: true,
    description: 'Brand new, sealed in box. Waterproof, 24-hour battery, deep bass and party-ready. Can also charge your phone.',
    specs: {'Battery': 'Up to 24 hours', 'Water rating': 'IPX7', 'Connectivity': 'Bluetooth 5.1'},
  ),
  Listing(
    id: 'l4', title: 'Modern accent armchair — cream', price: 95000, negotiable: true, condition: Condition.likeNew, categoryId: 'furniture',
    images: [_p('chair')], city: 'Lagos', area: 'Victoria Island', seller: sAmaka, postedAt: _ago(d: 1), views: 190, saves: 22,
    description: 'Comfortable cream accent chair with solid wooden legs. Bought six months ago, used in a guest room. No stains or tears.',
    specs: {'Material': 'Fabric & solid wood', 'Colour': 'Cream', 'Dimensions': '78 × 80 × 85 cm'},
  ),
  Listing(
    id: 'l5', title: 'Royal blue satin party dress (size 12)', price: 18500, negotiable: true, condition: Condition.likeNew, categoryId: 'fashion',
    images: [_p('dress')], city: 'Enugu', area: 'Independence Layout', seller: sEmeka, postedAt: _ago(d: 1, h: 4), views: 143, saves: 17,
    description: 'Worn once to a wedding. Elegant wrap bodice with flowing skirt, fully lined. Dry-cleaned and ready to wear.',
    specs: {'Size': 'UK 12', 'Colour': 'Royal blue', 'Fabric': 'Satin'},
  ),
  Listing(
    id: 'l6', title: '55-inch 4K Smart TV with wall mount', price: 340000, negotiable: true, condition: Condition.brandNew, categoryId: 'electronics',
    images: ['assets/images/products/tv_2.jpg', _p('tv')], city: 'Lagos', area: 'Yaba', seller: sChijioke, postedAt: _ago(d: 2), views: 689, saves: 91, featured: true,
    description: 'Brand new 55" 4K UHD smart TV with built-in streaming apps and voice remote. One-year warranty. Wall bracket included. Free delivery within Lagos mainland.',
    specs: {'Screen': '55 inch 4K UHD', 'Smart': 'Yes', 'Warranty': '12 months', 'Ports': '3× HDMI, 2× USB'},
  ),
  Listing(
    id: 'l7', title: '18-inch standing fan — 3 speeds', price: 28000, negotiable: false, condition: Condition.brandNew, categoryId: 'appliances',
    images: ['assets/images/products/fan_2.jpg', _p('fan')], city: 'Port Harcourt', area: 'Rumuola', seller: sJohn, postedAt: _ago(h: 20), views: 204, saves: 15,
    description: 'Quiet, powerful standing fan with adjustable height and oscillation. Perfect for the bedroom or living room.',
    specs: {'Size': '18 inch', 'Speeds': '3', 'Oscillation': 'Yes'},
  ),
  Listing(
    id: 'l8', title: 'Steam iron — non-stick soleplate', price: 14500, negotiable: true, condition: Condition.brandNew, categoryId: 'appliances',
    images: ['assets/images/products/iron_2.jpg', _p('iron')], city: 'Ibadan', area: 'Bodija', seller: sTola, postedAt: _ago(d: 3), views: 98, saves: 8,
    description: 'Powerful steam iron with variable temperature and self-clean function. New in box.',
    specs: {'Power': '2200W', 'Soleplate': 'Non-stick ceramic'},
  ),
  Listing(
    id: 'l9', title: 'Electric kettle 1.7L — stainless steel', price: 11000, negotiable: false, condition: Condition.brandNew, categoryId: 'kitchen',
    images: [_p('kettle_steel')], city: 'Lagos', area: 'Surulere', seller: sAmaka, postedAt: _ago(d: 2, h: 6), views: 121, saves: 9,
    description: 'Cordless stainless steel electric kettle with auto shut-off and boil-dry protection.',
    specs: {'Capacity': '1.7 litres', 'Power': '2200W'},
  ),
  Listing(
    id: 'l10', title: '25L digital microwave oven', price: 72000, negotiable: true, condition: Condition.likeNew, categoryId: 'kitchen',
    images: ['assets/images/products/microwave_2.jpg', _p('microwave')], city: 'Abuja', area: 'Garki', seller: sChinelo, postedAt: _ago(d: 4), views: 176, saves: 19,
    description: 'Used for three months. 25-litre digital microwave with 8 auto-cook menus, defrost and child lock. Works perfectly.',
    specs: {'Capacity': '25 L', 'Power': '900W', 'Controls': 'Digital'},
  ),
  Listing(
    id: 'l11', title: '2-slice stainless toaster', price: 12000, negotiable: true, condition: Condition.brandNew, categoryId: 'kitchen',
    images: ['assets/images/products/toaster_2.jpg', _p('toaster')], city: 'Enugu', area: 'Trans-Ekulu', seller: sEmeka, postedAt: _ago(d: 5), views: 64, saves: 5,
    description: 'Brushed stainless 2-slice toaster with 6 browning levels, defrost and reheat. Removable crumb tray.',
    specs: {'Slots': '2', 'Browning levels': '6'},
  ),
  Listing(
    id: 'l12', title: 'Bagless vacuum cleaner 2000W', price: 58000, negotiable: true, condition: Condition.fairlyUsed, categoryId: 'appliances',
    images: ['assets/images/products/vacuum_2.jpg', _p('vacuum')], city: 'Lagos', area: 'Ajah', seller: sChijioke, postedAt: _ago(d: 6), views: 87, saves: 7,
    description: 'Powerful bagless vacuum with washable filter and three attachments. Fairly used but in excellent working condition.',
    specs: {'Power': '2000W', 'Type': 'Bagless', 'Cord': '5 m'},
  ),
  Listing(
    id: 'l13', title: 'High-speed blender 1.5L', price: 26500, negotiable: false, condition: Condition.brandNew, categoryId: 'kitchen',
    images: ['assets/images/products/blender_2.jpg', _p('blender')], city: 'Rivers', area: 'Obio-Akpor', seller: sJohn, postedAt: _ago(d: 1, h: 2), views: 154, saves: 12,
    description: 'Crush ice, blend smoothies and make soups in seconds. 1.5L jar, stainless blades and a 1-year warranty.',
    specs: {'Capacity': '1.5 L', 'Power': '1000W', 'Warranty': '12 months'},
  ),
  Listing(
    id: 'l14', title: 'Event canopy tent 3×3 m (foldable)', price: 145000, negotiable: true, condition: Condition.brandNew, categoryId: 'events',
    images: [_p('tent')], city: 'Lagos', area: 'Ikorodu', seller: sAmaka, postedAt: _ago(d: 1, h: 8), views: 96, saves: 11,
    description: 'Heavy-duty folding canopy for outdoor events, markets and parties. Waterproof, UV-resistant top. Carry bag included.',
    specs: {'Size': '3 × 3 m', 'Frame': 'Aluminium', 'Top': 'Waterproof'},
  ),
  Listing(
    id: 'l15', title: 'Plush teddy bear with scarf (60 cm)', price: 7500, negotiable: false, condition: Condition.brandNew, categoryId: 'kids',
    images: [_p('teddy')], city: 'Ibadan', area: 'Challenge', seller: sTola, postedAt: _ago(d: 2, h: 1), views: 72, saves: 6,
    description: 'Super soft hypoallergenic teddy bear — perfect gift for birthdays and baby showers.',
    specs: {'Height': '60 cm', 'Material': 'Plush'},
  ),
  Listing(
    id: 'l16', title: 'Cordless electric kettle 1.8L', price: 9800, negotiable: true, condition: Condition.likeNew, categoryId: 'kitchen',
    images: ['assets/images/products/kettle_2.jpg', _p('kettle')], city: 'Lagos', area: 'Maryland', seller: sChijioke, postedAt: _ago(d: 7), views: 59, saves: 4,
    description: 'Barely used cordless kettle with auto shut-off. Heats up in about 3 minutes.',
    specs: {'Capacity': '1.8 litres', 'Power': '2000W'},
  ),
];

/// Listings that belong to the signed-in user.
final myMockListings = <Listing>[
  Listing(
    id: 'm1', title: 'Cordless stick vacuum — rechargeable', price: 64000, negotiable: true, condition: Condition.likeNew, categoryId: 'appliances',
    images: ['assets/images/products/vacuum_2.jpg'], city: 'Lagos', area: 'Yaba', seller: meSeller, postedAt: _ago(d: 3), views: 118, saves: 9,
    description: 'Lightweight cordless vacuum, 45-minute runtime. Includes wall mount and two heads.',
    specs: {'Runtime': '45 min'},
  ),
  Listing(
    id: 'm2', title: 'Small desk fan — USB powered', price: 6500, negotiable: false, condition: Condition.brandNew, categoryId: 'appliances',
    images: ['assets/images/products/fan_2.jpg'], city: 'Lagos', area: 'Yaba', seller: meSeller, postedAt: _ago(d: 9), views: 44, saves: 2, status: ListingStatus.sold,
    description: 'Compact USB desk fan, whisper quiet.',
  ),
];

// ───────────────────────── Transactions ─────────────────────────

String _ref(int n) => 'CP${(260000000 + n * 7919).toString()}';

final mockTxs = <Tx>[
  Tx(id: 't1', kind: TxKind.airtime, title: 'Airtime', subtitle: 'GLO · 0803 000 0001', amount: 1500, credit: false, status: Status.success, date: _ago(h: 2, m: 14), details: {'Network': 'GLO', 'Recipient': '08030000001'}),
  Tx(id: 't2', kind: TxKind.topup, title: 'Add Money', subtitle: 'Bank transfer', amount: 25000, credit: true, status: Status.success, date: _ago(h: 5), details: {'Method': 'Bank transfer'}),
  Tx(id: 't3', kind: TxKind.electricity, title: 'Electricity', subtitle: 'Enugu Electricity · Prepaid', amount: 5000, credit: false, status: Status.success, date: _ago(d: 1, h: 3), token: '4827 1093 5561 7740 2218', details: {'Provider': 'Enugu Electricity', 'Meter': '45031987266', 'Type': 'Prepaid', 'Units': '71.4 kWh'}),
  Tx(id: 't4', kind: TxKind.data, title: 'Mobile Data', subtitle: 'MTN · 1GB 3 Days Plan', amount: 400, credit: false, status: Status.success, date: _ago(d: 1, h: 9), details: {'Network': 'MTN', 'Recipient': '08031234567', 'Bundle': '1GB 3 Days Plan'}),
  Tx(id: 't5', kind: TxKind.purchase, title: 'Purchase', subtitle: 'Event canopy tent 3×3 m', amount: 148500, credit: false, status: Status.pending, date: _ago(d: 1, h: 20), details: {'Item': 'Event canopy tent 3×3 m', 'Seller': 'Amaka Eze'}),
  Tx(id: 't6', kind: TxKind.betting, title: 'Betting', subtitle: 'Bangbet · 30482291', amount: 100, credit: false, status: Status.success, date: _ago(d: 2, h: 1), details: {'Provider': 'Bangbet', 'User ID': '30482291'}),
  Tx(id: 't7', kind: TxKind.sale, title: 'Sale', subtitle: 'Small desk fan — USB powered', amount: 6500, credit: true, status: Status.success, date: _ago(d: 2, h: 7), details: {'Item': 'Small desk fan — USB powered', 'Buyer': 'John Ekpo'}),
  Tx(id: 't8', kind: TxKind.airtime, title: 'Airtime', subtitle: 'GLO · 0803 000 0001', amount: 3000, credit: false, status: Status.success, date: _ago(d: 3, h: 4), details: {'Network': 'GLO'}),
  Tx(id: 't9', kind: TxKind.tv, title: 'TV', subtitle: 'DStv Padi · 7000 123 456', amount: 4400, credit: false, status: Status.success, date: _ago(d: 4), details: {'Provider': 'DStv', 'Bouquet': 'DStv Padi', 'Smartcard': '7000123456'}),
  Tx(id: 't10', kind: TxKind.data, title: 'Mobile Data', subtitle: 'GLO · 5GB 7 Days Plan', amount: 1930, credit: false, status: Status.failed, date: _ago(d: 5, h: 2), details: {'Network': 'GLO', 'Reason': 'Network provider unavailable. Wallet refunded.'}),
  Tx(id: 't11', kind: TxKind.refund, title: 'Refund', subtitle: 'Mobile Data · GLO', amount: 1930, credit: true, status: Status.success, date: _ago(d: 5, h: 1), details: {'Reason': 'Failed data purchase'}),
  Tx(id: 't12', kind: TxKind.airtime, title: 'Airtime', subtitle: 'MTN · 0803 123 4567', amount: 300, credit: false, status: Status.success, date: _ago(d: 6, h: 6)),
  Tx(id: 't13', kind: TxKind.topup, title: 'Add Money', subtitle: 'Debit card', amount: 50000, credit: true, status: Status.success, date: _ago(d: 8), details: {'Method': 'Debit card'}),
  Tx(id: 't14', kind: TxKind.internet, title: 'Internet', subtitle: 'Smile · 40GB', amount: 15000, credit: false, status: Status.success, date: _ago(d: 9), details: {'Provider': 'Smile', 'Plan': 'Smile 40GB'}),
  Tx(id: 't15', kind: TxKind.airtime, title: 'Airtime', subtitle: 'GLO · 0803 000 0001', amount: 600, credit: false, status: Status.success, date: _ago(d: 10, h: 3)),
  Tx(id: 't16', kind: TxKind.electricity, title: 'Electricity', subtitle: 'Eko Electricity · Prepaid', amount: 3000, credit: false, status: Status.success, date: _ago(d: 12), token: '1198 5502 7731 0946 3358', details: {'Provider': 'Eko Electricity', 'Meter': '45000012345', 'Type': 'Prepaid'}),
  Tx(id: 't17', kind: TxKind.withdraw, title: 'Withdrawal', subtitle: 'To GTBank •• 4417', amount: 30000, credit: false, status: Status.success, date: _ago(d: 14), details: {'Bank': 'GTBank', 'Account': '•••• 4417'}),
  Tx(id: 't18', kind: TxKind.airtime, title: 'Airtime', subtitle: 'GLO · 0803 000 0001', amount: 1000, credit: false, status: Status.success, date: _ago(d: 16)),
  Tx(id: 't19', kind: TxKind.sale, title: 'Sale', subtitle: 'Cordless iron', amount: 11000, credit: true, status: Status.success, date: _ago(d: 18)),
  Tx(id: 't20', kind: TxKind.airtime, title: 'Airtime', subtitle: 'GLO · 0803 000 0001', amount: 140, credit: false, status: Status.success, date: _ago(d: 22)),
].map((t) => t).toList();

String refFor(int i) => _ref(i);

// ───────────────────────── Beneficiaries ─────────────────────────

const mockBeneficiaries = <Beneficiary>[
  Beneficiary(id: 'b1', name: 'My number', value: '08030000001', kind: TxKind.airtime, billerId: 'glo'),
  Beneficiary(id: 'b2', name: 'Mum', value: '08031234567', kind: TxKind.airtime, billerId: 'mtn'),
  Beneficiary(id: 'b3', name: 'Tunde (office)', value: '09012345678', kind: TxKind.airtime, billerId: 'airtel'),
  Beneficiary(id: 'b4', name: 'Home meter', value: '45031987266', kind: TxKind.electricity, billerId: 'enugu'),
  Beneficiary(id: 'b5', name: 'Shop meter', value: '45000012345', kind: TxKind.electricity, billerId: 'eko'),
  Beneficiary(id: 'b6', name: 'Living room DStv', value: '7000123456', kind: TxKind.tv, billerId: 'dstv'),
  Beneficiary(id: 'b7', name: 'My Bangbet', value: '30482291', kind: TxKind.betting, billerId: 'bangbet'),
];

// ───────────────────────── Orders ─────────────────────────

Listing _byId(String id) => mockListings.firstWhere((l) => l.id == id);

final mockOrders = <Order>[
  Order(id: 'CP-48213', listing: _byId('l14'), role: OrderRole.buying, stage: OrderStage.shipped, total: 148500, deliveryFee: 3500, date: _ago(d: 1, h: 20), counterparty: 'Amaka Eze', method: 'Delivery', address: '12 Admiralty Way, Lekki Phase 1, Lagos'),
  Order(id: 'CP-47190', listing: _byId('l9'), role: OrderRole.buying, stage: OrderStage.completed, total: 12500, deliveryFee: 1500, date: _ago(d: 12), counterparty: 'Amaka Eze', method: 'Delivery', address: '12 Admiralty Way, Lekki Phase 1, Lagos', reviewed: true),
  Order(id: 'CP-48302', listing: myMockListings[0], role: OrderRole.selling, stage: OrderStage.paid, total: 64000, deliveryFee: 0, date: _ago(h: 6), counterparty: 'Ngozi Peters', method: 'Pickup', address: 'Yaba, Lagos'),
  Order(id: 'CP-46851', listing: myMockListings[1], role: OrderRole.selling, stage: OrderStage.completed, total: 6500, deliveryFee: 0, date: _ago(d: 2, h: 7), counterparty: 'John Ekpo', method: 'Pickup', address: 'Yaba, Lagos'),
];

// ───────────────────────── Chats ─────────────────────────

final mockChats = <ChatThread>[
  ChatThread(
    id: 'c1',
    seller: sAmaka,
    listing: _byId('l14'),
    unread: 1,
    messages: [
      Msg(text: 'Hi, is the canopy tent still available?', mine: true, time: _ago(d: 2, h: 1)),
      Msg(text: 'Hello! Yes it is 😊 Brand new, still in the pack.', mine: false, time: _ago(d: 2)),
      Msg(text: 'Can you do ₦140,000?', mine: true, time: _ago(d: 1, h: 23), offer: 140000),
      Msg(text: 'I can do ₦145,000 final. It comes with the carry bag.', mine: false, time: _ago(d: 1, h: 22)),
      Msg(text: 'Your order is on its way — rider will call before arriving.', mine: false, time: _ago(h: 1, m: 10)),
    ],
  ),
  ChatThread(
    id: 'c2',
    seller: sChijioke,
    listing: _byId('l1'),
    unread: 0,
    messages: [
      Msg(text: 'Good afternoon, what is the battery health on this iPhone X?', mine: true, time: _ago(h: 6)),
      Msg(text: '87%, and Face ID works perfectly. I can send a video if you like.', mine: false, time: _ago(h: 5, m: 40)),
    ],
  ),
  ChatThread(
    id: 'c3',
    seller: sChinelo,
    listing: _byId('l2'),
    unread: 2,
    messages: [
      Msg(text: 'Hello, can I see the camera in person before paying?', mine: true, time: _ago(d: 1, h: 3)),
      Msg(text: 'Of course. We can meet at Wuse Market this weekend.', mine: false, time: _ago(d: 1, h: 2)),
      Msg(text: 'Saturday 11am works for me.', mine: false, time: _ago(d: 1, h: 2)),
    ],
  ),
];

// ───────────────────────── Notifications ─────────────────────────

final mockNotes = <AppNote>[
  AppNote(id: 'n1', kind: NoteKind.order, title: 'Your order is on its way', body: 'Amaka shipped “Event canopy tent 3×3 m”. Track it in Orders.', time: _ago(h: 1, m: 10)),
  AppNote(id: 'n2', kind: NoteKind.offer, title: 'New offer on your listing', body: 'Ngozi bought “Cordless stick vacuum”. Prepare it for pickup.', time: _ago(h: 6)),
  AppNote(id: 'n3', kind: NoteKind.wallet, title: 'Wallet credited', body: '₦25,000.00 has been added to your wallet.', time: _ago(h: 5), read: true),
  AppNote(id: 'n4', kind: NoteKind.bill, title: 'Electricity token ready', body: 'Your Enugu Electricity token for ₦5,000.00 is ready.', time: _ago(d: 1, h: 3), read: true),
  AppNote(id: 'n5', kind: NoteKind.promo, title: 'Earn cashback on airtime', body: 'Get up to 1.4% back every time you buy airtime this week.', time: _ago(d: 2), read: true),
  AppNote(id: 'n6', kind: NoteKind.security, title: 'New sign-in detected', body: 'Your account was signed in on a new Android device.', time: _ago(d: 4), read: true),
];

// ───────────────────────── Reviews ─────────────────────────

const mockReviews = <Review>[
  Review(author: 'Ngozi P.', rating: 5, text: 'Item exactly as described, packaged well and arrived early. Would buy again.', when: '2 weeks ago', avatar: 'assets/images/avatars/chinelo.jpg'),
  Review(author: 'Tunde A.', rating: 5, text: 'Very honest seller. Quick replies and smooth payment through Crystal Pay.', when: '1 month ago', avatar: 'assets/images/avatars/john.jpg'),
  Review(author: 'Bola K.', rating: 4, text: 'Good product. Delivery took one extra day but the seller kept me updated.', when: '2 months ago'),
];

const mockFaqs = <(String, String)>[
  ('How does buyer protection work?', 'When you pay for an item, your money is held securely by Crystal Pay. The seller is only paid after you confirm the item arrived as described.'),
  ('How long do bill payments take?', 'Airtime, data, TV and betting top-ups are instant. Electricity tokens are usually delivered within seconds.'),
  ('My bill payment failed. What now?', 'Failed payments are refunded to your wallet automatically, usually instantly. If you do not see the refund within 15 minutes, contact support.'),
  ('How do I list an item for sale?', 'Tap the + button at the centre of the bottom bar, add photos and details, set your price and publish. Listing is free.'),
  ('Are there any fees for selling?', 'Listing is free. A small service fee is deducted from the sale price only when your item sells.'),
  ('How do I withdraw my earnings?', 'Go to Wallet → Withdraw and choose your bank account. Withdrawals usually arrive within minutes.'),
];
