/// Seller plans. Sellers must hold an active plan to post items.
/// Prices, limits and fees here are the front-end source of truth until the
/// billing backend takes over (see docs/SELLER_PLANS.md).
enum PlanId { basic, pro, business }

class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.tagline,
    required this.price,
    required this.listingLimit,
    required this.boostsPerMonth,
    required this.serviceFeePct,
    required this.features,
    this.popular = false,
  });

  final PlanId id;
  final String name;
  final String tagline;

  /// Naira per month.
  final int price;

  /// Active listings allowed at once (sold and draft items do not count).
  final int listingLimit;
  final int boostsPerMonth;

  /// Deducted from the seller's payout on a completed sale.
  final double serviceFeePct;
  final List<String> features;
  final bool popular;
}

const plans = <Plan>[
  Plan(
    id: PlanId.basic,
    name: 'Basic',
    tagline: 'For people selling a few things',
    price: 3000,
    listingLimit: 5,
    boostsPerMonth: 0,
    serviceFeePct: 5,
    features: [
      'Up to 5 active listings',
      'Up to 5 photos per listing',
      'Chat, offers and Crystal Protect payments',
      'Real estate listings (counts toward your limit)',
      '5% service fee on each sale',
      'Standard payouts to your verified bank account',
      'In-app help centre and live chat',
    ],
  ),
  Plan(
    id: PlanId.pro,
    name: 'Pro',
    tagline: 'For regular sellers who want more reach',
    price: 7500,
    listingLimit: 25,
    boostsPerMonth: 3,
    serviceFeePct: 3.5,
    popular: true,
    features: [
      'Up to 25 active listings',
      '3 listing boosts a month (top of search for 7 days)',
      '3.5% service fee on each sale',
      'Seller insights: views, saves, offers and chats per listing',
      '"Pro seller" badge on your profile and listings',
      'Priority support replies',
      'Everything in Basic',
    ],
  ),
  Plan(
    id: PlanId.business,
    name: 'Business',
    tagline: 'For shops, agents and high-volume sellers',
    price: 15000,
    listingLimit: 100,
    boostsPerMonth: 10,
    serviceFeePct: 2,
    features: [
      'Up to 100 active listings',
      '10 listing boosts a month',
      '2% service fee on each sale',
      'Your own storefront page with a shareable link',
      'Same-day payouts',
      'Sales and earnings report each month',
      'Dedicated support contact',
      'Everything in Pro',
    ],
  ),
];

Plan planById(PlanId id) => plans.firstWhere((p) => p.id == id);

/// Plan billing period used across the app.
const kPlanPeriodDays = 30;
