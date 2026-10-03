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
    this.kind = 'gift',
    this.quantityLabel,
    this.statusLabel,
    this.claimed = false,
    this.printedLocally = false,
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
      kind: isTreasure ? 'sats_treasure' : 'gift',
    );
  }

  /// A row from `ticket_benefits` / `user_benefits`, the same list the CRM
  /// check-in page renders.
  factory Gift.fromBenefit(Map<String, dynamic> json) {
    final kind = json['kind']?.toString() ?? 'gift';
    final claimCode = json['claim_code']?.toString();
    final key = json['item_key']?.toString() ?? '';
    final explicitId = json['id']?.toString();
    final name = json['name']?.toString();
    final sats = json['sats_amount'];
    final claimed = json['claimed'] == true;
    return Gift(
      id: explicitId != null && explicitId.isNotEmpty
          ? explicitId
          : (kind == 'sats_treasure' && claimCode != null && claimCode.isNotEmpty
              ? claimCode
              : key),
      label: (name == null || name.isEmpty) ? key : name,
      imageUrl: json['image_url']?.toString(),
      lnurl: json['lnurl']?.toString(),
      satsAmount: sats is num ? sats.toInt() : int.tryParse('$sats'),
      kind: kind,
      quantityLabel: json['quantity_label']?.toString(),
      statusLabel: json['status_label']?.toString(),
      claimed: claimed,
    );
  }

  Gift copyWith({
    bool? claimed,
    bool? printedLocally,
    String? statusLabel,
    bool clearLnurl = false,
  }) => Gift(
    id: id,
    label: label,
    imageUrl: imageUrl,
    priceSats: priceSats,
    lnurl: clearLnurl ? null : lnurl,
    satsAmount: satsAmount,
    kind: kind,
    quantityLabel: quantityLabel,
    statusLabel: statusLabel ?? this.statusLabel,
    claimed: claimed ?? this.claimed,
    printedLocally: printedLocally ?? this.printedLocally,
  );

  final String id;
  final String label;

  /// Site-relative (`/item-type-templates/...`), resolved against the API base.
  final String? imageUrl;

  final int priceSats;

  /// Bech32 LUD-03 withdraw string. Present only for a Sats Treasure.
  final String? lnurl;

  /// Sats frozen on that chest.
  final int? satsAmount;

  final String kind;
  final String? quantityLabel;
  final String? statusLabel;

  /// Server says this row was already handed out or paid.
  final bool claimed;

  /// Printed in this session. The chest stays READY on the server.
  final bool printedLocally;

  bool get isTreasure =>
      kind == 'sats_treasure' ||
      (lnurl != null && lnurl!.isNotEmpty && (satsAmount ?? 0) > 0);

  bool get canPrint =>
      !claimed &&
      !printedLocally &&
      (isTreasure ? (lnurl != null && lnurl!.isNotEmpty) : true);

  String get detail {
    if (!isTreasure) return '';
    if (quantityLabel != null && quantityLabel!.isNotEmpty) return quantityLabel!;
    if (satsAmount != null && satsAmount! > 0) return '$satsAmount sats';
    return '';
  }

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
