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
  });

  factory Gift.fromJson(Map<String, dynamic> json) {
    final key = json['item_key']?.toString() ?? '';
    final name = json['name']?.toString();
    return Gift(
      id: key,
      // The server already falls back to the key; belt and braces.
      label: (name == null || name.isEmpty) ? key : name,
      imageUrl: json['image_url']?.toString(),
    );
  }

  final String id;
  final String label;

  /// Site-relative (`/item-type-templates/...`), resolved against the API base.
  final String? imageUrl;

  final int priceSats;

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
