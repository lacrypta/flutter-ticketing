import 'dart:math';
import 'dart:typed_data';

import 'package:bip340/bip340.dart' as bip340;
import 'package:convert/convert.dart';

import 'nostr_event.dart';

/// BIP-340 schnorr signing, as Nostr requires.
///
/// `bip340` is fiatjaf's own package (the author of the protocol) and is what
/// the `nostr` package itself wraps — using it directly avoids pulling a whole
/// relay/websocket SDK in just to sign an HTTP auth header.

/// Derives the 32-byte x-only public key (hex) from a private key (hex).
String derivePublicKey(String privateKeyHex) =>
    bip340.getPublicKey(privateKeyHex);

/// Signs an unsigned event, filling `pubkey` (when absent), `id` and `sig`.
NostrEvent signEvent(NostrEvent unsigned, String privateKeyHex) {
  final pubkey = unsigned.pubkey.isNotEmpty
      ? unsigned.pubkey
      : derivePublicKey(privateKeyHex);

  final id = NostrEvent.computeId(
    pubkey: pubkey,
    createdAt: unsigned.createdAt,
    kind: unsigned.kind,
    tags: unsigned.tags,
    content: unsigned.content,
  );

  return NostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: unsigned.createdAt,
    kind: unsigned.kind,
    tags: unsigned.tags,
    content: unsigned.content,
    sig: bip340.sign(privateKeyHex, id, randomHex32()),
  );
}

/// Verifies an event's id and signature. Used by the NIP-98 self-check tests,
/// which mirror the server's own validation.
bool verifyEvent(NostrEvent event) {
  final id = event.id;
  final sig = event.sig;
  if (id == null || sig == null) return false;
  if (id != event.computedId) return false;
  return bip340.verify(event.pubkey, id, sig);
}

/// 32 cryptographically-random bytes as lowercase hex.
///
/// Used both for BIP-340's auxiliary randomness and for generating the device
/// key. [Random.secure] is required — the default [Random] is seeded
/// predictably and would leak the key.
String randomHex32() {
  final rng = Random.secure();
  return hex.encode(
    Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256))),
  );
}
