import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screens.dart';
import '../features/auth/onboarding_flow.dart';
import '../features/bills/bills_hub_screen.dart';
import '../features/bills/international_screens.dart';
import '../features/bills/mobile_bills.dart';
import '../features/bills/utility_bills.dart';
import '../features/chat/chat_screens.dart';
import '../features/chat/support_chat.dart';
import '../features/funding/funding_screens.dart';
import '../features/funding/payout_screens.dart';
import '../features/home/home_screen.dart';
import '../services/models.dart';
import '../features/market/item_screens.dart';
import '../features/market/market_screen.dart';
import '../features/me/me_screens.dart';
import '../features/orders/orders_screens.dart';
import '../features/sell/sell_screens.dart';
import '../features/sell/plans_screen.dart';
import '../features/sell/insights_screen.dart';
import '../features/me/legal_screens.dart';
import '../features/wallet/beneficiaries_screen.dart';
import '../features/wallet/tx_screens.dart';
import '../features/wallet/wallet_screens.dart';
import '../features/wallet/send_money.dart';
import '../features/market/cart_screens.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/welcome', redirect: (c, s) => '/signin'),
      GoRoute(path: '/signin', builder: (c, s) => const SignInScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignUpScreen()),
      GoRoute(path: '/forgot', builder: (c, s) => const ForgotScreen()),
      GoRoute(path: '/otp', builder: (c, s) => OtpScreen(email: s.uri.queryParameters['email'] ?? '')),
      GoRoute(path: '/signup/details', builder: (c, s) => const DetailsScreen()),
      GoRoute(path: '/signup/verify-id', builder: (c, s) => const VerifyIdScreen(onboarding: true)),
      GoRoute(path: '/signup/biometric', builder: (c, s) => const BiometricSetupScreen()),
      GoRoute(path: '/settings/verify-id', builder: (c, s) => const VerifyIdScreen()),
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/shop', builder: (c, s) => MarketScreen(key: ValueKey(s.uri.toString()), initialCategory: s.uri.queryParameters['cat']))]),
          StatefulShellBranch(routes: [GoRoute(path: '/bills', builder: (c, s) => const BillsHubScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/more', builder: (c, s) => const MeScreen())]),
        ],
      ),
      // Old locations kept working.
      GoRoute(path: '/market', redirect: (c, s) => s.uri.query.isEmpty ? '/shop' : '/shop?${s.uri.query}'),
      GoRoute(path: '/me', redirect: (c, s) => '/more'),
      GoRoute(path: '/wallet', builder: (c, s) => const WalletScreen()),
      GoRoute(path: '/cart', builder: (c, s) => const CartScreen()),
      GoRoute(
        path: '/cart/placed',
        builder: (c, s) {
          final e = s.extra;
          if (e is (int, int)) return CartPlacedScreen(count: e.$1, total: e.$2);
          return const CartScreen();
        },
      ),
      GoRoute(path: '/send', builder: (c, s) => const SendMoneyScreen()),
      // Bills
      GoRoute(path: '/bills/airtime', builder: (c, s) => const AirtimeScreen()),
      GoRoute(path: '/bills/data', builder: (c, s) => const DataScreen()),
      GoRoute(path: '/bills/electricity', builder: (c, s) => const ElectricityScreen()),
      GoRoute(path: '/bills/tv', builder: (c, s) => const TvScreen()),
      GoRoute(path: '/bills/betting', builder: (c, s) => const BettingScreen()),
      GoRoute(path: '/bills/internet', builder: (c, s) => const InternetScreen()),
      GoRoute(path: '/bills/international', builder: (c, s) => const InternationalListScreen()),
      GoRoute(path: '/bills/international/:code', builder: (c, s) => InternationalPayScreen(code: s.pathParameters['code']!)),
      // Wallet
      GoRoute(path: '/wallet/add', builder: (c, s) => const AddMoneyScreen()),
      GoRoute(path: '/wallet/add/naira', builder: (c, s) => const FundNairaScreen()),
      GoRoute(path: '/wallet/add/naira/checkout', builder: (c, s) => s.extra is CheckoutSession ? GatewayCheckoutScreen(session: s.extra! as CheckoutSession) : const AddMoneyScreen()),
      GoRoute(
        path: '/wallet/add/naira/result',
        builder: (c, s) {
          final e = s.extra;
          if (e is (String, int, bool)) return FundingResultScreen(txRef: e.$1, amount: e.$2, cancelled: e.$3);
          return const AddMoneyScreen();
        },
      ),
      GoRoute(path: '/wallet/add/transfer', builder: (c, s) => const FundTransferScreen()),
      GoRoute(path: '/wallet/add/cct', builder: (c, s) => const CctFundScreen()),
      GoRoute(path: '/wallet/cct/deposit/:id', builder: (c, s) => DepositScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/wallet/withdraw', builder: (c, s) => const WithdrawScreen()),
      GoRoute(path: '/transactions', builder: (c, s) => TransactionsScreen(key: ValueKey(s.uri.toString()), kind: s.uri.queryParameters['kind'])),
      GoRoute(path: '/tx/:id', builder: (c, s) => TxDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/pay/:id', builder: (c, s) => PaymentResultScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/beneficiaries', builder: (c, s) => const BeneficiariesScreen()),
      // Marketplace
      GoRoute(path: '/search', builder: (c, s) => const SearchScreen()),
      GoRoute(path: '/saved', builder: (c, s) => const SavedScreen()),
      GoRoute(path: '/item/:id', builder: (c, s) => ItemScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/checkout/:id', builder: (c, s) => CheckoutScreen(id: s.pathParameters['id']!, price: int.tryParse(s.uri.queryParameters['price'] ?? ''))),
      GoRoute(path: '/order-placed/:id', builder: (c, s) => OrderPlacedScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/seller/:id', builder: (c, s) => SellerScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/insights', builder: (c, s) => const InsightsScreen()),
      GoRoute(path: '/plans', builder: (c, s) => const PlansScreen()),
      GoRoute(path: '/legal/terms', builder: (c, s) => const LegalScreen(privacy: false)),
      GoRoute(path: '/legal/privacy', builder: (c, s) => const LegalScreen(privacy: true)),
      GoRoute(path: '/sell', builder: (c, s) => const SellScreen()),
      GoRoute(path: '/my-listings', builder: (c, s) => const MyListingsScreen()),
      GoRoute(path: '/orders', builder: (c, s) => const OrdersScreen()),
      GoRoute(path: '/order/:id', builder: (c, s) => OrderDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/chats', builder: (c, s) => const ChatsScreen()),
      GoRoute(path: '/chat/:id', builder: (c, s) => ChatScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
      // Account
      GoRoute(path: '/settings/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/settings/security', builder: (c, s) => const SecurityScreen()),
      GoRoute(path: '/settings/notifications', builder: (c, s) => const NotifSettingsScreen()),
      GoRoute(path: '/help', builder: (c, s) => const HelpScreen()),
      GoRoute(path: '/help/chat', builder: (c, s) => const SupportChatScreen()),
      GoRoute(path: '/refer', builder: (c, s) => const ReferScreen()),
      GoRoute(path: '/about', builder: (c, s) => const AboutScreen()),
    ],
  );
});
