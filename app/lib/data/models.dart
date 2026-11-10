import '../core/widgets/common.dart' show Status;

// ───────────────────────── Transactions ─────────────────────────

enum TxKind { airtime, data, electricity, tv, betting, internet, international, topup, withdraw, purchase, sale, refund, cctTopup, subscription, transfer }

extension TxKindX on TxKind {
  String get label => switch (this) {
        TxKind.airtime => 'Airtime',
        TxKind.data => 'Mobile Data',
        TxKind.electricity => 'Electricity',
        TxKind.tv => 'TV',
        TxKind.betting => 'Betting',
        TxKind.internet => 'Internet',
        TxKind.international => 'Intl Airtime',
        TxKind.topup => 'Add Money',
        TxKind.withdraw => 'Withdrawal',
        TxKind.purchase => 'Purchase',
        TxKind.sale => 'Sale',
        TxKind.refund => 'Refund',
        TxKind.cctTopup => 'Added via CCT',
        TxKind.subscription => 'Seller plan',
        TxKind.transfer => 'Transfer',
      };

  bool get isBill => index <= TxKind.international.index;
}

class Tx {
  const Tx({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.credit,
    required this.status,
    required this.date,
    this.details = const {},
    this.token,
  });

  final String id;
  final TxKind kind;
  final String title;
  final String subtitle;
  final num amount;
  final bool credit;
  final Status status;
  final DateTime date;
  final Map<String, String> details;
  final String? token;
}

// ───────────────────────── Marketplace ─────────────────────────

enum Condition { brandNew, likeNew, used, fairlyUsed }

extension ConditionX on Condition {
  String get label => switch (this) {
        Condition.brandNew => 'Brand new',
        Condition.likeNew => 'Like new',
        Condition.used => 'Used',
        Condition.fairlyUsed => 'Fairly used',
      };
}

class Seller {
  const Seller({required this.id, required this.name, this.avatar, required this.rating, required this.reviews, required this.verified, required this.city, required this.joined, required this.sold, this.response = 'Replies within an hour'});
  final String id;
  final String name;
  final String? avatar;
  final double rating;
  final int reviews;
  final bool verified;
  final String city;
  final String joined;
  final int sold;
  final String response;
}

enum ListingStatus { active, sold, draft }

class Listing {
  const Listing({
    required this.id,
    required this.title,
    required this.price,
    required this.negotiable,
    required this.condition,
    required this.categoryId,
    required this.images,
    required this.city,
    required this.area,
    required this.seller,
    required this.description,
    required this.postedAt,
    this.views = 0,
    this.saves = 0,
    this.status = ListingStatus.active,
    this.delivery = true,
    this.pickup = true,
    this.specs = const {},
    this.featured = false,
    this.contactPhone,
    this.boostedUntil,
  });

  final String id;
  final String title;
  final int price;
  final bool negotiable;
  final Condition condition;
  final String categoryId;
  final List<String> images;
  final String city;
  final String area;
  final Seller seller;
  final String description;
  final DateTime postedAt;
  final int views;
  final int saves;
  final ListingStatus status;
  final bool delivery;
  final bool pickup;
  final Map<String, String> specs;
  final bool featured;

  /// Real-estate listings are never paid for on the platform; buyers reach
  /// the seller on this number instead.
  final String? contactPhone;

  bool get isRealEstate => categoryId == 'houses' || categoryId == 'lands' || categoryId == 'realestate';
  bool get isLand => categoryId == 'lands';

  /// "Per year" etc. for rentals and leases, null for outright sales.
  String? get pricePeriod => specs['Rent is paid'] ?? specs['Lease is paid'];
  bool get isRental => specs['Listing type'] == 'For rent' || specs['Listing type'] == 'For lease';

  /// Paid boost from the seller's plan (top of search for 7 days).
  final DateTime? boostedUntil;
  bool get isBoosted => boostedUntil != null && boostedUntil!.isAfter(DateTime.now());
  bool get isFeatured => featured || isBoosted;

  String get location => '$area, $city';

  Listing copyWith({ListingStatus? status, int? price, String? title, String? description, bool? negotiable, Condition? condition, int? views, int? saves, DateTime? boostedUntil}) => Listing(
        id: id,
        title: title ?? this.title,
        price: price ?? this.price,
        negotiable: negotiable ?? this.negotiable,
        condition: condition ?? this.condition,
        categoryId: categoryId,
        images: images,
        city: city,
        area: area,
        seller: seller,
        description: description ?? this.description,
        postedAt: postedAt,
        views: views ?? this.views,
        saves: saves ?? this.saves,
        status: status ?? this.status,
        delivery: delivery,
        pickup: pickup,
        specs: specs,
        featured: featured,
        contactPhone: contactPhone,
        boostedUntil: boostedUntil ?? this.boostedUntil,
      );
}

// ───────────────────────── Orders ─────────────────────────

enum OrderRole { buying, selling }

/// paid (held by Crystal Protect) → shipped → delivered → completed
enum OrderStage { paid, shipped, delivered, completed, cancelled }

class Order {
  const Order({
    required this.id,
    required this.listing,
    required this.role,
    required this.stage,
    required this.total,
    required this.deliveryFee,
    required this.date,
    required this.counterparty,
    required this.method,
    this.address = '',
    this.reviewed = false,
  });
  final String id;
  final Listing listing;
  final OrderRole role;
  final OrderStage stage;
  final int total;
  final int deliveryFee;
  final DateTime date;
  final String counterparty;
  final String method; // Delivery / Pickup
  final String address;
  final bool reviewed;

  Order copyWith({OrderStage? stage, bool? reviewed}) => Order(
        id: id,
        listing: listing,
        role: role,
        stage: stage ?? this.stage,
        total: total,
        deliveryFee: deliveryFee,
        date: date,
        counterparty: counterparty,
        method: method,
        address: address,
        reviewed: reviewed ?? this.reviewed,
      );
}

// ───────────────────────── Chat & notifications ─────────────────────────

class Msg {
  const Msg({required this.text, required this.mine, required this.time, this.offer});
  final String text;
  final bool mine;
  final DateTime time;
  final int? offer;
}

class ChatThread {
  const ChatThread({required this.id, required this.seller, required this.listing, required this.messages, this.unread = 0});
  final String id;
  final Seller seller;
  final Listing listing;
  final List<Msg> messages;
  final int unread;
  Msg get last => messages.last;

  ChatThread copyWith({List<Msg>? messages, int? unread}) => ChatThread(id: id, seller: seller, listing: listing, messages: messages ?? this.messages, unread: unread ?? this.unread);
}

enum NoteKind { bill, order, offer, wallet, promo, security }

class AppNote {
  const AppNote({required this.id, required this.kind, required this.title, required this.body, required this.time, this.read = false});
  final String id;
  final NoteKind kind;
  final String title;
  final String body;
  final DateTime time;
  final bool read;
  AppNote copyWith({bool? read}) => AppNote(id: id, kind: kind, title: title, body: body, time: time, read: read ?? this.read);
}

class Beneficiary {
  const Beneficiary({required this.id, required this.name, required this.value, required this.kind, this.billerId});
  final String id;
  final String name;
  final String value; // phone / meter / smartcard
  final TxKind kind;
  final String? billerId;
}

class Review {
  const Review({required this.author, required this.rating, required this.text, required this.when, this.avatar});
  final String author;
  final int rating;
  final String text;
  final String when;
  final String? avatar;
}
