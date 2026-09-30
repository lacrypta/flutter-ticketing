/// A claimable benefit.
///
/// [label] and [imageUrl] come from the server (`item_types`), so a gift added
/// after this build still prints with its real name instead of a raw key.
class Gift {
  const Gift({
    required this.id,
    required this.label,
    this.imageUrl,
    this.priceSats = 1,
    this.lnurl,
    this.satsAmount,
  });

  factory Gift.fromJson(Map<String, dynamic> json) {
    final key = json['item_key']?.toString() ?? '';
    final name = json['name']?.toString();
    final claimCode = json['claim_code']?.toString();
    final isTreasure = json['kind'] == 'sats_treasure';
    final sats = json['sats_amount'];
    return Gift(
      // One chest is one claim. A quantity stack stays keyed by item_key.
      id: isTreasure && claimCode != null && claimCode.isNotEmpty
          ? claimCode
          : key,
      // The server already falls back to the key; belt and braces.
      label: (name == null || name.isEmpty) ? key : name,
      imageUrl: json['image_url']?.toString(),
      lnurl: json['lnurl']?.toString(),
      satsAmount: sats is num ? sats.toInt() : int.tryParse('$sats'),
    );
  }

  final String id;
  final String label;

  /// Site-relative (`/item-type-templates/...`), resolved against the API base.
  final String? imageUrl;

  final int priceSats;

  /// Bech32 LUD-03 withdraw string. Present only for a Sats Treasure.
  final String? lnurl;

  /// Sats frozen on that chest.
  final int? satsAmount;

  bool get isTreasure =>
      lnurl != null && lnurl!.isNotEmpty && (satsAmount ?? 0) > 0;

  @override
  bool operator ==(Object other) =>
      other is Gift &&
      other.id == id &&
      other.label == label &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode => Object.hash(id, label, imageUrl);
}

/// A gift that has been consumed, kept for the "Claimeados" panel.
class ClaimedGift {
  const ClaimedGift({required this.gift, required this.claimedAt});

  final Gift gift;
  final DateTime claimedAt;
}
