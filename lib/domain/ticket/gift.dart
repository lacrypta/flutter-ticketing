/// A claimable benefit. Labels and prices come from the client-side catalogue
/// (`core/config/gift_catalogue.dart`); the API only ever returns ids and
/// remaining counts.
class Gift {
  const Gift({required this.id, required this.label, required this.priceSats});

  final String id;
  final String label;
  final int priceSats;

  @override
  bool operator ==(Object other) =>
      other is Gift &&
      other.id == id &&
      other.label == label &&
      other.priceSats == priceSats;

  @override
  int get hashCode => Object.hash(id, label, priceSats);
}

/// A gift that has been consumed, recorded locally for the "Claimeados" panel
/// and for reprinting a receipt.
class ClaimedGift {
  const ClaimedGift({
    required this.gift,
    required this.claimedAt,
    required this.totalArs,
    required this.satPrice,
  });

  final Gift gift;
  final DateTime claimedAt;

  /// Fiat value at the moment of claiming — frozen, because the rate moves.
  final double totalArs;
  final double satPrice;
}
