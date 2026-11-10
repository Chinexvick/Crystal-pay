import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_data.dart';
import 'plans.dart';

enum IdType { nin, bvn, passport }

extension IdTypeX on IdType {
  String get label => switch (this) { IdType.nin => 'NIN', IdType.bvn => 'BVN', IdType.passport => 'International passport' };
  String get short => switch (this) { IdType.nin => 'NIN', IdType.bvn => 'BVN', IdType.passport => 'Passport' };
}

/// The signed-in user's account. Front-end only: the auth backend becomes the
/// source of truth for every field here (see docs/API_REQUIREMENTS.md).
class Account {
  const Account({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.city = 'Lagos',
    this.idType,
    this.idVerified = false,
    this.biometric = false,
    this.photo,
    this.plan,
    this.planRenews,
    this.boostsUsed = 0,
    this.username = '',
  });

  final String email;

  /// Public handle used for Send Money (shown as @username).
  final String username;
  final String firstName;
  final String lastName;
  final String phone;
  final String city;
  final IdType? idType;

  /// True only after the identity check succeeds. Drives the blue tick.
  final bool idVerified;
  final bool biometric;
  final String? photo;

  /// Seller plan. Null until the user subscribes.
  final PlanId? plan;
  final DateTime? planRenews;
  final int boostsUsed;
  int get boostsLeft => planActive ? (planById(plan!).boostsPerMonth - boostsUsed).clamp(0, 999) : 0;

  bool get planActive => plan != null && planRenews != null && planRenews!.isAfter(DateTime.now());

  String get fullName => '$firstName $lastName'.trim();
  int get tier => idVerified ? 2 : 1;

  Account copyWith({String? email, String? firstName, String? lastName, String? phone, String? city, IdType? idType, bool? idVerified, bool? biometric, String? photo, PlanId? plan, DateTime? planRenews, int? boostsUsed, String? username}) => Account(
        email: email ?? this.email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone,
        city: city ?? this.city,
        idType: idType ?? this.idType,
        idVerified: idVerified ?? this.idVerified,
        biometric: biometric ?? this.biometric,
        photo: photo ?? this.photo,
        plan: plan ?? this.plan,
        planRenews: planRenews ?? this.planRenews,
        boostsUsed: boostsUsed ?? this.boostsUsed,
        username: username ?? this.username,
      );
}

const _demo = Account(
  email: 'victory@crystalpay.app',
  firstName: 'Victory',
  lastName: 'Bassey',
  phone: '08030000001',
  idType: IdType.nin,
  idVerified: true,
  photo: 'assets/images/avatars/me.jpg',
  plan: PlanId.basic,
  username: 'victory',
);

/// Suggests a handle from a first name: lowercase letters and digits only.
String suggestUsername(String first) {
  final base = first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final n = DateTime.now().millisecond % 90 + 10;
  return base.isEmpty ? 'user$n' : '$base$n';
}

/// Usernames: 3 to 20 characters, letters, numbers, dot or underscore.
bool isValidUsername(String u) => RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(u);

class AccountNotifier extends Notifier<Account> {
  @override
  Account build() => _demo.copyWith(city: mockProfile.city, planRenews: DateTime.now().add(const Duration(days: 21)));

  /// Demo sign-in: loads the demo profile under the email that was typed.
  void signInAs(String email) => state = _demo.copyWith(email: email.trim().toLowerCase(), city: mockProfile.city, planRenews: DateTime.now().add(const Duration(days: 21)));

  /// Fresh sign-up: nothing verified yet.
  void startSignup(String email) => state = Account(email: email.trim().toLowerCase(), firstName: '', lastName: '', phone: '');

  void setDetails({required String firstName, required String lastName, required String phone, String? username}) =>
      state = state.copyWith(firstName: firstName.trim(), lastName: lastName.trim(), phone: phone, username: username ?? (state.username.isEmpty ? suggestUsername(firstName) : null));

  void setUsername(String u) => state = state.copyWith(username: u.trim().toLowerCase());

  void setPhone(String phone) => state = state.copyWith(phone: phone);
  void setCity(String city) => state = state.copyWith(city: city);
  void markVerified(IdType t) => state = state.copyWith(idType: t, idVerified: true);
  void setPhoto(String? path) => state = state.copyWith(photo: path);
  /// Starts or changes the seller plan for a fresh 30-day period.
  void subscribe(PlanId id) => state = state.copyWith(plan: id, planRenews: DateTime.now().add(const Duration(days: kPlanPeriodDays)), boostsUsed: 0);
  void useBoost() => state = state.copyWith(boostsUsed: state.boostsUsed + 1);
  void setBiometric(bool on) => state = state.copyWith(biometric: on);
}

final accountProvider = NotifierProvider<AccountNotifier, Account>(AccountNotifier.new);
