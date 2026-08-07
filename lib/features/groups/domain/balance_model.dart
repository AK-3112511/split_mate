class BalanceModel {
  final String uid;
  final double amount; // Positive means user is owed money (creditor), negative means user owes (debtor)

  BalanceModel({
    required this.uid,
    required this.amount,
  });
}
