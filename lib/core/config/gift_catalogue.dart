import '../../domain/ticket/gift.dart';

/// The gift catalogue lives on the **client**, not the server.
///
/// `GET /api/checkin/{token}/gifts` returns only `{item_key: remaining}` — no
/// labels, no prices. The web app hardcodes the same two entries; we mirror
/// them so both apps print identical receipts.
///
/// An unknown id is not an error: it renders with the raw key as its label and
/// a 1 sat price, so a gift added server-side still works (just unstyled) until
/// this map catches up.
const Map<String, Gift> kGiftCatalogue = {
  'pizza_porcion': Gift(
    id: 'pizza_porcion',
    label: 'Porción de Pizza',
    priceSats: 1,
  ),
  'bebida': Gift(id: 'bebida', label: 'Bebida', priceSats: 1),
};

Gift resolveGift(String id) =>
    kGiftCatalogue[id] ?? Gift(id: id, label: id, priceSats: 1);
