import '../core/config/app_config.dart';

class Bank {
  const Bank(this.code, this.name);
  final String code;
  final String name;
}

class ResolvedAccount {
  const ResolvedAccount({required this.accountNumber, required this.bank, required this.accountName});
  final String accountNumber;
  final Bank bank;
  final String accountName;
}

/// A bank account the user has verified for payouts.
class PayoutAccount {
  const PayoutAccount({required this.id, required this.bank, required this.accountNumber, required this.accountName});
  final String id;
  final Bank bank;
  final String accountNumber;
  final String accountName;
}

/// A rate locked for [TokenConfig.quoteTtl]. All figures are computed by the
/// server in production. The client only displays them.
class Quote {
  const Quote({
    required this.id,
    required this.rate,
    required this.tokens,
    required this.grossNaira,
    required this.feeNaira,
    required this.netNaira,
    required this.expiresAt,
  });
  final String id;
  final double rate; // Naira per 1 CCT
  final double tokens; // CCT the user sends
  final double grossNaira;
  final double feeNaira;
  final double netNaira; // credited to the wallet
  final DateTime expiresAt;

  bool get expired => DateTime.now().isAfter(expiresAt);
  Duration get remaining => expiresAt.difference(DateTime.now());
}

enum DepositStatus { awaiting, detected, confirming, converting, completed, expired, failed }

extension DepositStatusX on DepositStatus {
  bool get terminal => this == DepositStatus.completed || this == DepositStatus.expired || this == DepositStatus.failed;
}

class DepositSession {
  const DepositSession({
    required this.id,
    required this.quote,
    required this.address,
    required this.status,
    this.confirmations = 0,
    this.reference,
  });
  final String id;
  final Quote quote;
  final String address;
  final DepositStatus status;
  final int confirmations;
  final String? reference;

  int get required => TokenConfig.confirmationsRequired;

  DepositSession copyWith({DepositStatus? status, int? confirmations, String? reference}) => DepositSession(
        id: id,
        quote: quote,
        address: address,
        status: status ?? this.status,
        confirmations: confirmations ?? this.confirmations,
        reference: reference ?? this.reference,
      );
}

class CheckoutSession {
  const CheckoutSession({required this.txRef, required this.amount, required this.checkoutUrl});
  final String txRef;
  final int amount;
  final String checkoutUrl;
}

enum PaymentOutcome { successful, failed, cancelled, pending }

class PayoutReceipt {
  const PayoutReceipt({required this.reference, required this.status});
  final String reference;
  final String status;
}
