import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/plans.dart';
import '../../core/utils/format.dart';

class _Sec {
  const _Sec(this.title, this.body);
  final String title;
  final List<String> body;
}

/// Working draft of the Terms and Privacy Policy. Have a Nigerian lawyer
/// review before launch; the real-estate and seller-plan clauses reflect the
/// product rules and must stay in sync with the app.
final _terms = <_Sec>[
  const _Sec('1. About Crystal Pay', [
    'Crystal Pay lets you pay bills (airtime, data, electricity, TV, betting wallets and internet), hold a Naira wallet, and buy or sell items with other users.',
    'You must be 18 or older and give accurate details. Some features need identity verification (NIN, BVN or international passport).',
  ]),
  const _Sec('2. Your wallet', [
    'Your wallet balance is held in Naira. You can add money by card, bank transfer or Crystal Cat (CCT), which is converted to Naira at the rate shown before you confirm.',
    'Withdrawals go only to a bank account in your own verified name. CCT can be used to fund your wallet but cannot be withdrawn or sold through Crystal Pay.',
    'You can send money to other Crystal Pay users by username, phone number or email. Transfers between wallets are instant and cannot be reversed, so check the name before you confirm.',
    'Keep your PIN and password private. Crystal Pay will never ask for them.',
  ]),
  const _Sec('3. Bill payments', [
    'Bill payments are completed from your wallet. If a payment fails, the amount is returned to your wallet.',
  ]),
  const _Sec('4. Buying and selling items', [
    'Ordinary items (phones, electronics, appliances, furniture, fashion and similar) can be paid for on Crystal Pay. Your payment is held by Crystal Protect and released to the seller after you confirm you received the item.',
    'Sellers must describe items honestly, use their own photos and must not list prohibited, counterfeit or stolen goods.',
  ]),
  _Sec('5. Seller plans', [
    'Selling needs an active seller plan, billed every $kPlanPeriodDays days from your wallet: ${plans.map((p) => '${p.name} ${money(p.price)} (${p.listingLimit} live listings)').join(', ')}.',
    'Your plan sets how many listings can be live at once. If your plan ends, your listings are hidden until you renew. Plan fees are not refundable once a period has started.',
    'A service fee, shown on your plan, is taken from the seller payout when a Crystal Protect sale completes.',
  ]),
  const _Sec('6. Real estate and land', [
    'Real estate and land listings (houses, apartments, land, commercial property and shortlets) are advertisements only. They cannot be bought, rented, reserved or paid for on Crystal Pay.',
    'Buyers and tenants must contact the seller by call, WhatsApp or chat and agree all terms, inspection and payment directly with the seller, outside Crystal Pay.',
    'Crystal Pay is not a party to any property deal. It does not hold, protect, refund or guarantee any property payment, and does not verify ownership or documents. Always inspect in person, verify documents with a lawyer and a surveyor, and never pay before doing so.',
    'Sellers must be the owner or authorised agent, must not request payment through the app, and must not post misleading prices, photos or documents. Listings that break these rules are removed and the account may be suspended.',
  ]),
  const _Sec('7. Prohibited use', [
    'No fraud, money laundering, harassment, or using someone else\'s identity or bank account. We may suspend accounts and report suspected crime to the authorities.',
  ]),
  const _Sec('8. Liability', [
    'Crystal Pay is not responsible for deals made outside the platform, including every real estate transaction. Our liability for other services is limited to the amount of the transaction concerned.',
  ]),
  const _Sec('9. Changes', [
    'We may update these terms. Continuing to use Crystal Pay after a change means you accept it.',
  ]),
];

final _privacy = <_Sec>[
  const _Sec('What we collect', [
    'Account details (email, name, phone number, city, profile photo), the ID number you submit for verification, wallet and transaction records, listings and chats.',
  ]),
  const _Sec('How we use it', [
    'To run your account and payments, verify your identity, prevent fraud, support you, and send service messages.',
    'Your ID number is used only for verification and is not shown to other users.',
  ]),
  const _Sec('What other users see', [
    'Your name, photo, city, verified tick and listings.',
    'On a real estate listing, buyers can also see the phone number you registered with, so they can reach you outside the platform. Do not post a real estate listing if you do not want this number shown.',
  ]),
  const _Sec('Sharing', [
    'We share data only with payment, bill and identity-verification partners that process it for us, and with authorities when the law requires. We do not sell your data.',
  ]),
  const _Sec('Security and your choices', [
    'Data is encrypted in transit. You can lock the app with a PIN or fingerprint, edit your details in Profile, and ask us to delete your account from Help.',
  ]),
];

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.privacy});
  final bool privacy;
  @override
  Widget build(BuildContext context) {
    final secs = privacy ? _privacy : _terms;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: privacy ? 'Privacy Policy' : 'Terms of Service'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
        Text('Last updated 15 October 2026', style: T.small),
        const Gap(14),
        for (final s in secs) ...[
          Text(s.title, style: T.h3),
          const Gap(6),
          for (final b in s.body) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(b, style: T.body.copyWith(color: C.muted, height: 1.55))),
          const Gap(10),
        ],
      ]),
    );
  }
}
